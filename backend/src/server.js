require('dotenv').config({ quiet: true });
const { createApp } = require('./app');
const { createPool } = require('./config/db');
const { loadEnv } = require('./config/env');
const { listen } = require('./listen');

async function main() {
  const env = loadEnv();
  const pool = createPool(env.db);
  const app = createApp({ pool, jwtSecret: env.jwtSecret });
  await listen(app, env.port);
  console.log(`ShortReel API listening on port ${env.port}`);
}

main().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
