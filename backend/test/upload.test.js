const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const express = require('express');
const request = require('supertest');
const { createUpload } = require('../src/middleware/upload');
const errorHandler = require('../src/middleware/errorHandler');
const { makeApp } = require('./helpers');

function setup() {
  const dest = fs.mkdtempSync(path.join(os.tmpdir(), 'shortreel-upload-'));
  const app = express();
  app.post('/upload', createUpload({ dest, maxBytes: 10 }).single('video'), (req, res) => {
    res.json({ filename: req.file.filename });
  });
  app.use(errorHandler);
  return { app, dest };
}

const send = (app, bytes, filename, contentType) =>
  request(app).post('/upload').attach('video', Buffer.alloc(bytes), { filename, contentType });

test('accepts mp4 with a random name', async () => {
  const { app, dest } = setup();
  const res = await send(app, 5, '../evil.mp4', 'video/mp4');
  assert.equal(res.status, 200);
  assert.match(res.body.filename, /\.mp4$/);
  assert.ok(!res.body.filename.includes('evil'));
  assert.deepEqual(fs.readdirSync(dest), [res.body.filename]);
});

test('rejects other file types', async () => {
  const { app, dest } = setup();
  const res = await send(app, 5, 'note.txt', 'text/plain');
  assert.equal(res.status, 400);
  assert.equal(res.body.error.code, 'VALIDATION_ERROR');
  assert.deepEqual(fs.readdirSync(dest), []);
});

test('rejects oversized files', async () => {
  const { app, dest } = setup();
  const res = await send(app, 11, 'big.mp4', 'video/mp4');
  assert.equal(res.status, 413);
  assert.equal(res.body.error.code, 'FILE_TOO_LARGE');
  assert.deepEqual(fs.readdirSync(dest), []);
});

test('uploads are not served', async () => {
  const res = await request(makeApp()).get('/uploads/film1_ep1.mp4');
  assert.equal(res.status, 404);
  assert.equal(res.body.error.code, 'NOT_FOUND');
});
