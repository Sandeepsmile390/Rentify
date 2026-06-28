const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const cookieParser = require('cookie-parser');
const path = require('path');
const fs = require('fs');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');
const sanitizeHtml = require('sanitize-html');
const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();
const rateLimit = require('express-rate-limit');

// Database client & schema
const { db } = require('./src/db/index');
const { users, properties, tenants, bills, comments, chats, notifications, auditLogs, sessions } = require('./src/db/schema');
const { eq, and, or, desc, ne } = require('drizzle-orm');

// Cryptographic & Validation helpers
const cryptoUtils = require('./src/utils/crypto');
const { 
  loginSchema, tenantSchema, propertySchema, 
  billSchema, commentSchema, chatSchema, paymentSchema 
} = require('./src/utils/validation');

// Security Middlewares
const { authenticateJWT, authorizeRoles } = require('./src/middleware/auth');
const { verifyOwnership } = require('./src/middleware/ownership');
const { upload, validateFileSize, UPLOAD_DIR } = require('./src/middleware/upload');

// Load environment config
require('dotenv').config();

const app = express();
app.set('trust proxy', 1); // Trust Vercel's proxy for express-rate-limit
const PORT = process.env.PORT || 5000;
const JWT_SECRET = process.env.JWT_SECRET || 'rentify_access_token_secret_99881122';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'rentify_refresh_token_secret_22118899';

// 1. CORS Setup (Support web cookie transfer)
app.use(cors({
  origin: (origin, callback) => {
    // Allow mobile apps, curl, postman (no origin header)
    if (!origin) return callback(null, true);
    
    // Allow localhost and any Vercel deployment subdomain
    if (
      origin.startsWith('http://localhost:') || 
      origin.startsWith('http://127.0.0.1:') ||
      origin.endsWith('.vercel.app')
    ) {
      return callback(null, true);
    }
    
    return callback(null, false);
  },
  credentials: true
}));

// 2. Helmet headers integration (Clickjacking & CSP)
app.use(helmet({
  contentSecurityPolicy: process.env.NODE_ENV === 'production' ? undefined : false, // bypass dev tools CSP if local
  crossOriginResourcePolicy: { policy: "cross-origin" }
}));

// 3. Auto HTTP -> HTTPS Redirection in production
if (process.env.NODE_ENV === 'production') {
  app.use((req, res, next) => {
    if (req.headers['x-forwarded-proto'] !== 'https' && !req.secure) {
      return res.redirect(`https://${req.headers.host}${req.url}`);
    }
    next();
  });
}

app.use(express.json());
app.use(cookieParser());

// 4. Rate Limiting Configurations (Protect against API abuse)
const loginLimiter = rateLimit({
  windowMs: 1 * 60 * 1000, // 1 min window
  max: 5,
  message: { message: 'Too many requests. Please try again after 1 minute.' }
});

const generalLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 100,
  message: { message: 'Rate limit exceeded.' }
});

const chatLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 50,
  message: { message: 'Chat rate limit exceeded.' }
});

const uploadLimiter = rateLimit({
  windowMs: 1 * 60 * 1000,
  max: 20,
  message: { message: 'Upload rate limit exceeded.' }
});

// Apply general limiter on all routes
app.use('/api/', generalLimiter);

// 5. Audit Log Database Helper
async function logAuditAction(req, action, oldValue = null, newValue = null) {
  try {
    const userId = req.user ? req.user.id : 'anonymous';
    const role = req.user ? req.user.role : 'none';
    const ip = req.ip || req.headers['x-forwarded-for'] || req.connection.remoteAddress;
    const device = req.headers['user-agent'] || 'unknown';

    await db.insert(auditLogs).values({
      id: 'audit-' + uuidv4(),
      userId,
      role,
      action,
      oldValue: oldValue ? JSON.stringify(oldValue) : null,
      newValue: newValue ? JSON.stringify(newValue) : null,
      ipAddress: ip,
      deviceInfo: device,
      timestamp: new Date().toISOString()
    });
  } catch (err) {
    console.error('⚠️ Failed to write audit log:', err.message);
  }
}

// ==============================================================
// SESSION TRACKING HELPER
// ==============================================================
function parseUserAgent(ua = '') {
  let browser = 'Unknown Browser';
  let os = 'Unknown OS';
  let deviceName = 'Unknown Device';

  if (/Chrome\//.test(ua) && !/Edg\//.test(ua)) browser = 'Chrome';
  else if (/Firefox\//.test(ua)) browser = 'Firefox';
  else if (/Safari\//.test(ua) && !/Chrome/.test(ua)) browser = 'Safari';
  else if (/Edg\//.test(ua)) browser = 'Edge';
  else if (/OPR\//.test(ua)) browser = 'Opera';

  if (/Windows NT/.test(ua)) { os = 'Windows'; deviceName = 'Windows PC'; }
  else if (/Mac OS X/.test(ua)) { os = 'macOS'; deviceName = 'Mac'; }
  else if (/Android/.test(ua)) { os = 'Android'; deviceName = 'Android Phone'; }
  else if (/iPhone|iPad/.test(ua)) { os = 'iOS'; deviceName = /iPad/.test(ua) ? 'iPad' : 'iPhone'; }
  else if (/Linux/.test(ua)) { os = 'Linux'; deviceName = 'Linux PC'; }

  return { browser, os, deviceName };
}

async function createSession(userId, req, tokenHash) {
  try {
    const ua = req.headers['user-agent'] || '';
    const ip = req.ip || req.headers['x-forwarded-for'] || '127.0.0.1';
    const { browser, os, deviceName } = parseUserAgent(ua);
    await db.insert(sessions).values({
      id: 'session-' + uuidv4(),
      userId,
      deviceName,
      browser,
      os,
      ipAddress: ip,
      location: 'Unknown Location',
      lastActive: new Date().toISOString(),
      isActive: true,
      tokenHash: tokenHash ? tokenHash.substring(0, 64) : null,
      createdAt: new Date().toISOString()
    });
  } catch (err) {
    console.error('⚠️ Failed to create session record:', err.message);
  }
}

// Root endpoints to confirm API status
app.get('/', (req, res) => {
  res.json({
    status: 'online',
    message: 'Welcome to Rentify API Secure Server',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

app.get('/api', (req, res) => {
  res.json({
    status: 'online',
    message: 'Welcome to Rentify API Secure Server',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// ==============================================================
// AUTHENTICATION APIs
// ==============================================================

// User login (Uses strict Rate Limiter)
app.post('/api/auth/login', loginLimiter, async (req, res, next) => {
  try {
    // Validate request inputs using Zod
    const validationResult = loginSchema.safeParse(req.body);
    if (!validationResult.success) {
      return res.status(400).json({ errors: validationResult.error.format() });
    }

    const { email, phone, password, role } = req.body;
    const loginVal = email || phone;

    if (!loginVal) {
      return res.status(400).json({ message: 'Email or Phone is required.' });
    }

    // Query user using parameterized Drizzle queries (SQL Injection Safe)
    const matchedUsers = await db.select().from(users).where(
      and(
        or(eq(users.email, loginVal), eq(users.phone, loginVal)),
        eq(users.role, role)
      )
    );

    if (matchedUsers.length === 0) {
      return res.status(401).json({ message: 'Invalid credentials.' });
    }

    const user = matchedUsers[0];

    // Check if login is disabled by owner
    if (user.loginEnabled === false) {
      return res.status(403).json({ message: 'Your account has been disabled. Please contact the owner.' });
    }

    // Verify Password Hash (Never store plain text passwords)
    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid credentials.' });
    }

    // Create JWT session tokens
    const accessToken = jwt.sign(
      { id: user.id, email: user.email, phone: user.phone, role: user.role },
      JWT_SECRET,
      { expiresIn: '15m' } // 15 min expiry
    );

    const refreshToken = jwt.sign(
      { id: user.id },
      JWT_REFRESH_SECRET,
      { expiresIn: '30d' } // 30 day expiry
    );

    // Save refresh token & session active status in database
    await db.update(users)
      .set({ 
        refreshToken: refreshToken, 
        sessionActive: true, 
        lastActive: new Date().toISOString(),
        deviceInfo: req.headers['user-agent'] || 'unknown'
      })
      .where(eq(users.id, user.id));

    // Create session tracking record
    await createSession(user.id, req, refreshToken);

    // Web Client Cookie configuration (Supports cross-site calls to live API from local/deployed frontend)
    const isProd = process.env.NODE_ENV === 'production' || (req.headers.host && req.headers.host.includes('vercel.app'));
    res.cookie('accessToken', accessToken, {
      httpOnly: true,
      secure: isProd,
      sameSite: isProd ? 'none' : 'lax',
      maxAge: 15 * 60 * 1000 // 15 minutes
    });

    res.cookie('refreshToken', refreshToken, {
      httpOnly: true,
      secure: isProd,
      sameSite: isProd ? 'none' : 'lax',
      maxAge: 30 * 24 * 60 * 60 * 1000 // 30 days
    });

    // Write audit log
    req.user = { id: user.id, role: user.role };
    await logAuditAction(req, 'LOGIN_SUCCESS', null, { userId: user.id, email: user.email });

    res.json({
      success: true,
      isFirstLogin: user.isFirstLogin || false,
      accessToken,
      refreshToken,
      user: { id: user.id, email: user.email, phone: user.phone, role: user.role, tenantLoginId: user.tenantLoginId }
    });
  } catch (error) {
    next(error);
  }
});

// Logout current session
app.post('/api/auth/logout', authenticateJWT, async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Revoke token in DB
    await db.update(users)
      .set({ refreshToken: null, sessionActive: false })
      .where(eq(users.id, userId));

    // Clear client cookies
    res.clearCookie('accessToken');
    res.clearCookie('refreshToken');

    await logAuditAction(req, 'LOGOUT_SUCCESS', { userId });
    res.json({ success: true, message: 'Logged out successfully.' });
  } catch (error) {
    next(error);
  }
});

// Logout all device sessions
app.post('/api/auth/logout-all', authenticateJWT, async (req, res, next) => {
  try {
    const userId = req.user.id;

    // Revoke session token across all sessions
    await db.update(users)
      .set({ refreshToken: null, sessionActive: false })
      .where(eq(users.id, userId));

    res.clearCookie('accessToken');
    res.clearCookie('refreshToken');

    await logAuditAction(req, 'LOGOUT_ALL_DEVICES', { userId });
    res.json({ success: true, message: 'Successfully logged out from all devices.' });
  } catch (error) {
    next(error);
  }
});

// Get self profile info
app.get('/api/auth/me', authenticateJWT, async (req, res, next) => {
  try {
    res.json({ user: req.user });
  } catch (error) {
    next(error);
  }
});

// Change user password
app.post('/api/auth/change-password', authenticateJWT, async (req, res, next) => {
  try {
    const { oldPassword, newPassword } = req.body;
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ message: 'New password must be at least 6 characters long.' });
    }

    const userRecord = await db.select().from(users).where(eq(users.id, req.user.id));
    if (userRecord.length === 0) return res.status(404).json({ message: 'User not found.' });

    const user = userRecord[0];
    const isOldValid = await bcrypt.compare(oldPassword, user.passwordHash);
    if (!isOldValid) {
      return res.status(400).json({ message: 'Incorrect old password.' });
    }

    const hashedNew = await bcrypt.hash(newPassword, 10);
    await db.update(users).set({ passwordHash: hashedNew }).where(eq(users.id, user.id));

    await logAuditAction(req, 'CHANGE_PASSWORD', { userId: user.id });
    res.json({ success: true, message: 'Password changed successfully.' });
  } catch (error) {
    next(error);
  }
});



// ==============================================================
// PROPERTY MANAGEMENT APIs (Owner Restricted)
// ==============================================================
app.get('/api/properties', authenticateJWT, async (req, res, next) => {
  try {
    // Owners get all; tenants can see their own property details
    if (req.user.role === 'tenant') {
      const tenantRec = await db.select().from(tenants).where(eq(tenants.userId, req.user.id));
      if (tenantRec.length > 0) {
        const prop = await db.select().from(properties).where(eq(properties.id, tenantRec[0].propertyId));
        return res.json(prop);
      }
      return res.json([]);
    }

    const propList = await db.select().from(properties);
    res.json(propList);
  } catch (e) {
    next(e);
  }
});

app.post('/api/properties', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const valid = propertySchema.safeParse(req.body);
    if (!valid.success) return res.status(400).json({ errors: valid.error.format() });

    const { name, type, totalRooms } = req.body;
    const newProp = {
      id: 'prop-' + uuidv4(),
      name,
      type,
      totalRooms,
      occupied: 0,
      vacant: totalRooms,
      monthlyRevenue: 0,
      ownerId: req.user.id
    };

    await db.insert(properties).values(newProp);
    await logAuditAction(req, 'CREATE_PROPERTY', null, newProp);
    res.status(201).json(newProp);
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// TENANT MANAGEMENT APIs (RBAC + Ownership Checks)
// ==============================================================
app.get('/api/tenants', authenticateJWT, async (req, res, next) => {
  try {
    let list = [];
    if (req.user.role === 'tenant') {
      // Tenants see only their own profile decrypted
      list = await db.select({
        tenant: tenants,
        loginId: users.tenantLoginId,
        loginEnabled: users.loginEnabled
      })
      .from(tenants)
      .leftJoin(users, eq(tenants.userId, users.id))
      .where(eq(tenants.userId, req.user.id));
    } else {
      // Owners view all
      list = await db.select({
        tenant: tenants,
        loginId: users.tenantLoginId,
        loginEnabled: users.loginEnabled
      })
      .from(tenants)
      .leftJoin(users, eq(tenants.userId, users.id));
    }

    // Decrypt AES-256 encrypted fields for clients
    const decryptedList = list.map(item => {
      const t = item.tenant;
      return {
        ...t,
        tenantLoginId: item.loginId,
        loginEnabled: item.loginEnabled !== false, // default true if null
        aadhaar: cryptoUtils.decrypt(t.aadhaarEncrypted),
        pan: cryptoUtils.decrypt(t.panEncrypted),
        permanentAddress: cryptoUtils.decrypt(t.permanentAddressEncrypted),
        emergencyContact: cryptoUtils.decrypt(t.emergencyContactEncrypted)
      };
    });

    res.json(decryptedList);
  } catch (error) {
    next(error);
  }
});

// Create new Tenant (Owner only)
app.post('/api/tenants', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const valid = tenantSchema.safeParse(req.body);
    if (!valid.success) return res.status(400).json({ errors: valid.error.format() });

    const {
      name, fatherName, phone, altPhone, email, occupation,
      aadhaar, pan, permanentAddress, propertyId, roomNumber,
      roomType, moveInDate, agreementDuration, rentAmount,
      securityDeposit, electricityRate, waterCharges, photo, emergencyContact
    } = req.body;

    // Check if property exists
    const propArr = await db.select().from(properties).where(eq(properties.id, propertyId));
    if (propArr.length === 0) return res.status(404).json({ message: 'Target property not found.' });
    const prop = propArr[0];

    // Create system login for Tenant
    const tenantUserId = 'user-tenant-' + uuidv4();
    // Use owner-specified credentials or generate defaults
    const loginId = req.body.tenantLoginId || ('TENANT-' + Math.floor(100 + Math.random() * 900));
    const rawTempPassword = req.body.tempPassword || ('Temp@' + Math.floor(100000 + Math.random() * 900000));
    const defaultPasswordHash = await bcrypt.hash(rawTempPassword, 10);

    await db.insert(users).values({
      id: tenantUserId,
      email: email || null,
      phone: phone,
      passwordHash: defaultPasswordHash,
      role: 'tenant',
      sessionActive: false,
      tenantLoginId: loginId,
      isFirstLogin: true,  // Force password change on first login
      loginEnabled: req.body.loginEnabled !== false  // default: true
    });

    const tenantId = 'tenant-' + uuidv4();

    // Encrypt Aadhaar, PAN, Permanent Address, and Emergency Contact (AES-256-CBC)
    const newTenant = {
      id: tenantId,
      userId: tenantUserId,
      name,
      fatherName,
      phone,
      altPhone,
      email,
      occupation,
      aadhaarEncrypted: cryptoUtils.encrypt(aadhaar),
      panEncrypted: cryptoUtils.encrypt(pan),
      permanentAddressEncrypted: cryptoUtils.encrypt(permanentAddress),
      emergencyContactEncrypted: cryptoUtils.encrypt(emergencyContact || ''),
      currentAddress: req.body.currentAddress || `${roomType} ${roomNumber}, ${prop.name}`,
      propertyId,
      propertyName: prop.name,
      roomNumber,
      roomType,
      moveInDate,
      agreementDuration,
      rentAmount,
      securityDeposit,
      electricityRate,
      waterCharges,
      status: 'Active',
      photo: photo || 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      documents: req.body.documents || {}
    };

    await db.insert(tenants).values(newTenant);

    // Update vacancy counts on property
    const newOccupied = prop.occupied + 1;
    await db.update(properties)
      .set({ 
        occupied: newOccupied, 
        vacant: Math.max(0, prop.totalRooms - newOccupied),
        monthlyRevenue: prop.monthlyRevenue + rentAmount
      })
      .where(eq(properties.id, propertyId));

    await logAuditAction(req, 'CREATE_TENANT', null, { tenantId, name });
    res.status(201).json({
      ...newTenant,
      tenantLoginId: loginId,
      tempPassword: rawTempPassword  // Shown once to owner at check-in
    });
  } catch (error) {
    next(error);
  }
});

// Soft Delete (Archive Tenant Move Out)
app.post('/api/tenants/:id/move-out', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const tenantId = req.params.id;
    const { clearDues, refundAmount, refundDeductionReason } = req.body;

    const tenantArr = await db.select().from(tenants).where(eq(tenants.id, tenantId));
    if (tenantArr.length === 0) return res.status(404).json({ message: 'Tenant not found.' });
    const tenant = tenantArr[0];

    // Clear all pending bills if requested
    if (clearDues) {
      const outstandingBills = await db.select().from(bills).where(
        and(eq(bills.tenantId, tenantId), eq(bills.status, 'Unpaid'))
      );
      
      for (const bill of outstandingBills) {
        await db.update(bills)
          .set({
            paidAmount: bill.totalAmount,
            pendingAmount: 0,
            status: 'Paid',
            payments: [
              ...(bill.payments || []),
              { date: new Date().toISOString().split('T')[0], amount: bill.pendingAmount, method: 'Cash', note: 'Settled on checkout' }
            ]
          })
          .where(eq(bills.id, bill.id));
      }
    }

    // Soft delete profile: Update status to 'Left', record departure timestamp
    await db.update(tenants)
      .set({ 
        status: 'Left', 
        leftDate: new Date().toISOString().split('T')[0],
        archiveDate: new Date().toISOString()
      })
      .where(eq(tenants.id, tenantId));

    // Release room on property
    const propArr = await db.select().from(properties).where(eq(properties.id, tenant.propertyId));
    if (propArr.length > 0) {
      const prop = propArr[0];
      const newOccupied = Math.max(0, prop.occupied - 1);
      await db.update(properties)
        .set({ 
          occupied: newOccupied, 
          vacant: prop.totalRooms - newOccupied,
          monthlyRevenue: Math.max(0, prop.monthlyRevenue - tenant.rentAmount)
        })
        .where(eq(properties.id, tenant.propertyId));
    }

    await logAuditAction(req, 'SOFT_DELETE_TENANT_MOVE_OUT', tenant, { tenantId, status: 'Left' });
    res.json({ success: true, message: 'Tenant archived successfully under soft delete.' });
  } catch (error) {
    next(error);
  }
});

// Restore soft-deleted tenant
app.post('/api/tenants/:id/restore', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const tenantId = req.params.id;
    const tenantArr = await db.select().from(tenants).where(eq(tenants.id, tenantId));
    if (tenantArr.length === 0) return res.status(404).json({ message: 'Tenant not found.' });
    const tenant = tenantArr[0];

    if (tenant.status !== 'Left') {
      return res.status(400).json({ message: 'Tenant is already active.' });
    }

    // Restore status to Active
    await db.update(tenants)
      .set({ status: 'Active', leftDate: null, archiveDate: null })
      .where(eq(tenants.id, tenantId));

    // Update Property Vacancy
    const propArr = await db.select().from(properties).where(eq(properties.id, tenant.propertyId));
    if (propArr.length > 0) {
      const prop = propArr[0];
      const newOccupied = prop.occupied + 1;
      await db.update(properties)
        .set({
          occupied: newOccupied,
          vacant: Math.max(0, prop.totalRooms - newOccupied),
          monthlyRevenue: prop.monthlyRevenue + tenant.rentAmount
        })
        .where(eq(properties.id, tenant.propertyId));
    }

    await logAuditAction(req, 'RESTORE_TENANT', tenant, { tenantId, status: 'Active' });
    res.json({ success: true, message: 'Tenant restored successfully.' });
  } catch (error) {
    next(error);
  }
});

// Permanent Delete Tenant (Owner only, restricted)
app.delete('/api/tenants/:id', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const tenantId = req.params.id;
    const tenantArr = await db.select().from(tenants).where(eq(tenants.id, tenantId));
    if (tenantArr.length === 0) return res.status(404).json({ message: 'Tenant not found.' });
    const tenant = tenantArr[0];

    // Deleting matching records in DB
    await db.delete(bills).where(eq(bills.tenantId, tenantId));
    await db.delete(comments).where(eq(comments.tenantId, tenantId));
    await db.delete(chats).where(eq(chats.tenantId, tenantId));
    await db.delete(tenants).where(eq(tenants.id, tenantId));
    
    // Delete user login profile
    if (tenant.userId) {
      await db.delete(users).where(eq(users.id, tenant.userId));
    }

    await logAuditAction(req, 'HARD_DELETE_TENANT', tenant, null);
    res.json({ success: true, message: 'Tenant records permanently deleted.' });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// BILLS & UTILITIES APIs (Ownership Checks for Tenants)
// ==============================================================
app.get('/api/bills', authenticateJWT, async (req, res, next) => {
  try {
    if (req.user.role === 'tenant') {
      // Find matching tenant record first
      const tenantRec = await db.select().from(tenants).where(eq(tenants.userId, req.user.id));
      if (tenantRec.length === 0) return res.json([]);
      const myBills = await db.select().from(bills).where(eq(bills.tenantId, tenantRec[0].id));
      return res.json(myBills);
    }
    const allBills = await db.select().from(bills);
    res.json(allBills);
  } catch (error) {
    next(error);
  }
});

// Enforce ownership verify on specific bill route
app.get('/api/bills/:id', authenticateJWT, verifyOwnership('bill'), async (req, res, next) => {
  try {
    const billRec = await db.select().from(bills).where(eq(bills.id, req.params.id));
    if (billRec.length === 0) return res.status(404).json({ message: 'Bill not found.' });
    res.json(billRec[0]);
  } catch (error) {
    next(error);
  }
});

// Create bills automatically (Owner only)
app.post('/api/bills/generate-monthly', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const { month } = req.body;
    if (!month) return res.status(400).json({ message: 'Month is required.' });

    const activeTenants = await db.select().from(tenants).where(eq(tenants.status, 'Active'));
    let generatedCount = 0;

    for (const tenant of activeTenants) {
      // Check if bill exists for this month and tenant
      const existing = await db.select().from(bills).where(
        and(eq(bills.tenantId, tenant.id), eq(bills.billingMonth, month))
      );

      if (existing.length === 0) {
        // Random usage mock
        const units = Math.floor(Math.random() * 60) + 90;
        const electricityAmount = units * tenant.electricityRate;
        const total = tenant.rentAmount + electricityAmount + tenant.waterCharges;

        const newBill = {
          id: 'bill-' + uuidv4(),
          tenantId: tenant.id,
          tenantName: tenant.name,
          roomNumber: tenant.roomNumber,
          propertyName: tenant.propertyName,
          billingMonth: month,
          rentAmount: tenant.rentAmount,
          electricityUnits: units,
          electricityRate: tenant.electricityRate,
          electricityAmount,
          waterCharges: tenant.waterCharges,
          lateFee: 0,
          discount: 0,
          extraCharges: 0,
          extraChargesReason: '',
          totalAmount: total,
          paidAmount: 0,
          pendingAmount: total,
          status: 'Unpaid',
          dueDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
          payments: []
        };

        await db.insert(bills).values(newBill);
        generatedCount++;

        // Add Notification
        await db.insert(notifications).values({
          id: 'notif-' + uuidv4(),
          tenantId: tenant.id,
          title: 'Bill Generated',
          message: `Your rent bill of ₹${total} for ${month} has been generated.`,
          time: new Date().toISOString(),
          forRole: 'tenant',
          read: false
        });
      }
    }

    await logAuditAction(req, 'GENERATE_MONTHLY_BILLS', null, { month, generatedCount });
    res.json({ success: true, count: generatedCount });
  } catch (error) {
    next(error);
  }
});

// Update specific bill values (Owner only)
app.put('/api/bills/:id', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const billId = req.params.id;
    const valid = billSchema.safeParse(req.body);
    if (!valid.success) return res.status(400).json({ errors: valid.error.format() });

    const billArr = await db.select().from(bills).where(eq(bills.id, billId));
    if (billArr.length === 0) return res.status(404).json({ message: 'Bill not found.' });
    const bill = billArr[0];

    // Read parameter changes
    const rentAmount = req.body.rentAmount !== undefined ? parseFloat(req.body.rentAmount) : bill.rentAmount;
    const electricityUnits = req.body.electricityUnits !== undefined ? parseFloat(req.body.electricityUnits) : bill.electricityUnits;
    const electricityRate = req.body.electricityRate !== undefined ? parseFloat(req.body.electricityRate) : bill.electricityRate;
    const waterCharges = req.body.waterCharges !== undefined ? parseFloat(req.body.waterCharges) : bill.waterCharges;
    const lateFee = req.body.lateFee !== undefined ? parseFloat(req.body.lateFee) : bill.lateFee;
    const discount = req.body.discount !== undefined ? parseFloat(req.body.discount) : bill.discount;
    const extraCharges = req.body.extraCharges !== undefined ? parseFloat(req.body.extraCharges) : bill.extraCharges;
    const extraChargesReason = req.body.extraChargesReason !== undefined ? req.body.extraChargesReason : bill.extraChargesReason;

    // Server-side calculation prevents client tampering
    const electricityAmount = electricityUnits * electricityRate;
    const totalAmount = rentAmount + electricityAmount + waterCharges + lateFee + extraCharges - discount;

    const paymentsList = bill.payments || [];
    const totalPaid = paymentsList.reduce((sum, p) => sum + p.amount, 0);
    const pendingAmount = Math.max(0, totalAmount - totalPaid);

    let status = 'Unpaid';
    if (pendingAmount === 0) status = 'Paid';
    else if (totalPaid > 0) status = 'Partial Paid';

    await db.update(bills)
      .set({
        rentAmount, electricityUnits, electricityRate, electricityAmount,
        waterCharges, lateFee, discount, extraCharges, extraChargesReason,
        totalAmount, pendingAmount, status
      })
      .where(eq(bills.id, billId));

    await logAuditAction(req, 'OVERRIDE_BILL_UTILITIES', bill, { billId, totalAmount });
    res.json({ success: true, message: 'Bill override parameters saved.' });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// PAYMENTS API (Recalculates dues on server)
// ==============================================================
app.post('/api/payments', authenticateJWT, async (req, res, next) => {
  try {
    const valid = paymentSchema.safeParse(req.body);
    if (!valid.success) return res.status(400).json({ errors: valid.error.format() });

    const { billId, amount, method, note } = req.body;
    const billArr = await db.select().from(bills).where(eq(bills.id, billId));
    if (billArr.length === 0) return res.status(404).json({ message: 'Bill reference not found.' });
    
    const bill = billArr[0];
    const paymentAmount = parseFloat(amount);

    if (paymentAmount > bill.pendingAmount) {
      return res.status(400).json({ message: 'Payment exceeds pending amount due.' });
    }

    // Append transaction receipt
    const newPayment = {
      date: new Date().toISOString().split('T')[0],
      amount: paymentAmount,
      method,
      note: sanitizeHtml(note || '')
    };

    const newPaymentsList = [...(bill.payments || []), newPayment];
    const newPaidAmount = bill.paidAmount + paymentAmount;
    
    // Server-side calculation prevents duplicate or incorrect remaining sums
    const newPendingAmount = Math.max(0, bill.totalAmount - newPaidAmount);
    const newStatus = newPendingAmount === 0 ? 'Paid' : 'Partial Paid';

    await db.update(bills)
      .set({
        paidAmount: newPaidAmount,
        pendingAmount: newPendingAmount,
        status: newStatus,
        payments: newPaymentsList
      })
      .where(eq(bills.id, billId));

    // Register logs
    await logAuditAction(req, 'RECORD_PAYMENT_TRANSACTION', { billId, prevPaid: bill.paidAmount }, { amount: paymentAmount, method });

    // Send notifications
    await db.insert(notifications).values({
      id: 'notif-' + uuidv4(),
      tenantId: bill.tenantId,
      title: 'Payment Recorded',
      message: `Your payment of ₹${paymentAmount} has been recorded successfully.`,
      time: new Date().toISOString(),
      forRole: 'tenant',
      read: false
    });

    res.json({ success: true, message: 'Payment logged successfully.' });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// COMMENTS & TICKETS APIs (Sanitizes Inputs)
// ==============================================================
app.get('/api/comments', authenticateJWT, async (req, res, next) => {
  try {
    if (req.user.role === 'tenant') {
      const tenantRec = await db.select().from(tenants).where(eq(tenants.userId, req.user.id));
      if (tenantRec.length === 0) return res.json([]);
      const myComments = await db.select().from(comments).where(eq(comments.tenantId, tenantRec[0].id));
      return res.json(myComments);
    }
    const allComments = await db.select().from(comments);
    res.json(allComments);
  } catch (error) {
    next(error);
  }
});

app.post('/api/comments', authenticateJWT, async (req, res, next) => {
  try {
    const valid = commentSchema.safeParse(req.body);
    if (!valid.success) return res.status(400).json({ errors: valid.error.format() });

    const { tenantId, title, category, message } = req.body;
    
    // Ownership check for tenant
    if (req.user.role === 'tenant') {
      const tenantRec = await db.select().from(tenants).where(eq(tenants.userId, req.user.id));
      if (tenantRec.length === 0 || tenantRec[0].id !== tenantId) {
        return res.status(403).json({ message: 'Forbidden. Incorrect tenant mapping.' });
      }
    }

    const tenantArr = await db.select().from(tenants).where(eq(tenants.id, tenantId));
    if (tenantArr.length === 0) return res.status(404).json({ message: 'Tenant profile not found.' });
    const tenant = tenantArr[0];

    // Sanitize XSS tags in Comments
    const sanitizedTitle = sanitizeHtml(title);
    const sanitizedMessage = sanitizeHtml(message);

    const newComment = {
      id: 'comment-' + uuidv4(),
      tenantId,
      tenantName: tenant.name,
      roomNumber: tenant.roomNumber,
      title: sanitizedTitle,
      category: category || 'Maintenance',
      status: 'Open',
      createdAt: new Date().toISOString(),
      unreadByOwner: true,
      unreadByTenant: false,
      replies: [
        {
          id: 'reply-' + uuidv4(),
          sender: 'tenant',
          name: tenant.name,
          message: sanitizedMessage,
          createdAt: new Date().toISOString()
        }
      ]
    };

    await db.insert(comments).values(newComment);
    res.status(201).json(newComment);
  } catch (error) {
    next(error);
  }
});

app.post('/api/comments/:id/reply', authenticateJWT, verifyOwnership('comment'), async (req, res, next) => {
  try {
    const commentId = req.params.id;
    const { message } = req.body;
    if (!message) return res.status(400).json({ message: 'Reply message cannot be empty.' });

    const commentArr = await db.select().from(comments).where(eq(comments.id, commentId));
    if (commentArr.length === 0) return res.status(404).json({ message: 'Comment thread not found.' });
    const comment = commentArr[0];

    // Sanitize XSS tags
    const sanitizedMessage = sanitizeHtml(message);

    const reply = {
      id: 'reply-' + uuidv4(),
      sender: req.user.role,
      name: req.user.role === 'owner' ? 'Owner / Landlord' : req.user.email,
      message: sanitizedMessage,
      createdAt: new Date().toISOString()
    };

    const newRepliesList = [...(comment.replies || []), reply];
    const updatePayload = {
      replies: newRepliesList,
      createdAt: new Date().toISOString()
    };

    if (req.user.role === 'owner') {
      updatePayload.unreadByTenant = true;
      updatePayload.unreadByOwner = false;
    } else {
      updatePayload.unreadByOwner = true;
      updatePayload.unreadByTenant = false;
    }

    await db.update(comments).set(updatePayload).where(eq(comments.id, commentId));
    res.json({ success: true, reply });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// CHATS & DIRECT MESSAGE APIs (Uses Chat rate limits)
// ==============================================================
app.get('/api/chats', authenticateJWT, async (req, res, next) => {
  try {
    if (req.user.role === 'tenant') {
      const tenantRec = await db.select().from(tenants).where(eq(tenants.userId, req.user.id));
      if (tenantRec.length === 0) return res.json([]);
      const myChats = await db.select().from(chats).where(eq(chats.tenantId, tenantRec[0].id));
      return res.json(myChats);
    }
    const allChats = await db.select().from(chats);
    res.json(allChats);
  } catch (error) {
    next(error);
  }
});

app.post('/api/chats/message', authenticateJWT, chatLimiter, async (req, res, next) => {
  try {
    const valid = chatSchema.safeParse(req.body);
    if (!valid.success) return res.status(400).json({ errors: valid.error.format() });

    const { tenantId, sender, text, attachment, attachmentType } = req.body;

    // Tenant identity validation
    if (req.user.role === 'tenant') {
      const tenantRec = await db.select().from(tenants).where(eq(tenants.userId, req.user.id));
      if (tenantRec.length === 0 || tenantRec[0].id !== tenantId) {
        return res.status(403).json({ message: 'Forbidden. Incorrect sender channel.' });
      }
    }

    let chatArr = await db.select().from(chats).where(eq(chats.tenantId, tenantId));
    let chat = null;

    if (chatArr.length === 0) {
      const tenantRec = await db.select().from(tenants).where(eq(tenants.id, tenantId));
      if (tenantRec.length === 0) return res.status(404).json({ message: 'Tenant not found.' });
      
      chat = {
        id: 'chat-' + uuidv4(),
        tenantId,
        tenantName: tenantRec[0].name,
        tenantPhoto: tenantRec[0].photo,
        unreadCount: 0,
        messages: [],
        lastUpdated: new Date().toISOString()
      };
      await db.insert(chats).values(chat);
    } else {
      chat = chatArr[0];
    }

    // Sanitize XSS tags in chat texts
    const sanitizedText = text ? sanitizeHtml(text) : '';
    const newMsg = {
      id: 'msg-' + uuidv4(),
      sender,
      text: sanitizedText,
      timestamp: new Date().toISOString(),
      seen: false
    };

    if (attachment) {
      newMsg.attachment = sanitizeHtml(attachment);
      newMsg.attachmentType = attachmentType || 'image';
    }

    const updatedMessagesList = [...(chat.messages || []), newMsg];
    const updatePayload = {
      messages: updatedMessagesList,
      lastUpdated: new Date().toISOString()
    };

    if (sender !== 'owner') {
      updatePayload.unreadCount = chat.unreadCount + 1;
    }

    await db.update(chats).set(updatePayload).where(eq(chats.id, chat.id));
    res.status(201).json({ success: true, message: newMsg });
  } catch (error) {
    next(error);
  }
});

// Mark chat as read
app.post('/api/chats/:id/seen', authenticateJWT, verifyOwnership('chat'), async (req, res, next) => {
  try {
    const tenantId = req.params.id;
    const { sender } = req.body; // 'owner' or 'tenant' mark seen

    const chatArr = await db.select().from(chats).where(eq(chats.tenantId, tenantId));
    if (chatArr.length > 0) {
      const chat = chatArr[0];
      const updatedMessages = (chat.messages || []).map(m => {
        if (m.sender !== sender) m.seen = true;
        return m;
      });

      const updatePayload = { messages: updatedMessages };
      if (sender === 'owner') {
        updatePayload.unreadCount = 0;
      }

      await db.update(chats).set(updatePayload).where(eq(chats.id, chat.id));
    }

    res.json({ success: true });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// DOCUMENT UPLOADS & SIGNED URL SERVICE (Secure object store)
// ==============================================================

// Upload files inside Private Storage
app.post('/api/documents/upload', authenticateJWT, uploadLimiter, upload.single('document'), validateFileSize, async (req, res, next) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No file uploaded.' });
    }
    
    // Logs upload transaction
    await logAuditAction(req, 'UPLOAD_DOCUMENT', null, { originalname: req.file.originalname, secureFilename: req.file.filename });
    res.json({ 
      success: true, 
      filename: req.file.filename,
      mimetype: req.file.mimetype 
    });
  } catch (error) {
    next(error);
  }
});

// Generate Short-lived signed download link (expires in 5 minutes)
app.get('/api/documents/signed-url/:filename', authenticateJWT, async (req, res, next) => {
  try {
    const { filename } = req.params;
    const userId = req.user.id;
    const role = req.user.role;

    // Verify ownership of the file before signing url
    if (role === 'tenant') {
      const tenantRecs = await db.select().from(tenants).where(eq(tenants.userId, userId));
      if (tenantRecs.length === 0) return res.status(403).json({ message: 'Forbidden. Unauthorized user.' });
      
      const tenant = tenantRecs[0];
      const docs = tenant.documents || {};
      const matches = Object.values(docs).includes(filename);
      if (!matches) {
        return res.status(403).json({ message: 'Forbidden. You do not own this document.' });
      }
    }

    // Sign a temporary token for the file (Valid for 5 minutes)
    const token = jwt.sign(
      { filename, userId, role }, 
      JWT_SECRET, 
      { expiresIn: '5m' }
    );

    // Return the safe signed URL route
    const signedUrl = `${req.protocol}://${req.get('host')}/api/documents/download/${filename}?token=${token}`;
    res.json({ success: true, url: signedUrl });
  } catch (error) {
    next(error);
  }
});

// Retrieve file via signed URL verification (Forbidden on standard /uploads paths)
app.get('/api/documents/download/:filename', async (req, res, next) => {
  try {
    const { filename } = req.params;
    const { token } = req.query;

    if (!token) {
      return res.status(403).json({ message: 'Forbidden. Signed token is missing.' });
    }

    // Verify signed JWT signature
    let decoded = null;
    try {
      decoded = jwt.verify(token, JWT_SECRET);
    } catch (e) {
      return res.status(403).json({ message: 'Forbidden. Signed URL token has expired or is invalid.' });
    }

    if (decoded.filename !== filename) {
      return res.status(403).json({ message: 'Forbidden. File mismatch.' });
    }

    const filePath = path.join(UPLOAD_DIR, filename);
    if (!fs.existsSync(filePath)) {
      return res.status(404).json({ message: 'File not found.' });
    }

    // Enforce Content-Disposition headers for PDF download streams
    res.setHeader('Content-Security-Policy', "default-src 'self'");
    res.sendFile(filePath);
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// NOTIFICATIONS APIs
// ==============================================================

// Get notifications for the logged-in user based on role
app.get('/api/notifications', authenticateJWT, async (req, res, next) => {
  try {
    let notifList = [];
    if (req.user.role === 'tenant') {
      // Tenant gets their own notifications
      const tenantRec = await db.select().from(tenants).where(eq(tenants.userId, req.user.id));
      if (tenantRec.length > 0) {
        notifList = await db.select().from(notifications).where(
          and(eq(notifications.tenantId, tenantRec[0].id), eq(notifications.forRole, 'tenant'))
        );
      }
    } else {
      // Owner sees all owner-targeted notifications
      notifList = await db.select().from(notifications).where(eq(notifications.forRole, 'owner'));
    }
    res.json(notifList);
  } catch (error) {
    next(error);
  }
});

// Mark all notifications as read for the logged-in user
app.post('/api/notifications/mark-all-read', authenticateJWT, async (req, res, next) => {
  try {
    if (req.user.role === 'tenant') {
      const tenantRec = await db.select().from(tenants).where(eq(tenants.userId, req.user.id));
      if (tenantRec.length > 0) {
        await db.update(notifications)
          .set({ read: true })
          .where(and(eq(notifications.tenantId, tenantRec[0].id), eq(notifications.forRole, 'tenant')));
      }
    } else {
      await db.update(notifications)
        .set({ read: true })
        .where(eq(notifications.forRole, 'owner'));
    }
    res.json({ success: true, message: 'All notifications marked as read.' });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// AUDIT LOGS & BACKUPS APIs (Owner strictly)
// ==============================================================
app.get('/api/audit-logs', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const logs = await db.select().from(auditLogs).orderBy(desc(auditLogs.timestamp)).limit(50);
    res.json(logs);
  } catch (error) {
    next(error);
  }
});

// Seed trigger route
app.post('/api/database/seed', async (req, res, next) => {
  try {
    const { seed } = require('./src/db/seed');
    await seed();
    res.json({ success: true, message: 'Seed run completed.' });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// TENANT LOGIN (User ID + Password)
// ==============================================================
app.post('/api/auth/tenant-login', loginLimiter, async (req, res, next) => {
  try {
    const { tenantLoginId, password } = req.body;
    if (!tenantLoginId || !password) {
      return res.status(400).json({ message: 'Tenant User ID and password are required.' });
    }

    // Find user by tenantLoginId
    const matchedUsers = await db.select().from(users).where(
      and(eq(users.tenantLoginId, tenantLoginId.toUpperCase()), eq(users.role, 'tenant'))
    );

    if (matchedUsers.length === 0) {
      return res.status(401).json({ message: 'Invalid User ID or password.' });
    }

    const user = matchedUsers[0];

    // Check if login is enabled
    if (user.loginEnabled === false) {
      return res.status(403).json({ message: 'Your account has been disabled. Please contact your landlord.' });
    }

    // Verify password
    const isPasswordValid = await bcrypt.compare(password, user.passwordHash);
    if (!isPasswordValid) {
      return res.status(401).json({ message: 'Invalid User ID or password.' });
    }

    // Issue tokens
    const accessToken = jwt.sign(
      { id: user.id, email: user.email, phone: user.phone, role: user.role, tenantLoginId: user.tenantLoginId },
      JWT_SECRET,
      { expiresIn: '15m' }
    );
    const refreshToken = jwt.sign({ id: user.id }, JWT_REFRESH_SECRET, { expiresIn: '30d' });

    await db.update(users)
      .set({ refreshToken, sessionActive: true, lastActive: new Date().toISOString(), deviceInfo: req.headers['user-agent'] || 'unknown' })
      .where(eq(users.id, user.id));

    await createSession(user.id, req, refreshToken);

    const isProd = process.env.NODE_ENV === 'production' || (req.headers.host && req.headers.host.includes('vercel.app'));
    res.cookie('accessToken', accessToken, { httpOnly: true, secure: isProd, sameSite: isProd ? 'none' : 'lax', maxAge: 15 * 60 * 1000 });
    res.cookie('refreshToken', refreshToken, { httpOnly: true, secure: isProd, sameSite: isProd ? 'none' : 'lax', maxAge: 30 * 24 * 60 * 60 * 1000 });

    req.user = { id: user.id, role: user.role };
    await logAuditAction(req, 'TENANT_LOGIN_SUCCESS', null, { tenantLoginId });

    res.json({
      success: true,
      isFirstLogin: user.isFirstLogin || false,
      accessToken,
      refreshToken,
      user: { id: user.id, email: user.email, phone: user.phone, role: user.role, tenantLoginId: user.tenantLoginId }
    });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// FIRST LOGIN — FORCE PASSWORD CHANGE
// ==============================================================
app.post('/api/auth/change-password-first', authenticateJWT, async (req, res, next) => {
  try {
    const { oldPassword, newPassword } = req.body;

    if (!newPassword || newPassword.length < 8) {
      return res.status(400).json({ message: 'New password must be at least 8 characters.' });
    }

    // Validate strength: must have uppercase, lowercase, number, special char
    const hasUpper = /[A-Z]/.test(newPassword);
    const hasLower = /[a-z]/.test(newPassword);
    const hasNum = /[0-9]/.test(newPassword);
    const hasSpecial = /[^A-Za-z0-9]/.test(newPassword);

    if (!hasUpper || !hasLower || !hasNum || !hasSpecial) {
      return res.status(400).json({ message: 'Password must contain uppercase, lowercase, number and special character.' });
    }

    const userRecord = await db.select().from(users).where(eq(users.id, req.user.id));
    if (userRecord.length === 0) return res.status(404).json({ message: 'User not found.' });
    const user = userRecord[0];

    const isOldValid = await bcrypt.compare(oldPassword, user.passwordHash);
    if (!isOldValid) {
      return res.status(400).json({ message: 'Incorrect old/temporary password.' });
    }

    // Prevent reuse of old password
    const isSamePassword = await bcrypt.compare(newPassword, user.passwordHash);
    if (isSamePassword) {
      return res.status(400).json({ message: 'New password cannot be the same as old password.' });
    }

    const hashedNew = await bcrypt.hash(newPassword, 10);
    await db.update(users).set({ passwordHash: hashedNew, isFirstLogin: false }).where(eq(users.id, user.id));

    await logAuditAction(req, 'FIRST_LOGIN_PASSWORD_CHANGED', null, { userId: user.id });

    res.json({ success: true, message: 'Password changed successfully.', user: { id: user.id, role: user.role } });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// ACTIVE SESSIONS API
// ==============================================================

// List all active sessions for the current user
app.get('/api/auth/sessions', authenticateJWT, async (req, res, next) => {
  try {
    const activeSessions = await db.select().from(sessions).where(
      and(eq(sessions.userId, req.user.id), eq(sessions.isActive, true))
    ).orderBy(desc(sessions.lastActive));
    res.json(activeSessions);
  } catch (error) {
    next(error);
  }
});

// Logout a specific session by ID
app.delete('/api/auth/sessions/:sessionId', authenticateJWT, async (req, res, next) => {
  try {
    const sessionRecord = await db.select().from(sessions).where(eq(sessions.id, req.params.sessionId));
    if (sessionRecord.length === 0) return res.status(404).json({ message: 'Session not found.' });

    // Ensure user can only delete their own sessions (owners can delete tenant sessions)
    if (req.user.role !== 'owner' && sessionRecord[0].userId !== req.user.id) {
      return res.status(403).json({ message: 'Access denied.' });
    }

    await db.update(sessions).set({ isActive: false }).where(eq(sessions.id, req.params.sessionId));
    await logAuditAction(req, 'LOGOUT_SESSION', { sessionId: req.params.sessionId });

    res.json({ success: true, message: 'Session logged out.' });
  } catch (error) {
    next(error);
  }
});

// Owner: force-logout a specific tenant (all their sessions)
app.post('/api/auth/force-logout/:userId', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const targetUserId = req.params.userId;

    await db.update(sessions).set({ isActive: false }).where(eq(sessions.userId, targetUserId));
    await db.update(users).set({ refreshToken: null, sessionActive: false }).where(eq(users.id, targetUserId));

    await logAuditAction(req, 'OWNER_FORCE_LOGOUT', null, { targetUserId });
    res.json({ success: true, message: 'Tenant forcibly logged out from all devices.' });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// TENANT CREDENTIAL MANAGEMENT (Owner only)
// ==============================================================

// Create / Update tenant login credentials (User ID + temp password)
app.patch('/api/tenants/:id/credentials', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const tenantId = req.params.id;
    const { tenantLoginId: newLoginId, tempPassword } = req.body;

    if (!newLoginId) return res.status(400).json({ message: 'Tenant User ID is required.' });

    const tenantArr = await db.select().from(tenants).where(eq(tenants.id, tenantId));
    if (tenantArr.length === 0) return res.status(404).json({ message: 'Tenant not found.' });
    const tenant = tenantArr[0];

    // Check if tenantLoginId is already taken by another user
    const existing = await db.select().from(users).where(
      and(eq(users.tenantLoginId, newLoginId.toUpperCase()), ne(users.id, tenant.userId))
    );
    if (existing.length > 0) {
      return res.status(409).json({ message: `User ID "${newLoginId}" is already in use.` });
    }

    const updates = { tenantLoginId: newLoginId.toUpperCase() };
    if (tempPassword) {
      updates.passwordHash = await bcrypt.hash(tempPassword, 10);
      updates.isFirstLogin = true; // Force password change on next login
    }

    await db.update(users).set(updates).where(eq(users.id, tenant.userId));
    await logAuditAction(req, 'OWNER_SET_TENANT_CREDENTIALS', null, { tenantId, newLoginId });

    res.json({ success: true, message: 'Tenant credentials updated successfully.', tenantLoginId: newLoginId.toUpperCase() });
  } catch (error) {
    next(error);
  }
});

// Owner: Reset tenant password (generates temp password, forces first-login change)
app.post('/api/tenants/:id/reset-password', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const tenantId = req.params.id;
    const { newPassword } = req.body;

    const tenantArr = await db.select().from(tenants).where(eq(tenants.id, tenantId));
    if (tenantArr.length === 0) return res.status(404).json({ message: 'Tenant not found.' });
    const tenant = tenantArr[0];

    // Generate temp password if not provided
    const tempPwd = newPassword || `Temp@${Math.floor(100000 + Math.random() * 900000)}`;
    const hashedPwd = await bcrypt.hash(tempPwd, 10);

    await db.update(users).set({ passwordHash: hashedPwd, isFirstLogin: true }).where(eq(users.id, tenant.userId));

    // Force logout existing sessions
    await db.update(sessions).set({ isActive: false }).where(eq(sessions.userId, tenant.userId));
    await db.update(users).set({ refreshToken: null, sessionActive: false }).where(eq(users.id, tenant.userId));

    await logAuditAction(req, 'OWNER_RESET_TENANT_PASSWORD', null, { tenantId });

    res.json({ success: true, message: 'Password reset successfully.', tempPassword: tempPwd });
  } catch (error) {
    next(error);
  }
});

// Owner: Enable or disable tenant login
app.patch('/api/tenants/:id/toggle-login', authenticateJWT, authorizeRoles('owner'), async (req, res, next) => {
  try {
    const tenantId = req.params.id;
    const { enabled } = req.body;

    const tenantArr = await db.select().from(tenants).where(eq(tenants.id, tenantId));
    if (tenantArr.length === 0) return res.status(404).json({ message: 'Tenant not found.' });
    const tenant = tenantArr[0];

    await db.update(users).set({ loginEnabled: enabled }).where(eq(users.id, tenant.userId));

    // If disabling, force logout all sessions
    if (!enabled) {
      await db.update(sessions).set({ isActive: false }).where(eq(sessions.userId, tenant.userId));
      await db.update(users).set({ refreshToken: null, sessionActive: false }).where(eq(users.id, tenant.userId));
    }

    await logAuditAction(req, enabled ? 'OWNER_ENABLE_TENANT_LOGIN' : 'OWNER_DISABLE_TENANT_LOGIN', null, { tenantId, enabled });

    res.json({ success: true, message: `Tenant login ${enabled ? 'enabled' : 'disabled'}.`, loginEnabled: enabled });
  } catch (error) {
    next(error);
  }
});

// ==============================================================
// ERROR HANDLING MIDDLEWARE (Mask internal details)
// ==============================================================
app.use((err, req, res, next) => {
  // Log full trace to server logs solely
  console.error('💥 Server Stack Trace:', err.stack || err.message);
  
  // Return generalized user alert to block SQL/Stack leaks
  res.status(500).json({ message: 'Something went wrong.' });
});

// Launch server listener
app.listen(PORT, () => {
  console.log(`Rentify API secure server running on port ${PORT}`);
});
