const { Router } = require('express');
const { requireAuth } = require('../middleware/auth');
const wallet = require('../controllers/wallet');

const router = Router();

router.get('/', requireAuth, wallet.getWallet);
router.get('/transactions', requireAuth, wallet.listTransactions);
router.get('/unlocked', requireAuth, wallet.listUnlocked);
router.post('/topup', requireAuth, wallet.topup);

const coinPacksRouter = Router();
coinPacksRouter.get('/', wallet.listCoinPacks);

module.exports = { walletRouter: router, coinPacksRouter };
