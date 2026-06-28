const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const uuidv4 = () => crypto.randomUUID();

const os = require('os');

// Use OS temp directory in serverless environments like Vercel where the app directory is read-only
const UPLOAD_DIR = process.env.VERCEL
  ? path.join(os.tmpdir(), 'private_uploads')
  : path.join(__dirname, '../../private_uploads');

if (!fs.existsSync(UPLOAD_DIR)) {
  try {
    fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  } catch (err) {
    console.warn('⚠️ Could not create upload directory:', err.message);
  }
}

// Set up secure disk storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, UPLOAD_DIR);
  },
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    // Rename using a secure random UUID to prevent original file leak
    const secureName = `${uuidv4()}${ext}`;
    cb(null, secureName);
  }
});

// Enforce strict file extension and MIME type whitelist
const fileFilter = (req, file, cb) => {
  const allowedMimeTypes = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'application/pdf'];
  const allowedExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.pdf'];
  const ext = path.extname(file.originalname).toLowerCase();

  if (allowedMimeTypes.includes(file.mimetype) && allowedExtensions.includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error('Invalid file type. Only JPG, JPEG, PNG, WEBP and PDF are allowed.'), false);
  }
};

const upload = multer({
  storage: storage,
  fileFilter: fileFilter,
  limits: {
    fileSize: 10 * 1024 * 1024 // 10MB max limit (PDF ceiling)
  }
});

// Custom size checker middleware (Images max 5MB, PDF max 10MB)
const validateFileSize = (req, res, next) => {
  if (!req.file) return next();
  
  const ext = path.extname(req.file.filename).toLowerCase();
  const size = req.file.size;
  
  const isImage = ['.jpg', '.jpeg', '.png', '.webp'].includes(ext);
  const imageLimit = 5 * 1024 * 1024; // 5MB
  const pdfLimit = 10 * 1024 * 1024; // 10MB
  
  if (isImage && size > imageLimit) {
    try {
      fs.unlinkSync(req.file.path); // remove invalid file from private directory
    } catch (e) {}
    return res.status(400).json({ message: 'Image file size exceeds the 5 MB limit.' });
  }
  
  if (ext === '.pdf' && size > pdfLimit) {
    try {
      fs.unlinkSync(req.file.path); // remove invalid file
    } catch (e) {}
    return res.status(400).json({ message: 'PDF file size exceeds the 10 MB limit.' });
  }
  
  next();
};

module.exports = {
  upload,
  validateFileSize,
  UPLOAD_DIR
};
