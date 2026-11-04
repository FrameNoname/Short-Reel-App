const { Router } = require('express');
const { requireAuth } = require('../middleware/auth');
const requireRole = require('../middleware/requireRole');
const admin = require('../controllers/admin');

const router = Router();

router.use(requireAuth, requireRole('admin'));
router.get('/reviews', admin.listReviews);
router.get('/films', admin.listFilms);
router.post('/films/:id/review', admin.reviewFilm);
router.get('/sales', admin.sales);
router.get('/settings/revenue-share', admin.getRevenueShare);
router.put('/settings/revenue-share', admin.setRevenueShare);
router.get('/users', admin.listUsers);
router.put('/users/:id/role', admin.setUserRole);

module.exports = router;
