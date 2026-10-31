const { Router } = require('express');
const { requireAuth } = require('../middleware/auth');
const subscriptions = require('../controllers/subscriptions');

const router = Router();

router.get('/', requireAuth, subscriptions.getCurrent);
router.post('/', requireAuth, subscriptions.subscribe);
router.delete('/', requireAuth, subscriptions.cancel);

module.exports = router;
