const { Router } = require('express');
const { requireAuth } = require('../middleware/auth');
const requireRole = require('../middleware/requireRole');
const creator = require('../controllers/creator');

const router = Router();

router.use(requireAuth, requireRole('creator', 'admin'));
router.get('/films', creator.listFilms);
router.get('/earnings', creator.earnings);

module.exports = router;
