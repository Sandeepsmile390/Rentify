const { pgTable, varchar, integer, boolean, text, jsonb } = require('drizzle-orm/pg-core');

// 1. Users Table
const users = pgTable('users', {
  id: varchar('id', { length: 256 }).primaryKey(),
  email: varchar('email', { length: 256 }).unique(),
  phone: varchar('phone', { length: 256 }).unique(),
  passwordHash: varchar('password_hash', { length: 512 }).notNull(),
  role: varchar('role', { length: 50 }).notNull(), // 'owner' or 'tenant'
  refreshToken: varchar('refresh_token', { length: 1024 }),
  sessionActive: boolean('session_active').default(false),
  deviceInfo: varchar('device_info', { length: 512 }),
  lastActive: varchar('last_active', { length: 256 }),

  // Auth system extensions
  tenantLoginId: varchar('tenant_login_id', { length: 100 }), // e.g. TENANT-101
  isFirstLogin: boolean('is_first_login').default(false),      // Force password change on first login
  loginEnabled: boolean('login_enabled').default(true),        // Owner can disable tenant login
});

// 2. Properties Table
const properties = pgTable('properties', {
  id: varchar('id', { length: 256 }).primaryKey(),
  name: varchar('name', { length: 256 }).notNull(),
  type: varchar('type', { length: 100 }).default('Residential'),
  totalRooms: integer('total_rooms').default(0),
  occupied: integer('occupied').default(0),
  vacant: integer('vacant').default(0),
  monthlyRevenue: integer('monthly_revenue').default(0),
  ownerId: varchar('owner_id', { length: 256 }).default('owner-admin')
});

// 3. Tenants Table
const tenants = pgTable('tenants', {
  id: varchar('id', { length: 256 }).primaryKey(),
  userId: varchar('user_id', { length: 256 }).references(() => users.id),
  name: varchar('name', { length: 256 }).notNull(),
  fatherName: varchar('father_name', { length: 256 }),
  phone: varchar('phone', { length: 256 }).notNull(),
  altPhone: varchar('alt_phone', { length: 256 }),
  email: varchar('email', { length: 256 }),
  occupation: varchar('occupation', { length: 256 }),
  
  // Sensitive personal data encrypted using AES-256
  aadhaarEncrypted: text('aadhaar_encrypted'),
  panEncrypted: text('pan_encrypted'),
  permanentAddressEncrypted: text('permanent_address_encrypted'),
  emergencyContactEncrypted: text('emergency_contact_encrypted'),
  
  currentAddress: varchar('current_address', { length: 512 }),
  propertyId: varchar('property_id', { length: 256 }).references(() => properties.id),
  propertyName: varchar('property_name', { length: 256 }),
  roomNumber: varchar('room_number', { length: 100 }).notNull(),
  roomType: varchar('room_type', { length: 100 }).default('Room'),
  moveInDate: varchar('move_in_date', { length: 100 }),
  agreementDuration: integer('agreement_duration').default(12),
  rentAmount: integer('rent_amount').default(0),
  securityDeposit: integer('security_deposit').default(0),
  electricityRate: integer('electricity_rate').default(6),
  waterCharges: integer('water_charges').default(0),
  status: varchar('status', { length: 50 }).default('Active'), // 'Active', 'Leaving', 'Left'
  photo: varchar('photo', { length: 512 }),
  documents: jsonb('documents').default({}), // Profile, Aadhaar front/back, PAN, rental agreement
  leftDate: varchar('left_date', { length: 100 }),
  archiveDate: varchar('archive_date', { length: 100 })
});

// 4. Bills Table
const bills = pgTable('bills', {
  id: varchar('id', { length: 256 }).primaryKey(),
  tenantId: varchar('tenant_id', { length: 256 }).references(() => tenants.id),
  tenantName: varchar('tenant_name', { length: 256 }),
  roomNumber: varchar('room_number', { length: 100 }),
  propertyName: varchar('property_name', { length: 256 }),
  billingMonth: varchar('billing_month', { length: 100 }).notNull(),
  rentAmount: integer('rent_amount').default(0),
  electricityUnits: integer('electricity_units').default(0),
  electricityRate: integer('electricity_rate').default(6),
  electricityAmount: integer('electricity_amount').default(0),
  waterCharges: integer('water_charges').default(0),
  lateFee: integer('late_fee').default(0),
  discount: integer('discount').default(0),
  extraCharges: integer('extra_charges').default(0),
  extraChargesReason: varchar('extra_charges_reason', { length: 512 }),
  totalAmount: integer('total_amount').default(0),
  paidAmount: integer('paid_amount').default(0),
  pendingAmount: integer('pending_amount').default(0),
  status: varchar('status', { length: 50 }).default('Unpaid'), // 'Paid', 'Partial Paid', 'Unpaid'
  dueDate: varchar('due_date', { length: 100 }),
  payments: jsonb('payments').default([]) // Array of payment receipts
});

// 5. Comments Table
const comments = pgTable('comments', {
  id: varchar('id', { length: 256 }).primaryKey(),
  tenantId: varchar('tenant_id', { length: 256 }).references(() => tenants.id),
  tenantName: varchar('tenant_name', { length: 256 }),
  roomNumber: varchar('room_number', { length: 100 }),
  title: varchar('title', { length: 256 }).notNull(),
  category: varchar('category', { length: 100 }).default('Maintenance'),
  status: varchar('status', { length: 50 }).default('Open'), // 'Open', 'In Progress', 'Resolved'
  createdAt: varchar('created_at', { length: 100 }),
  unreadByOwner: boolean('unread_by_owner').default(true),
  unreadByTenant: boolean('unread_by_tenant').default(false),
  replies: jsonb('replies').default([]) // Chat thread array
});

// 6. Chats Table
const chats = pgTable('chats', {
  id: varchar('id', { length: 256 }).primaryKey(),
  tenantId: varchar('tenant_id', { length: 256 }).references(() => tenants.id),
  tenantName: varchar('tenant_name', { length: 256 }),
  tenantPhoto: varchar('tenant_photo', { length: 512 }),
  unreadCount: integer('unread_count').default(0),
  lastUpdated: varchar('last_updated', { length: 100 }),
  messages: jsonb('messages').default([]) // Chat bubble array
});

// 7. Notifications Table
const notifications = pgTable('notifications', {
  id: varchar('id', { length: 256 }).primaryKey(),
  tenantId: varchar('tenant_id', { length: 256 }),
  title: varchar('title', { length: 256 }).notNull(),
  message: varchar('message', { length: 512 }).notNull(),
  time: varchar('time', { length: 100 }),
  forRole: varchar('for_role', { length: 50 }).notNull(), // 'owner' or 'tenant'
  read: boolean('read').default(false)
});

// 8. Audit Logs Table
const auditLogs = pgTable('audit_logs', {
  id: varchar('id', { length: 256 }).primaryKey(),
  userId: varchar('user_id', { length: 256 }),
  role: varchar('role', { length: 50 }),
  action: varchar('action', { length: 256 }).notNull(),
  oldValue: text('old_value'),
  newValue: text('new_value'),
  ipAddress: varchar('ip_address', { length: 100 }),
  deviceInfo: varchar('device_info', { length: 512 }),
  timestamp: varchar('timestamp', { length: 100 })
});

// 9. Sessions Table — device tracking per user
const sessions = pgTable('sessions', {
  id: varchar('id', { length: 256 }).primaryKey(),
  userId: varchar('user_id', { length: 256 }).references(() => users.id),
  deviceName: varchar('device_name', { length: 256 }).default('Unknown Device'),
  browser: varchar('browser', { length: 256 }).default('Unknown Browser'),
  os: varchar('os', { length: 256 }).default('Unknown OS'),
  ipAddress: varchar('ip_address', { length: 100 }),
  location: varchar('location', { length: 256 }).default('Unknown Location'),
  lastActive: varchar('last_active', { length: 100 }),
  isActive: boolean('is_active').default(true),
  tokenHash: varchar('token_hash', { length: 256 }), // Identifies which refresh token this session uses
  createdAt: varchar('created_at', { length: 100 })
});

module.exports = {
  users,
  properties,
  tenants,
  bills,
  comments,
  chats,
  notifications,
  auditLogs,
  sessions
};
