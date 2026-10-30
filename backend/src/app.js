const express = require('express');
const ApiError = require('./utils/ApiError');
const errorHandler = require('./middleware/errorHandler');

function createApp({ pool, jwtSecret }) {
  const app = express();
  app.locals.pool = pool;
  app.locals.jwtSecret = jwtSecret;

  app.use(express.json());

  app.get('/api/health', async (req, res, next) => {
    try {
      await req.app.locals.pool.query('SELECT 1');
      res.json({ status: 'ok', db: 'up' });
    } catch {
      next(new ApiError(503, 'DB_UNAVAILABLE', 'Database is unavailable'));
    }
  });

  app.use((req, res, next) => {
    next(new ApiError(404, 'NOT_FOUND', 'Route not found'));
  });
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
