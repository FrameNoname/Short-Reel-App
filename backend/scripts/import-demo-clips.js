#!/usr/bin/env node
// Copies the team's own MP4 clips into uploads/ and points the seed episodes at them.
//
//   node scripts/import-demo-clips.js <folder-with-mp4s> [--dry-run]
//
// Use only clips the team has the right to use. With 10-20 clips every seed
// film gets different material; with fewer, clips are reused round-robin.
// Several episodes may share one file; the server only deletes a file when no
// episode still points at it. Only the seed films (ids 1-5) are touched, so
// films uploaded through the app keep their own videos.
require('dotenv').config({ quiet: true });
const fs = require('node:fs');
const path = require('node:path');
const mysql = require('mysql2/promise');
const { looksLikeMp4, mp4DurationSec } = require('../src/services/media');

const SEED_FILM_IDS = [1, 2, 3, 4, 5];

async function main() {
  const [folder, ...flags] = process.argv.slice(2);
  const dryRun = flags.includes('--dry-run');
  if (!folder || !fs.existsSync(folder)) {
    console.error('Usage: node scripts/import-demo-clips.js <folder-with-mp4s> [--dry-run]');
    process.exit(1);
  }
  const files = fs
    .readdirSync(folder)
    .filter((name) => name.toLowerCase().endsWith('.mp4'))
    .sort()
    .map((name) => path.join(folder, name));
  const clips = [];
  for (const file of files) {
    if (await looksLikeMp4(file)) clips.push(file);
    else console.warn(`skipped (not an MP4): ${file}`);
  }
  if (clips.length === 0) {
    console.error('No MP4 clips found.');
    process.exit(1);
  }
  if (clips.length < 10 || clips.length > 20) {
    console.warn(`Found ${clips.length} clips; the project plan asks for 10-20. Reusing them round-robin.`);
  }

  const db = await mysql.createConnection({
    host: process.env.DB_HOST ?? '127.0.0.1',
    port: Number(process.env.DB_PORT ?? 3306),
    user: process.env.DB_USER ?? 'root',
    password: process.env.DB_PASSWORD ?? '',
    database: process.env.DB_NAME ?? 'shortreel',
  });
  try {
    const [episodes] = await db.query(
      'SELECT id, film_id, episode_no FROM episodes WHERE film_id IN (?) ORDER BY film_id, episode_no',
      [SEED_FILM_IDS],
    );
    const uploads = path.join(__dirname, '..', 'uploads');
    fs.mkdirSync(uploads, { recursive: true });
    const copied = new Map();
    for (const [index, episode] of episodes.entries()) {
      const source = clips[index % clips.length];
      const name = `demo_${path.basename(source).replace(/[^A-Za-z0-9._-]/g, '_')}`;
      if (!copied.has(source)) {
        if (!dryRun) fs.copyFileSync(source, path.join(uploads, name));
        copied.set(source, { name, seconds: await mp4DurationSec(source) });
      }
      const { name: stored, seconds } = copied.get(source);
      console.log(`film ${episode.film_id} ep ${episode.episode_no} -> uploads/${stored} (${seconds}s)`);
      if (!dryRun) {
        // Some encoders write no length into the file; then the seed value stays.
        await db.query(
          'UPDATE episodes SET video_path = ?, duration_sec = IF(? > 0, ?, duration_sec) WHERE id = ?',
          [`uploads/${stored}`, seconds, seconds, episode.id],
        );
      }
    }
    console.log(dryRun ? 'Dry run: nothing changed.' : `Done: ${copied.size} clip(s) for ${episodes.length} episodes.`);
  } finally {
    await db.end();
  }
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
