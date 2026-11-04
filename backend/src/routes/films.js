const { Router } = require('express');
const { optionalAuth } = require('../middleware/auth');
const films = require('../controllers/films');

const router = Router();

router.get('/', optionalAuth, films.list);
router.get('/:id', optionalAuth, films.getOne);

module.exports = router;
