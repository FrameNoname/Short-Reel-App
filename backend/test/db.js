// Integration-test harness. Every test file builds its own throw-away database
// from db/shortreel.sql, named shortreel_<name>_test. It refuses to touch any
// database whose name does not end in "_test", so real data can never be dropped.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const jwt = require('jsonwebtoken');
const mysql = require('mysql2/promise');
const request = require('supertest');
const { createApp } = require('../src/app');
const { createPool } = require('../src/config/db');

const SECRET = 'test-secret';
const SCHEMA = fs.readFileSync(path.join(__dirname, '..', 'db', 'shortreel.sql'), 'utf8');

const conn = {
  host: process.env.TEST_DB_HOST ?? '127.0.0.1',
  port: Number(process.env.TEST_DB_PORT ?? 3306),
  user: process.env.TEST_DB_USER ?? 'root',
  password: process.env.TEST_DB_PASSWORD ?? '',
};

// Passwords of the seed accounts (see the header of shortreel.sql).
const SEED_PASSWORDS = {
  admin: '1111',
  kestrel_studio: '2222',
  'noor.frames': '3333',
  'mira.lens': '4444',
  tidewater_ai: '5555',
  viewer01: '6666',
};

// A tiny but structurally valid MP4: ftyp + moov(mvhd, 5 s) + mdat.
function makeMp4(payloadBytes = 2048, seconds = 5) {
  const box = (type, ...parts) => {
    const body = Buffer.concat(parts);
    const head = Buffer.alloc(8);
    head.writeUInt32BE(body.length + 8, 0);
    head.write(type, 4, 'latin1');
    return Buffer.concat([head, body]);
  };
  const mvhd = Buffer.alloc(100);
  mvhd.writeUInt32BE(1000, 12);
  mvhd.writeUInt32BE(seconds * 1000, 16);
  return Buffer.concat([
    box('ftyp', Buffer.from('isom\0\0\2\0isomiso2', 'latin1')),
    box('moov', box('mvhd', mvhd)),
    box('mdat', Buffer.alloc(payloadBytes, 7)),
  ]);
}

async function createTestEnv(name, options = {}) {
  const dbName = `shortreel_${name}_test`;
  if (!/^[a-z0-9_]+_test$/.test(dbName)) throw new Error(`refusing to use database ${dbName}`);
  const admin = await mysql.createConnection({ ...conn, multipleStatements: true });
  try {
    await admin.query(SCHEMA.replaceAll('`shortreel`', `\`${dbName}\``));
  } finally {
    await admin.end();
  }
  const pool = createPool({ ...conn, database: dbName });
  const uploadDir = fs.mkdtempSync(path.join(os.tmpdir(), 'shortreel-test-'));
  const app = createApp({ pool, jwtSecret: SECRET, uploadDir, ...options });
  const tokens = {};

  const api = {
    app,
    pool,
    uploadDir,
    dbName,
    req: (method, url, token) => {
      const r = request(app)[method](url);
      return token ? r.set('Authorization', `Bearer ${token}`) : r;
    },
    async login(username) {
      if (!tokens[username]) {
        const res = await request(app)
          .post('/api/auth/login')
          .send({ username, password: SEED_PASSWORDS[username] });
        if (res.status !== 200) throw new Error(`login ${username}: ${res.status}`);
        tokens[username] = res.body.token;
      }
      return tokens[username];
    },
    // A signed-in user that is not one of the seed accounts.
    async register(username, role = 'viewer') {
      const res = await request(app).post('/api/auth/register').send({ username, password: 'secret123', role });
      if (res.status !== 201) throw new Error(`register ${username}: ${res.status}`);
      return { token: res.body.token, user: res.body.user };
    },
    tokenFor: (id, role) => jwt.sign({ sub: String(id), role }, SECRET, { expiresIn: '1h' }),
    async close() {
      await pool.query(`DROP DATABASE IF EXISTS \`${dbName}\``);
      await pool.end();
      fs.rmSync(uploadDir, { recursive: true, force: true });
    },
    // Creates a pending film with one uploaded episode and returns ids.
    async uploadFilm(token, { title = 'Test Film', price_coins = 0, episodes = 1 } = {}) {
      const created = await request(app)
        .post('/api/films')
        .set('Authorization', `Bearer ${token}`)
        .send({ title, genre: 'Drama', ai_tool: 'Mixed', prompt_credit: 'p', is_ai_generated: true });
      if (created.status !== 201) throw new Error(`create film: ${created.status}`);
      const filmId = created.body.film.id;
      const episodeIds = [];
      for (let n = 1; n <= episodes; n += 1) {
        const ep = await request(app)
          .post(`/api/films/${filmId}/episodes`)
          .set('Authorization', `Bearer ${token}`)
          .field('price_coins', String(n === 1 ? 0 : price_coins))
          .attach('video', makeMp4(), { filename: 'clip.mp4', contentType: 'video/mp4' });
        if (ep.status !== 201) throw new Error(`add episode: ${ep.status} ${JSON.stringify(ep.body)}`);
        episodeIds.push(ep.body.episode.id);
      }
      return { filmId, episodeIds };
    },
    async approve(filmId) {
      const admin = await api.login('admin');
      const res = await request(app)
        .post(`/api/admin/films/${filmId}/review`)
        .set('Authorization', `Bearer ${admin}`)
        .send({ status: 'approved' });
      if (res.status !== 200) throw new Error(`approve: ${res.status}`);
    },
  };
  return api;
}

module.exports = { createTestEnv, makeMp4, SECRET };
