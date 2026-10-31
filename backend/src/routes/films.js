const { Router } = require('express');
const { requireAuth, optionalAuth } = require('../middleware/auth');
const requireRole = require('../middleware/requireRole');
const films = require('../controllers/films');
const { uploadVideo } = require('../middleware/upload');

const router = Router();
const creatorOnly = [requireAuth, requireRole('creator', 'admin')];

router.get('/', optionalAuth, films.list);
router.get('/:id', optionalAuth, films.getOne);
router.post('/', creatorOnly, films.create);
router.put('/:id', creatorOnly, films.loadOwnedFilm, films.update);
router.delete('/:id', creatorOnly, films.loadOwnedFilm, films.remove);
// Ownership is checked before multer, so a stranger's upload is never written to disk.
router.post('/:id/episodes', creatorOnly, films.loadOwnedFilm, uploadVideo, films.addEpisode);

module.exports = router;
