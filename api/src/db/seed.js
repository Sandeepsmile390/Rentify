const { db } = require('./index');
const { users, properties, tenants, bills, comments, chats, notifications, sessions } = require('./schema');
const bcrypt = require('bcrypt');
const cryptoUtils = require('../utils/crypto');

async function seed() {
  console.log('🌱 Starting database seeding...');
  
  try {
    // 1. Hash a default password
    const saltRounds = 10;
    const passwordHash = await bcrypt.hash('password', saltRounds);

    // 2. Create Users
    console.log('Inserting users...');
    const seedUsers = [
      {
        id: 'owner-admin',
        email: 'admin@rentify.com',
        phone: '9999999999',
        passwordHash: passwordHash,
        role: 'owner',
        sessionActive: false,
        loginEnabled: true,
        isFirstLogin: false
      },
      {
        id: 'user-tenant-1',
        email: 'ravi.kumar@gmail.com',
        phone: '9876543210',
        passwordHash: passwordHash,
        role: 'tenant',
        sessionActive: false,
        tenantLoginId: 'TENANT-101',
        loginEnabled: true,
        isFirstLogin: false
      },
      {
        id: 'user-tenant-2',
        email: 'priya.sharma@yahoo.com',
        phone: '9812345678',
        passwordHash: passwordHash,
        role: 'tenant',
        sessionActive: false,
        tenantLoginId: 'TENANT-102',
        loginEnabled: true,
        isFirstLogin: false
      },
      {
        id: 'user-tenant-3',
        email: 'amit.patel@gmail.com',
        phone: '9012345678',
        passwordHash: passwordHash,
        role: 'tenant',
        sessionActive: false,
        tenantLoginId: 'TENANT-103',
        loginEnabled: true,
        isFirstLogin: false
      }
    ];

    for (const u of seedUsers) {
      await db.insert(users).values(u).onConflictDoNothing();
    }

    // 3. Create Properties
    console.log('Inserting properties...');
    const seedProperties = [
      { id: 'prop-1', name: 'House A', type: 'Residential', totalRooms: 10, occupied: 2, vacant: 8, monthlyRevenue: 6000 },
      { id: 'prop-2', name: 'House B', type: 'Residential', totalRooms: 15, occupied: 0, vacant: 15, monthlyRevenue: 0 },
      { id: 'prop-3', name: 'Shop Complex', type: 'Commercial', totalRooms: 5, occupied: 1, vacant: 4, monthlyRevenue: 15000 }
    ];

    for (const p of seedProperties) {
      await db.insert(properties).values(p).onConflictDoNothing();
    }

    // 4. Create Tenants
    console.log('Inserting tenants...');
    const seedTenants = [
      {
        id: 'tenant-1',
        userId: 'user-tenant-1',
        name: 'Ravi Kumar',
        fatherName: 'Suresh Kumar',
        phone: '9876543210',
        altPhone: '9876543211',
        email: 'ravi.kumar@gmail.com',
        occupation: 'Software Engineer',
        
        // Encrypted sensitive fields (AES-256)
        aadhaarEncrypted: cryptoUtils.encrypt('1234 5678 9012'),
        panEncrypted: cryptoUtils.encrypt('ABCDE1234F'),
        permanentAddressEncrypted: cryptoUtils.encrypt('123, Main Street, Patna, Bihar'),
        emergencyContactEncrypted: cryptoUtils.encrypt('Suresh Kumar (Father) - 9876543211'),
        
        currentAddress: 'Room 101, House A, Rentify Complex',
        propertyId: 'prop-1',
        propertyName: 'House A',
        roomNumber: '101',
        roomType: 'Room',
        moveInDate: '2025-04-10',
        agreementDuration: 12,
        rentAmount: 2500,
        securityDeposit: 5000,
        electricityRate: 6,
        waterCharges: 150,
        status: 'Active',
        photo: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        documents: {
          profilePhoto: 'profile.jpg',
          aadhaarFront: 'aadhaar_front.jpg',
          aadhaarBack: 'aadhaar_back.jpg',
          pan: 'pan.jpg',
          agreement: 'agreement.pdf'
        }
      },
      {
        id: 'tenant-2',
        userId: 'user-tenant-2',
        name: 'Priya Sharma',
        fatherName: 'Ramesh Sharma',
        phone: '9812345678',
        altPhone: '9812345679',
        email: 'priya.sharma@yahoo.com',
        occupation: 'Teacher',
        
        aadhaarEncrypted: cryptoUtils.encrypt('9876 5432 1098'),
        panEncrypted: cryptoUtils.encrypt('WXYZP9876Q'),
        permanentAddressEncrypted: cryptoUtils.encrypt('Sector 15, Noida, UP'),
        emergencyContactEncrypted: cryptoUtils.encrypt('Ramesh Sharma (Father) - 9812345679'),
        
        currentAddress: 'Room 102, House A, Rentify Complex',
        propertyId: 'prop-1',
        propertyName: 'House A',
        roomNumber: '102',
        roomType: 'Room',
        moveInDate: '2025-05-01',
        agreementDuration: 11,
        rentAmount: 3500,
        securityDeposit: 7000,
        electricityRate: 6,
        waterCharges: 150,
        status: 'Active',
        photo: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        documents: {
          profilePhoto: 'profile_priya.jpg',
          aadhaarFront: 'aadhaar_p_front.jpg',
          aadhaarBack: 'aadhaar_p_back.jpg',
          pan: 'pan_p.jpg',
          agreement: 'agreement_p.pdf'
        }
      },
      {
        id: 'tenant-3',
        userId: 'user-tenant-3',
        name: 'Amit Patel',
        fatherName: 'Dinesh Patel',
        phone: '9012345678',
        altPhone: '9012345679',
        email: 'amit.patel@gmail.com',
        occupation: 'Retail Business Owner',
        
        aadhaarEncrypted: cryptoUtils.encrypt('1111 2222 3333'),
        panEncrypted: cryptoUtils.encrypt('KKKAA5555L'),
        permanentAddressEncrypted: cryptoUtils.encrypt('Vastrapur, Ahmedabad, Gujarat'),
        emergencyContactEncrypted: cryptoUtils.encrypt('Dinesh Patel (Father) - 9012345679'),
        
        currentAddress: 'Shop 3, Shop Complex, Rentify Complex',
        propertyId: 'prop-3',
        propertyName: 'Shop Complex',
        roomNumber: 'Shop 3',
        roomType: 'Shop',
        moveInDate: '2024-11-15',
        agreementDuration: 24,
        rentAmount: 15000,
        securityDeposit: 30000,
        electricityRate: 8,
        waterCharges: 500,
        status: 'Active',
        photo: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
        documents: {
          profilePhoto: 'profile_amit.jpg',
          aadhaarFront: 'aadhaar_a_front.jpg',
          aadhaarBack: 'aadhaar_a_back.jpg',
          pan: 'pan_a.jpg',
          agreement: 'agreement_a.pdf'
        }
      }
    ];

    for (const t of seedTenants) {
      await db.insert(tenants).values(t).onConflictDoNothing();
    }

    // 5. Create Bills
    console.log('Inserting bills...');
    const seedBills = [
      {
        id: 'bill-1',
        tenantId: 'tenant-1',
        tenantName: 'Ravi Kumar',
        roomNumber: '101',
        propertyName: 'House A',
        billingMonth: 'June 2026',
        rentAmount: 2500,
        electricityUnits: 100,
        electricityRate: 6,
        electricityAmount: 600,
        waterCharges: 150,
        lateFee: 0,
        discount: 0,
        extraCharges: 0,
        extraChargesReason: '',
        totalAmount: 3250,
        paidAmount: 3000,
        pendingAmount: 250,
        status: 'Partial Paid',
        dueDate: '2026-06-15',
        payments: [
          { date: '2026-06-10', amount: 2000, method: 'Cash', note: 'Advance partial' },
          { date: '2026-06-14', amount: 1000, method: 'UPI', note: 'Sent via GPay' }
        ]
      },
      {
        id: 'bill-2',
        tenantId: 'tenant-2',
        tenantName: 'Priya Sharma',
        roomNumber: '102',
        propertyName: 'House A',
        billingMonth: 'June 2026',
        rentAmount: 3500,
        electricityUnits: 120,
        electricityRate: 6,
        electricityAmount: 720,
        waterCharges: 150,
        lateFee: 0,
        discount: 100,
        extraCharges: 0,
        extraChargesReason: '',
        totalAmount: 4270,
        paidAmount: 4270,
        pendingAmount: 0,
        status: 'Paid',
        dueDate: '2026-06-15',
        payments: [
          { date: '2026-06-12', amount: 4270, method: 'Bank Transfer', note: 'NetBanking' }
        ]
      },
      {
        id: 'bill-3',
        tenantId: 'tenant-3',
        tenantName: 'Amit Patel',
        roomNumber: 'Shop 3',
        propertyName: 'Shop Complex',
        billingMonth: 'June 2026',
        rentAmount: 15000,
        electricityUnits: 450,
        electricityRate: 8,
        electricityAmount: 3600,
        waterCharges: 500,
        lateFee: 200,
        discount: 0,
        extraCharges: 0,
        extraChargesReason: '',
        totalAmount: 19300,
        paidAmount: 0,
        pendingAmount: 19300,
        status: 'Unpaid',
        dueDate: '2026-06-15',
        payments: []
      }
    ];

    for (const b of seedBills) {
      await db.insert(bills).values(b).onConflictDoNothing();
    }

    // 6. Create Comments
    console.log('Inserting comments...');
    const seedComments = [
      {
        id: 'comment-1',
        tenantId: 'tenant-1',
        tenantName: 'Ravi Kumar',
        roomNumber: '101',
        title: 'Fan is not working',
        category: 'Maintenance',
        status: 'In Progress',
        createdAt: '2026-06-20T10:00:00Z',
        unreadByOwner: true,
        unreadByTenant: false,
        replies: [
          {
            id: 'reply-1',
            sender: 'tenant',
            name: 'Ravi Kumar',
            message: 'The ceiling fan in Room 101 is making a humming sound and not spinning at speed.',
            createdAt: '2026-06-20T10:00:00Z'
          },
          {
            id: 'reply-2',
            sender: 'owner',
            name: 'Owner / Landlord',
            message: 'Thanks for informing, Ravi. I have contacted electrician Vinod. He will visit tomorrow (21st June) by 11:00 AM.',
            createdAt: '2026-06-20T14:30:00Z'
          }
        ]
      },
      {
        id: 'comment-2',
        tenantId: 'tenant-2',
        tenantName: 'Priya Sharma',
        roomNumber: '102',
        title: 'Water tap leaking in toilet',
        category: 'Plumbing',
        status: 'Open',
        createdAt: '2026-06-22T08:15:00Z',
        unreadByOwner: true,
        unreadByTenant: false,
        replies: [
          {
            id: 'reply-3',
            sender: 'tenant',
            name: 'Priya Sharma',
            message: 'The main toilet flush tap is leaking water continuously. Please fix this soon to avoid water wastage.',
            createdAt: '2026-06-22T08:15:00Z'
          }
        ]
      }
    ];

    for (const c of seedComments) {
      await db.insert(comments).values(c).onConflictDoNothing();
    }

    // 7. Create Chats
    console.log('Inserting chats...');
    const seedChats = [
      {
        id: 'chat-1',
        tenantId: 'tenant-1',
        tenantName: 'Ravi Kumar',
        tenantPhoto: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
        unreadCount: 1,
        lastUpdated: '2026-06-22T18:45:00Z',
        messages: [
          { id: 'msg-1', sender: 'owner', text: 'Hello Ravi, please pay the outstanding rent balance of ₹250.', timestamp: '2026-06-22T10:00:00Z', seen: true },
          { id: 'msg-2', sender: 'tenant', text: 'Hi sir, I will clear it along with next month rent if that is ok?', timestamp: '2026-06-22T18:30:00Z', seen: true },
          { id: 'msg-3', sender: 'tenant', text: 'Or I can pay by cash this Friday.', timestamp: '2026-06-22T18:45:00Z', seen: false }
        ]
      },
      {
        id: 'chat-2',
        tenantId: 'tenant-2',
        tenantName: 'Priya Sharma',
        tenantPhoto: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
        unreadCount: 0,
        lastUpdated: '2026-06-21T09:12:00Z',
        messages: [
          { id: 'msg-4', sender: 'tenant', text: 'Here is the payment screenshot for this month.', timestamp: '2026-06-21T09:05:00Z', seen: true, attachment: 'receipt_june.png', attachmentType: 'image' },
          { id: 'msg-5', sender: 'owner', text: 'Received, thank you Priya!', timestamp: '2026-06-21T09:12:00Z', seen: true }
        ]
      }
    ];

    for (const ch of seedChats) {
      await db.insert(chats).values(ch).onConflictDoNothing();
    }

    console.log('✅ Database seeded successfully!');
  } catch (error) {
    console.error('❌ Seeding failed:', error.message);
  }
}

module.exports = { seed };

if (require.main === module) {
  seed().then(() => process.exit(0));
}
