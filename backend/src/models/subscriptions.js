const { withTransaction } = require('../utils/transaction');
const { setting } = require('./wallet');

exports.price = async (db) => Number(await setting(db, 'subscription_price_usd', 6.99));

// The latest plan that covers today, else the most recent one.
exports.current = async (pool, userId) => {
  const [rows] = await pool.query(
    `SELECT id, price_usd, start_date, end_date, cancelled_at,
            (CURDATE() BETWEEN start_date AND end_date) AS active
       FROM subscriptions WHERE user_id = ?
      ORDER BY active DESC, end_date DESC, id DESC LIMIT 1`,
    [userId],
  );
  const row = rows[0];
  if (!row) return { active: false, subscription: null };
  return {
    active: Boolean(row.active),
    subscription: {
      id: row.id,
      price_usd: Number(row.price_usd),
      start_date: row.start_date,
      end_date: row.end_date,
      is_cancelled: row.cancelled_at !== null,
    },
  };
};

// Simulated purchase. Subscribing while a plan is active adds one month after it.
exports.subscribe = (pool, userId) =>
  withTransaction(pool, async (conn) => {
    await conn.query('SELECT id FROM users WHERE id = ? FOR UPDATE', [userId]);
    const price = await exports.price(conn);
    await conn.query(
      `INSERT INTO subscriptions (user_id, price_usd, start_date, end_date)
       SELECT ?, ?, s.start_date, DATE_ADD(s.start_date, INTERVAL 1 MONTH) FROM (
         SELECT COALESCE(
           (SELECT DATE_ADD(MAX(end_date), INTERVAL 1 DAY) FROM subscriptions
             WHERE user_id = ? AND CURDATE() BETWEEN start_date AND end_date),
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
