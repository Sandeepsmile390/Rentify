const { z } = require('zod');

const loginSchema = z.object({
  email: z.string().email('Invalid email format').optional(),
  phone: z.string().regex(/^[6-9]\d{9}$/, 'Invalid phone number format').optional(),
  password: z.string().min(6, 'Password must be at least 6 characters long'),
  role: z.enum(['owner', 'tenant'])
});

const tenantSchema = z.object({
  name: z.string().min(2, 'Name must be at least 2 characters').max(100),
  fatherName: z.string().min(2, 'Father name must be at least 2 characters').max(100),
  phone: z.string().regex(/^[6-9]\d{9}$/, 'Invalid phone format'),
  altPhone: z.string().regex(/^[6-9]\d{9}$/, 'Invalid alt phone format').optional().nullable(),
  email: z.string().email('Invalid email').optional().nullable(),
  occupation: z.string().min(2, 'Occupation is required').max(100),
  
  // Validation for Indian Aadhaar and PAN numbers
  aadhaar: z.string().regex(/(^\d{12}$)|(^\d{4} \d{4} \d{4}$)/, 'Aadhaar must be 12 digits or formatted as "0000 0000 0000"'),
  pan: z.string().regex(/^[A-Z]{5}[0-9]{4}[A-Z]{1}$/, 'PAN must be 10 characters alphanumeric (e.g. ABCDE1234F)'),
  
  permanentAddress: z.string().min(5, 'Permanent address must be at least 5 characters'),
  currentAddress: z.string().optional().nullable(),
  propertyId: z.string().min(1, 'Property reference is required'),
  roomNumber: z.string().min(1, 'Room number is required'),
  roomType: z.enum(['Room', 'Shop', 'Flat']),
  moveInDate: z.string().min(1, 'Move in date is required'),
  agreementDuration: z.coerce.number().int().min(1, 'Agreement duration must be positive'),
  rentAmount: z.coerce.number().min(0, 'Rent amount cannot be negative'),
  securityDeposit: z.coerce.number().min(0, 'Security deposit cannot be negative'),
  electricityRate: z.coerce.number().min(0, 'Electricity unit rate cannot be negative'),
  waterCharges: z.coerce.number().min(0, 'Water charges cannot be negative'),
  photo: z.string().optional(),
  emergencyContact: z.string().optional().nullable(),
  gender: z.string().optional().nullable(),
  dob: z.string().optional().nullable(),
  companyCollege: z.string().optional().nullable(),
  drivingLicense: z.string().optional().nullable(),
  vehicleDetails: z.string().optional().nullable(),
  notes: z.string().optional().nullable(),
  roomId: z.string().optional().nullable()
});

const propertySchema = z.object({
  name: z.string().min(2, 'Property name is too short').max(256),
  type: z.enum(['Residential', 'Commercial']),
  totalRooms: z.number().int().min(1, 'Total units must be at least 1'),
  address: z.string().optional().nullable(),
  description: z.string().optional().nullable(),
  floors: z.number().int().min(1).optional()
});

const billSchema = z.object({
  rentAmount: z.number().min(0).optional(),
  electricityUnits: z.number().min(0).optional(),
  electricityRate: z.number().min(0).optional(),
  waterCharges: z.number().min(0).optional(),
  lateFee: z.number().min(0).optional(),
  discount: z.number().min(0).optional(),
  extraCharges: z.number().min(0).optional(),
  extraChargesReason: z.string().optional(),
  prevMeterReading: z.number().int().min(0).optional(),
  currMeterReading: z.number().int().min(0).optional(),
  meterPhoto: z.string().optional().nullable()
});

const commentSchema = z.object({
  title: z.string().min(2, 'Title must be at least 2 characters').max(256),
  category: z.string().optional(),
  message: z.string().min(1, 'Message description cannot be empty').max(1024)
});

const chatSchema = z.object({
  text: z.string().min(1, 'Chat text cannot be empty').optional(),
  attachment: z.string().optional(),
  attachmentType: z.enum(['image', 'document']).optional()
});

const paymentSchema = z.object({
  billId: z.string().min(1, 'Bill reference is required'),
  amount: z.number().positive('Payment amount must be greater than zero'),
  method: z.enum(['UPI', 'Cash', 'Card', 'Bank Transfer']),
  note: z.string().optional()
});

module.exports = {
  loginSchema,
  tenantSchema,
  propertySchema,
  billSchema,
  commentSchema,
  chatSchema,
  paymentSchema
};
