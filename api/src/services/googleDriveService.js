const { google } = require('googleapis');
const path = require('path');
const stream = require('stream');
const fs = require('fs');

const KEY_FILE_PATH = path.join(__dirname, '../../google-credentials.json');

let isConfigured = false;
let drive = null;
let folderId = '';

if (fs.existsSync(KEY_FILE_PATH)) {
  try {
    let rawFolderId = process.env.GOOGLE_DRIVE_FOLDER_ID || '';
    if (rawFolderId.includes('folders/')) {
      folderId = rawFolderId.split('folders/')[1].split('?')[0].replace(/"/g, '').replace(/'/g, '');
    } else {
      folderId = rawFolderId.replace(/"/g, '').replace(/'/g, '');
    }

    if (folderId) {
      const auth = new google.auth.GoogleAuth({
        keyFile: KEY_FILE_PATH,
        scopes: ['https://www.googleapis.com/auth/drive'],
      });
      drive = google.drive({ version: 'v3', auth });
      isConfigured = true;
      console.log('✅ Google Drive API Service initialized. Folder ID:', folderId);
    } else {
      console.warn('⚠️ Google Drive Service: GOOGLE_DRIVE_FOLDER_ID not set in .env');
    }
  } catch (error) {
    console.error('❌ Failed to initialize Google Drive client:', error.message);
  }
} else {
  console.warn('⚠️ google-credentials.json not found in api root. Google Drive uploads will fall back to local disk storage.');
}

async function uploadToGoogleDrive(file) {
  if (!isConfigured) {
    throw new Error('Google Drive integration is not fully configured.');
  }

  const bufferStream = new stream.PassThrough();
  bufferStream.end(file.buffer);

  const response = await drive.files.create({
    requestBody: {
      name: `${Date.now()}-${file.originalname}`,
      parents: [folderId],
    },
    media: {
      mimeType: file.mimetype,
      body: bufferStream,
    },
    fields: 'id, name, webViewLink, webContentLink',
  });

  // Make the file readable by anyone with the link so the tenant/landlord can view it
  try {
    await drive.permissions.create({
      fileId: response.data.id,
      requestBody: {
        role: 'reader',
        type: 'anyone',
      },
    });
  } catch (err) {
    console.warn('⚠️ Could not set Google Drive file permissions:', err.message);
  }

  return response.data;
}

module.exports = {
  isConfigured,
  uploadToGoogleDrive,
};
