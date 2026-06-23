const jwt = require('jsonwebtoken');
const { db } = require('../db/index');
const { users } = require('../db/schema');
const { eq } = require('drizzle-orm');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const JWT_SECRET = process.env.JWT_SECRET || 'rentify_access_token_secret_99881122';
const JWT_REFRESH_SECRET = process.env.JWT_REFRESH_SECRET || 'rentify_refresh_token_secret_22118899';

// Middleware to verify JWT tokens
async function authenticateJWT(req, res, next) {
  // Read token from header or cookie
  let token = null;
  const authHeader = req.headers.authorization;
  
  if (authHeader && authHeader.startsWith('Bearer ')) {
    token = authHeader.split(' ')[1];
  } else if (req.cookies && req.cookies.accessToken) {
    token = req.cookies.accessToken;
  }

  if (!token) {
    // If access token is missing, attempt to refresh session automatically using Refresh Token
    return handleSessionRefresh(req, res, next);
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.user = decoded;
    
    // Update last active status in DB
    await db.update(users)
      .set({ lastActive: new Date().toISOString() })
      .where(eq(users.id, decoded.id));
      
    return next();
  } catch (err) {
    if (err.name === 'TokenExpiredError') {
      // Access token expired, attempt refresh
      return handleSessionRefresh(req, res, next);
    }
    return res.status(401).json({ message: 'Authentication failed. Session invalid.' });
  }
}

// Session Refresh mechanism
async function handleSessionRefresh(req, res, next) {
  let refreshToken = null;
  if (req.cookies && req.cookies.refreshToken) {
    refreshToken = req.cookies.refreshToken;
  } else if (req.headers['x-refresh-token']) {
    refreshToken = req.headers['x-refresh-token'];
  }

  if (!refreshToken) {
    return res.status(401).json({ message: 'Session expired. Please log in again.' });
  }

  try {
    const decoded = jwt.verify(refreshToken, JWT_REFRESH_SECRET);
    
    // Check if refresh token is registered in Database
    const userRecords = await db.select().from(users).where(eq(users.id, decoded.id));
    if (userRecords.length === 0) {
      return res.status(401).json({ message: 'User session not found.' });
    }
    
    const user = userRecords[0];
    if (user.refreshToken !== refreshToken || !user.sessionActive) {
      return res.status(401).json({ message: 'Session revoked or logged out.' });
    }

    // Generate new Access Token (expires in 15 mins)
    const newAccessToken = jwt.sign(
      { id: user.id, email: user.email, phone: user.phone, role: user.role },
      JWT_SECRET,
      { expiresIn: '15m' }
    );

    // Set new cookie on web client
    res.cookie('accessToken', newAccessToken, {
      httpOnly: true,
      secure: process.env.NODE_ENV === 'production',
      sameSite: 'strict',
      maxAge: 15 * 60 * 1000 // 15 mins
    });

    // Provide token to downstream
    req.user = { id: user.id, email: user.email, phone: user.phone, role: user.role };
    
    // Update last active
    await db.update(users)
      .set({ lastActive: new Date().toISOString() })
      .where(eq(users.id, user.id));

    return next();
  } catch (refreshErr) {
    return res.status(401).json({ message: 'Session expired. Please sign in.' });
  }
}

// Middleware to enforce RBAC role permissions
function authorizeRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ message: 'Authentication required.' });
    }
    if (!allowedRoles.includes(req.user.role)) {
      return res.status(403).json({ message: 'Forbidden. Insufficient permissions.' });
    }
    next();
  };
}

module.exports = {
  authenticateJWT,
  authorizeRoles
};
