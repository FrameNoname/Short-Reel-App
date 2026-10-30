const { Router } = require('express');
const { requireAuth } = require('../middleware/auth');
const auth = require('../controllers/auth');

const router = Router();

router.post('/register', auth.register);
router.post('/login', auth.login);
router.post('/logout', requireAuth, auth.logout);
router.get('/me', requireAuth, auth.me);

module.exports = router;
