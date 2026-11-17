// Runs the real API for the Flutter widget tests (mobile/test/app_test.dart).
//
//   node scripts/widget-test-server.js
//
// It uses its own database, shortreel_widget_test by default, built from
// db/shortreel.sql, and never the development database `shortreel`. The app's
// routes, controllers and SQL all run for real. Only the outside Series Jeen
// provider is replaced by a small stub, so a test run never spends its quota.
//
// POST /__test/reset rebuilds the database from the seed, so every widget test
// starts from the same accounts, films and balances.
require('dotenv').config({ quiet: true, path: require('node:path').join(__dirname, '..', '.env') });
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const mysql = require('mysql2/promise');
const { createApp } = require('../src/app');
const { createPool } = require('../src/config/db');
const { listen } = require('../src/listen');
const freereels = require('../src/services/freereels');

const DB_NAME = process.env.WIDGET_TEST_DB_NAME || 'shortreel_widget_test';
const PORT = Number(process.env.WIDGET_TEST_PORT || 3100);

if (!DB_NAME.endsWith('_test')) {
  console.error(`Refusing to use database "${DB_NAME}": its name must end in _test.`);
  process.exit(1);
}

const server = {
  host: process.env.DB_HOST ?? '127.0.0.1',
  port: Number(process.env.DB_PORT ?? 3306),
  user: process.env.DB_USER ?? 'root',
  password: process.env.DB_PASSWORD ?? '',
};

// The seed creates `shortreel`; point it at the test database instead.
const seed = fs
  .readFileSync(path.join(__dirname, '..', 'db', 'shortreel.sql'), 'utf8')
  .replace(/`shortreel`/g, `\`${DB_NAME}\``);

async function resetDatabase() {
  const conn = await mysql.createConnection({ ...server, multipleStatements: true });
  try {
    await conn.query(seed);
  } finally {
    await conn.end();
  }
}

// Two Series Jeen series, in the shapes the provider answers with.
const stubSeries = [
  { series_id: 'stubMoon01', title: 'Moon Bride', cover: null, episode_count: 10, genre: 'Romance', description: 'A bride from the moon.' },
  { series_id: 'stubStorm2', title: 'Storm Heir', cover: null, episode_count: 10, genre: 'Drama', description: 'Heir to a storm.' },
];

function stubPage(items) {
  return { page: 1, page_size: 20, total: items.length, items };
}

const stubCatalog = {
  async get(requestPath, query = {}) {
    if (requestPath === freereels.paths.access) {
      return { platforms: [{ platform_id: 19, name: 'FreeReels' }] };
    }
    if (requestPath === freereels.paths.thai) return stubPage(stubSeries);
    if (requestPath === freereels.paths.search) {
      const word = String(query.keyword ?? '').toLowerCase();
      return stubPage(stubSeries.filter((s) => s.title.toLowerCase().includes(word)));
    }
    const series = stubSeries.find((s) => requestPath.includes(`/drama/${s.series_id}`));
    if (series && requestPath.includes('/play/')) {
      const ep = Number(requestPath.split('/play/')[1]);
      return { data: { data: { episode_number: ep, m3u8_url: `http://127.0.0.1:${PORT}/stub/${ep}.m3u8`, subtitle_list: [] } }, success: true };
    }
    if (series) {
      return {
        data: {
          data: {
            info: {
              id: series.series_id,
              name: series.title,
              desc: series.description,
              cover: series.cover,
              episode_count: series.episode_count,
              content_tags: [series.genre],
              episode: { subtitle_list: [] },
            },
          },
        },
        success: true,
      };
    }
    throw new Error(`The Series Jeen stub has no answer for ${requestPath}`);
  },
};

async function main() {
  await resetDatabase();
  const pool = createPool({ ...server, database: DB_NAME });
  const app = createApp({
    pool,
    jwtSecret: crypto.randomBytes(32).toString('hex'),
    jwtExpiresIn: '1h',
    catalog: stubCatalog,
  });

  const outer = express();
  outer.post('/__test/reset', async (req, res) => {
    try {
      await resetDatabase();
      res.json({ status: 'reset', database: DB_NAME });
    } catch (err) {
      res.status(500).json({ error: err.message });
    }
  });
  outer.use(app);

  await listen(outer, PORT, '127.0.0.1');
  console.log(`Widget test API on http://127.0.0.1:${PORT}/api (database ${DB_NAME})`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
