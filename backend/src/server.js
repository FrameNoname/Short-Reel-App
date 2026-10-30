require('dotenv').config({ quiet: true });
const { createApp } = require('./app');
const { createPool } = require('./config/db');
const { loadEnv } = require('./config/env');

const env = loadEnv();
const pool = createPool(env.db);
const app = createApp({ pool, jwtSecret: env.jwtSecret });

app.listen(env.port, () => {
  console.log(`ShortReel API listening on port ${env.port}`);
});
