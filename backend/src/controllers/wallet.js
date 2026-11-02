const wallet = require('../models/wallet');
const subscriptions = require('../models/subscriptions');
const { pathId, bool, bad } = require('../utils/validate');

const SIMULATED = 'Simulated payment: no real money is charged.';

exports.getWallet = async (req, res) => {
  const pool = req.app.locals.pool;
  res.json({
    coin_balance: await wallet.getBalance(pool, req.user.id),
    demo_topup_coins: Number(await wallet.setting(pool, 'demo_topup_coins', 100)),
    simulated_payment: true,
    notice: SIMULATED,
  });
};

exports.listTransactions = async (req, res) => {
  const limit = req.query.limit === undefined ? 50 : pathId(req.query.limit, 'limit');
  const offset = req.query.offset === undefined ? 0 : Number(pathId(req.query.offset, 'offset'));
  if (limit < 1 || limit > 200) throw bad('limit is not valid');
  const rows = await wallet.listTransactions(req.app.locals.pool, req.user.id, {
    limit: limit + 1,
    offset,
  });
  res.json({
    simulated_payment: true,
    transactions: rows.slice(0, limit),
    limit,
    offset,
    has_more: rows.length > limit,
  });
};

// Every episode the user paid for, read from the unlock rows themselves, so an
// old purchase never falls out of view behind newer ledger entries.
exports.listUnlocked = async (req, res) => {
  res.json({ unlocked: await wallet.listUnlocked(req.app.locals.pool, req.user.id) });
};

exports.topup = async (req, res) => {
  const hasPack = req.body?.pack_id !== undefined;
  const demo = bool(req.body, 'demo', { optional: true }) === true;
  if (hasPack === demo) throw bad('Send either pack_id or demo: true');
  const result = await wallet.topUp(req.app.locals.pool, req.user.id, {
    packId: hasPack ? pathId(req.body.pack_id, 'pack_id') : undefined,
  });
  res.status(201).json({ ...result, simulated_payment: true, notice: SIMULATED });
};

exports.listCoinPacks = async (req, res) => {
  const pool = req.app.locals.pool;
  res.json({
    simulated_payment: true,
    demo_topup_coins: Number(await wallet.setting(pool, 'demo_topup_coins', 100)),
    coin_packs: await wallet.listCoinPacks(pool),
    subscription_price_usd: await subscriptions.price(pool),
  });
};
