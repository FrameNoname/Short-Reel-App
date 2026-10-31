const subscriptions = require('../models/subscriptions');
const ApiError = require('../utils/ApiError');

const SIMULATED = 'Simulated payment: no real money is charged.';

async function state(pool, userId) {
  return {
    ...(await subscriptions.current(pool, userId)),
    price_usd: await subscriptions.price(pool),
    simulated_payment: true,
  };
}

exports.getCurrent = async (req, res) => {
  res.json(await state(req.app.locals.pool, req.user.id));
};

exports.subscribe = async (req, res) => {
  const pool = req.app.locals.pool;
  await subscriptions.subscribe(pool, req.user.id);
  res.status(201).json({ ...(await state(pool, req.user.id)), notice: SIMULATED });
};

exports.cancel = async (req, res) => {
  const pool = req.app.locals.pool;
  if ((await subscriptions.cancel(pool, req.user.id)) === 0) {
    throw new ApiError(404, 'NOT_FOUND', 'There is no running subscription to cancel');
  }
  res.json(await state(pool, req.user.id));
};
