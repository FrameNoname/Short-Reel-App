const { Router } = require('express');
const { requireAuth } = require('../middleware/auth');
const requireRole = require('../middleware/requireRole');
const admin = require('../controllers/admin');
const catalog = require('../controllers/catalog');

const router = Router();

router.use(requireAuth, requireRole('admin'));
router.get('/sales', admin.sales);

router.get('/films', admin.listFilms);
router.put('/films/:id/status', admin.setFilmStatus);
router.get('/catalog/search', catalog.adminSearch);
router.put('/catalog/:dramaId/status', catalog.adminSetStatus);
router.get('/films/:id/episodes', admin.listEpisodes);
router.put('/episodes/:id', admin.updateEpisode);

router.get('/comments', admin.listComments);
router.delete('/comments/:id', admin.removeComment);

router.get('/settings', admin.getSettings);
router.put('/settings', admin.saveSettings);

router.get('/coin-packs', admin.listCoinPacks);
router.post('/coin-packs', admin.createCoinPack);
router.put('/coin-packs/:id', admin.updateCoinPack);
router.delete('/coin-packs/:id', admin.deleteCoinPack);

module.exports = router;
