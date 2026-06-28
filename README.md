# 🏠 Rentify — Smart Property & Rent Management System

A production-grade, full-stack rent management system for modern landlords and tenants.

![RentFlow](https://img.shields.io/badge/RentFlow-v1.0.0-6366f1?style=for-the-badge&logo=home)
![Node.js](https://img.shields.io/badge/Node.js-Express-43853d?style=for-the-badge&logo=node.js)
![React](https://img.shields.io/badge/React-Vite-61dafb?style=for-the-badge&logo=react)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Drizzle_ORM-336791?style=for-the-badge&logo=postgresql)

---

## 🚀 Project Overview

RentFlow is a **three-tier application** that allows property owners to manage tenants, bills, and communications, while tenants can access their rent summaries, billing history, and chat with their landlord.

| Directory | Technology | Purpose |
|-----------|-----------|---------|
| `api/` | Node.js + Express + PostgreSQL | REST API Backend |
| `web/` | Vite + React.js | Owner Web Dashboard |
| `mobile/` | Expo + React Native | Tenant Mobile App |

---

## 🔐 Security Features

- **JWT Authentication** — Access tokens (15 min) + Refresh tokens (30 days)
- **bcrypt** password hashing — never plain text
- **AES-256-CBC** encryption for Aadhaar, PAN, Address data
- **RBAC** — Owner and Tenant roles with strict route-level enforcement
- **Rate limiting** — 5 req/min on login, 100 req/min general
- **Device session tracking** — logout single device or all devices
- **Helmet.js** security headers, **CORS** strict origin policy
- **Zod validation** + **sanitize-html** on all inputs
- **HttpOnly, SameSite=Strict cookies** (web) + **SecureStore** (mobile)

---

## 👥 User Roles

### 🏠 Owner / Admin
- Login: Email or Phone + Password
- Manage properties, check-in/out tenants
- Generate monthly bills, record payments
- View financial reports and audit logs
- Chat with tenants, resolve maintenance tickets
- Manage tenant login credentials

### 👤 Tenant
- Login: Tenant User ID (e.g. `TENANT-101`) + Password
- View rent summary and billing history
- Submit maintenance requests
- Chat with landlord
- Download invoices

---

## 📋 Auth Flow

1. **Owner Login** → `POST /api/auth/login` with email/phone + password
2. **Tenant Login** → `POST /api/auth/tenant-login` with tenantLoginId + password
3. **First Login** → If `isFirstLogin: true`, tenant must change password before accessing dashboard
4. **Token Refresh** → Automatic via refresh token cookie (web) or `x-refresh-token` header (mobile)

---

## 🗄️ Database Schema

| Table | Purpose |
|-------|---------|
| `users` | Auth credentials + session tokens |
| `properties` | Owner's buildings |
| `tenants` | Tenant KYC profiles (AES-encrypted sensitive fields) |
| `bills` | Monthly rent + utility invoices |
| `comments` | Maintenance ticket threads |
| `chats` | Direct messaging |
| `notifications` | System alerts |
| `audit_logs` | Full write-operation audit trail |
| `sessions` | Per-device session tracking |

---

## 🚀 How to Run

### Prerequisites
- Node.js v18+
- PostgreSQL (running locally or cloud)

### 1. API Server
```bash
cd api
npm install
# Edit .env with your PostgreSQL connection string
npm start
# → http://localhost:5000
```

### 2. Web App
```bash
cd web
npm install
npm run dev
# → http://localhost:5173
```

### 3. Mobile App (Expo)
```bash
cd mobile
npm install
npx expo start
# Scan QR with Expo Go app on your phone
```

---

## 🌱 Seed Data (Test Credentials)

| Role | Login | Password |
|------|-------|----------|
| Owner | `admin@rentify.com` or `9999999999` | `password` |
| Tenant (Ravi) | `TENANT-101` | `password` |
| Tenant (Priya) | `TENANT-102` | `password` |
| Tenant (Amit) | `TENANT-103` | `password` |

To seed the database:
```bash
cd api
node -e "const {seed}=require('./src/db/seed'); seed().then(() => process.exit(0))"
```

---

## 📁 Project Structure

```
Rentify/
├── api/                          # Express REST API
│   ├── server.js                 # Main server with all routes
│   ├── .env.example              # Environment template
│   └── src/
│       ├── db/
│       │   ├── index.js          # PostgreSQL connection pool
│       │   ├── schema.js         # Drizzle ORM table definitions
│       │   └── seed.js           # Sample seed data
│       ├── middleware/
│       │   ├── auth.js           # JWT authentication + RBAC
│       │   ├── ownership.js      # Resource ownership checks
│       │   └── upload.js         # Multer file handler
│       └── utils/
│           ├── crypto.js         # AES-256 encrypt/decrypt
│           └── validation.js     # Zod input schemas
│
├── web/                          # React.js Owner Portal (Vite)
│   └── src/
│       ├── App.jsx               # Full SPA (dashboard, tenants, bills)
│       ├── index.css             # Premium CSS design system
│       └── components/
│           ├── AuthFlow.jsx      # Multi-screen auth (role select, login, first-login)
│           └── Logo.jsx          # Brand logo component
│
└── mobile/                       # React Native Tenant App (Expo)
    ├── App.js                    # Navigation stack
    └── src/
        ├── services/
        │   └── api.js            # Axios client with JWT interceptors
        └── screens/
            ├── auth/
            │   ├── RoleSelectScreen.js
            │   ├── OwnerLoginScreen.js
            │   ├── TenantLoginScreen.js
            │   ├── FirstLoginScreen.js
            │   ├── BiometricScreen.js
            │   └── AppLockScreen.js
            ├── HomeScreen.js
            ├── BillsScreen.js
            ├── ChatScreen.js
            ├── ProfileScreen.js
            ├── ActiveSessionsScreen.js
            └── AppLockSettingsScreen.js
```

---

## 🛡️ Environment Variables

Copy `api/.env.example` to `api/.env` and fill in your values:

```env
PORT=5000
NODE_ENV=development
DATABASE_URL=postgresql://user:password@localhost:5432/rentify
JWT_SECRET=your_access_token_secret_here
JWT_REFRESH_SECRET=your_refresh_token_secret_here
ENCRYPTION_KEY=your_64_char_hex_key_here
```

---

## 📄 License

MIT License — Free to use and modify.

---

Built with ❤️ by [Sandeep Kumar](https://github.com/Sandeepsmile390)
