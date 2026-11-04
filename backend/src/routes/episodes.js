const { Router } = require('express');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const episodes = require('../controllers/episodes');

const router = Router();

router.get('/:id', optionalAuth, episodes.getOne);
router.get('/:id/stream', optionalAuth, episodes.stream);
router.post('/:id/unlock', requireAuth, episodes.unlock);

module.exports = router;
