const cors = require('cors');
const express = require('express');
const ApiError = require('./utils/ApiError');
const errorHandler = require('./middleware/errorHandler');
const authRoutes = require('./routes/auth');
const filmRoutes = require('./routes/films');
const episodeRoutes = require('./routes/episodes');
const { walletRouter, coinPacksRouter } = require('./routes/wallet');
const subscriptionRoutes = require('./routes/subscriptions');
const creatorRoutes = require('./routes/creator');
const adminRoutes = require('./routes/admin');
const socialRoutes = require('./routes/social');
const catalogRoutes = require('./routes/catalog');

// The Flutter web dev server runs on localhost; the mobile app does not need CORS.
const LOCAL_WEB_ORIGIN = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

function createApp({ pool, jwtSecret, catalog, catalogAllowGuest = false }) {
  const app = express();
  app.locals.pool = pool;
  app.locals.jwtSecret = jwtSecret;
  app.locals.catalog = catalog;
  app.locals.catalogAllowGuest = catalogAllowGuest;

  app.use(cors({ origin: LOCAL_WEB_ORIGIN }));
  app.use(express.json());

  app.get('/api/health', async (req, res, next) => {
    try {
      await req.app.locals.pool.query('SELECT 1');
      res.json({ status: 'ok', db: 'up' });
    } catch {
      next(new ApiError(503, 'DB_UNAVAILABLE', 'Database is unavailable'));
    }
  });

  app.use('/api/auth', authRoutes);
  app.use('/api/catalog', catalogRoutes);
  app.use('/api/films', filmRoutes);
  app.use('/api/episodes', episodeRoutes);
  app.use('/api/wallet', walletRouter);
  app.use('/api/coin-packs', coinPacksRouter);
  app.use('/api/subscription', subscriptionRoutes);
  app.use('/api/creator', creatorRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api', socialRoutes);

  app.use((req, res, next) => {
    next(new ApiError(404, 'NOT_FOUND', 'Route not found'));
  });
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
