const { Router } = require('express');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const requireRole = require('../middleware/requireRole');
const episodes = require('../controllers/episodes');

const router = Router();
const creatorOnly = [requireAuth, requireRole('creator', 'admin')];

router.get('/:id', optionalAuth, episodes.getOne);
router.put('/:id', creatorOnly, episodes.update);
router.delete('/:id', creatorOnly, episodes.remove);
router.get('/:id/stream', optionalAuth, episodes.stream);
router.post('/:id/unlock', requireAuth, episodes.unlock);

module.exports = router;
