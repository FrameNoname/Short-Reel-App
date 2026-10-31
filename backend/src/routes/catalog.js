const { Router } = require('express');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const catalog = require('../controllers/catalog');

const router = Router();

router.get('/platforms', catalog.platforms);
router.get('/platforms/:platformId/dramas', catalog.dramas);
router.get('/dramas/:dramaId', catalog.drama);
// Local trials can run before real login exists: CATALOG_ALLOW_GUEST=true.
const viewerOnly = (req, res, next) =>
  (req.app.locals.catalogAllowGuest ? optionalAuth : requireAuth)(req, res, next);

router.get('/dramas/:dramaId/episodes', viewerOnly, catalog.episodes);

module.exports = router;
