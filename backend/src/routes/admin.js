const { Router } = require('express');
const { requireAuth } = require('../middleware/auth');
const requireRole = require('../middleware/requireRole');
const admin = require('../controllers/admin');

const router = Router();

router.use(requireAuth, requireRole('admin'));
router.get('/sales', admin.sales);

module.exports = router;
