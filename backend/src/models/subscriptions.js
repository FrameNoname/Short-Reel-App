const { withTransaction } = require('../utils/transaction');
const { setting } = require('./wallet');

exports.price = async (db) => Number(await setting(db, 'subscription_price_usd', 6.99));

// Dates are inclusive on both ends: a plan bought on day D covers D through
// D + 1 month - 1 day, and the next purchase starts the day after end_date.
// `subscription` is the plan covering today (else the most recent one);
// `paid_through` is the last paid day across every plan, prepaid ones included.
exports.current = async (pool, userId) => {
  const [rows] = await pool.query(
    `SELECT id, price_usd, start_date, end_date, cancelled_at,
            (CURDATE() BETWEEN start_date AND end_date) AS active
       FROM subscriptions WHERE user_id = ?
      ORDER BY active DESC, end_date DESC, id DESC LIMIT 1`,
    [userId],
  );
  const [[meta]] = await pool.query(
    `SELECT CURDATE() AS today,
            (SELECT MAX(end_date) FROM subscriptions WHERE user_id = ? AND end_date >= CURDATE()) AS paid_through,
            (SELECT COUNT(*) FROM subscriptions WHERE user_id = ? AND end_date >= CURDATE()) AS plans_remaining`,
    [userId, userId],
  );
  const row = rows[0];
  const common = {
    today: meta.today,
    paid_through: meta.paid_through,
    plans_remaining: Number(meta.plans_remaining),
  };
  if (!row) return { active: false, subscription: null, ...common };
  return {
    active: Boolean(row.active),
    subscription: {
      id: row.id,
      price_usd: Number(row.price_usd),
      start_date: row.start_date,
      end_date: row.end_date,
      is_cancelled: row.cancelled_at !== null,
    },
    ...common,
  };
};

// Simulated purchase. A new plan starts the day after the last paid day (today
// when nothing is paid ahead), so any number of renewals never overlap.
exports.subscribe = (pool, userId) =>
  withTransaction(pool, async (conn) => {
    await conn.query('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId]);
    const price = await exports.price(conn);
    await conn.query(
      `INSERT INTO subscriptions (user_id, price_usd, start_date, end_date)
       SELECT ?, ?, s.start_date, DATE_SUB(DATE_ADD(s.start_date, INTERVAL 1 MONTH), INTERVAL 1 DAY) FROM (
         SELECT COALESCE(
           (SELECT DATE_ADD(MAX(end_date), INTERVAL 1 DAY) FROM subscriptions
             WHERE user_id = ? AND end_date >= CURDATE()),
           CURDATE()) AS start_date
       ) s`,
      [userId, price, userId],
    );
  });

// The plan keeps working until end_date; only renewal stops.
exports.cancel = async (pool, userId) => {
  const [result] = await pool.query(
    `UPDATE subscriptions SET cancelled_at = NOW()
      WHERE user_id = ? AND end_date >= CURDATE() AND cancelled_at IS NULL`,
    [userId],
  );
  return result.affectedRows;
};
