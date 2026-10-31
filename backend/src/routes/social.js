const { Router } = require('express');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const social = require('../controllers/social');

const router = Router();

router.post('/films/:id/like', requireAuth, social.like);
router.delete('/films/:id/like', requireAuth, social.unlike);
router.get('/watchlist', requireAuth, social.listWatchlist);
router.post('/films/:id/watchlist', requireAuth, social.addToWatchlist);
router.delete('/films/:id/watchlist', requireAuth, social.removeFromWatchlist);
router.get('/films/:id/comments', optionalAuth, social.listComments);
router.post('/films/:id/comments', requireAuth, social.addComment);
router.delete('/comments/:id', requireAuth, social.removeComment);
router.post('/creators/:id/follow', requireAuth, social.follow);
router.delete('/creators/:id/follow', requireAuth, social.unfollow);
router.post('/films/:id/reports', requireAuth, social.reportFilm);

module.exports = router;
