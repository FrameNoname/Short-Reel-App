const { Router } = require('express');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const requireRole = require('../middleware/requireRole');
const films = require('../controllers/films');

const router = Router();
const creatorOnly = [requireAuth, requireRole('creator', 'admin')];

router.get('/', optionalAuth, films.list);
router.get('/:id', optionalAuth, films.getOne);
router.post('/', creatorOnly, films.create);
router.put('/:id', creatorOnly, films.update);
router.delete('/:id', creatorOnly, films.remove);
// Add upload.single('video') here with the real handler, so the stub keeps no files.
router.post('/:id/episodes', creatorOnly, films.addEpisode);

module.exports = router;
