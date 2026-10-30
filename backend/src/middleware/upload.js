const crypto = require('node:crypto');
const path = require('node:path');
const multer = require('multer');
const ApiError = require('../utils/ApiError');

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');
const MAX_BYTES = 200 * 1024 * 1024;

function createUpload({ dest, maxBytes = MAX_BYTES }) {
  return multer({
    storage: multer.diskStorage({
      destination: dest,
      filename: (req, file, cb) => cb(null, `${crypto.randomUUID()}.mp4`),
    }),
    limits: { fileSize: maxBytes },
    fileFilter: (req, file, cb) => {
      if (file.mimetype === 'video/mp4') return cb(null, true);
      cb(new ApiError(400, 'VALIDATION_ERROR', 'Only video/mp4 files are allowed'));
    },
  });
}

module.exports = { createUpload, upload: createUpload({ dest: UPLOAD_DIR }) };
