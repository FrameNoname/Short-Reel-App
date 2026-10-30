const { createApp } = require('../src/app');

const TEST_SECRET = 'test-secret';

const okPool = { query: async () => [[{ 1: 1 }]] };
const failingPool = {
  query: async () => {
    throw new Error('connection refused');
  },
};

function makeApp(pool = okPool) {
  return createApp({ pool, jwtSecret: TEST_SECRET });
}

module.exports = { TEST_SECRET, okPool, failingPool, makeApp };
