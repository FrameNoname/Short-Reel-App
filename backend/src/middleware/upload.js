const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const multer = require('multer');
const ApiError = require('../utils/ApiError');

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');
const MAX_BYTES = 200 * 1024 * 1024;

function createUpload({ dest, maxBytes = MAX_BYTES }) {
  fs.mkdirSync(dest, { recursive: true });
  return multer({
    storage: multer.diskStorage({
      destination: dest,
      filename: (req, file, cb) => cb(null, `${crypto.randomUUID()}.mp4`),
    }),
    limits: { fileSize: maxBytes, files: 1 },
    fileFilter: (req, file, cb) => {
      if (file.mimetype === 'video/mp4') return cb(null, true);
      cb(new ApiError(400, 'VALIDATION_ERROR', 'Only video/mp4 files are allowed'));
    },
  });
}

// One multer per upload folder, so tests can point the app at a temp directory.
const cache = new Map();

function uploadVideo(req, res, next) {
  const dir = req.app.locals.uploadDir ?? UPLOAD_DIR;
  const maxBytes = req.app.locals.maxUploadBytes ?? MAX_BYTES;
  const key = `${dir}|${maxBytes}`;
  if (!cache.has(key)) cache.set(key, createUpload({ dest: dir, maxBytes }));
  cache.get(key).single('video')(req, res, next);
}

module.exports = { createUpload, uploadVideo, UPLOAD_DIR };
