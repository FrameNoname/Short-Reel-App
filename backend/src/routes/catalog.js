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
router.post('/dramas/:dramaId/episodes/:episodeNo/unlock', requireAuth, catalog.unlock);
router.get('/dramas/:dramaId/comments', optionalAuth, catalog.listComments);
router.post('/dramas/:dramaId/comments', requireAuth, catalog.addComment);
router.post('/dramas/:dramaId/like', requireAuth, catalog.like);
router.delete('/dramas/:dramaId/like', requireAuth, catalog.unlike);
router.post('/dramas/:dramaId/watchlist', requireAuth, catalog.save);
router.delete('/dramas/:dramaId/watchlist', requireAuth, catalog.unsave);
router.get('/stats', optionalAuth, catalog.stats);
router.get('/access', optionalAuth, catalog.access);

module.exports = router;
