const ApiError = require('../utils/ApiError');
const { withTransaction } = require('../utils/transaction');
const films = require('./films');

// from -> allowed next statuses. Approving needs at least one episode.
const TRANSITIONS = {
  pending: ['approved', 'rejected'],
  approved: ['taken_down'],
  rejected: ['approved'],
  taken_down: ['approved'],
};
const NOTE_REQUIRED = new Set(['rejected', 'taken_down']);

exports.REVIEW_STATUSES = ['approved', 'rejected', 'taken_down'];

exports.review = (pool, filmId, { status, note, adminId }) =>
  withTransaction(pool, async (conn) => {
    const [rows] = await conn.query('SELECT id, status FROM films WHERE id = ? FOR UPDATE', [filmId]);
    if (rows.length === 0) throw new ApiError(404, 'NOT_FOUND', 'Film not found');
    const from = rows[0].status;
    if (!TRANSITIONS[from].includes(status)) {
      throw new ApiError(409, 'CONFLICT', `A ${from} film cannot become ${status}`);
    }
    if (NOTE_REQUIRED.has(status) && !note) {
      throw new ApiError(400, 'VALIDATION_ERROR', 'note is required to reject or take down a film');
    }
    if (status === 'approved') {
      const [[count]] = await conn.query('SELECT COUNT(*) AS n FROM episodes WHERE film_id = ?', [filmId]);
      if (count.n === 0) {
        throw new ApiError(409, 'CONFLICT', 'A film needs at least one episode before it can go live');
      }
    }
    await films.setReview(conn, filmId, { status, note: status === 'approved' ? null : note, adminId });
    if (status === 'taken_down') {
      await conn.query("UPDATE reports SET status = 'resolved' WHERE film_id = ? AND status = 'open'", [
        filmId,
      ]);
    }
  });

exports.sales = async (pool) => {
  const [[coins]] = await pool.query(
    `SELECT COUNT(*) AS unlock_count, COALESCE(SUM(coins_spent), 0) AS coins_spent,
            COALESCE(SUM(creator_share), 0) AS creator_share, COALESCE(SUM(admin_share), 0) AS admin_share
       FROM unlocked_episodes`,
  );
  const [[topups]] = await pool.query(
    `SELECT COUNT(*) AS count, COALESCE(SUM(price_usd), 0) AS simulated_usd, COALESCE(SUM(amount), 0) AS coins_issued
       FROM coin_transactions WHERE type = 'topup'`,
  );
  const [[subs]] = await pool.query(
    'SELECT COUNT(*) AS count, COALESCE(SUM(price_usd), 0) AS simulated_usd FROM subscriptions',
  );
  const [perFilm] = await pool.query(
    `SELECT f.id AS film_id, f.title, u.username AS owner, u.role AS owner_role, COUNT(ue.id) AS unlock_count,
            COALESCE(SUM(ue.coins_spent), 0) AS coins_spent,
            COALESCE(SUM(ue.creator_share), 0) AS creator_share,
            COALESCE(SUM(ue.admin_share), 0) AS admin_share
       FROM unlocked_episodes ue
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
       JOIN users u ON u.id = f.creator_id
      GROUP BY f.id, f.title, u.username, u.role ORDER BY coins_spent DESC, f.id`,
  );
  const [recent] = await pool.query(
    `SELECT ue.id, ue.created_at, ue.coins_spent, ue.creator_share, ue.admin_share,
            buyer.username AS buyer, f.id AS film_id, f.title AS film_title, e.episode_no
       FROM unlocked_episodes ue
       JOIN users buyer ON buyer.id = ue.user_id
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
      ORDER BY ue.id DESC LIMIT 20`,
  );
  const num = (row) => Object.fromEntries(Object.entries(row).map(([k, v]) => [k, Number(v)]));
  return {
    // Coins and simulated dollars are different units and are never summed.
    coins: { unit: 'coins', ...num(coins) },
    simulated_payments: {
      unit: 'usd (simulated, no real money)',
      coin_topups: num(topups),
      subscriptions: num(subs),
    },
    per_film: perFilm.map(num_owner),
    recent_unlocks: recent,
  };
};

function num_owner(row) {
  return {
    ...row,
    unlock_count: Number(row.unlock_count),
    coins_spent: Number(row.coins_spent),
    creator_share: Number(row.creator_share),
    admin_share: Number(row.admin_share),
  };
}

exports.setSharePercent = (pool, percent) =>
  pool.query(
    `INSERT INTO settings (name, value) VALUES ('admin_share_percent', ?)
     ON DUPLICATE KEY UPDATE value = VALUES(value)`,
    [String(percent)],
  );

exports.listUsers = async (pool) => {
  const [rows] = await pool.query(
    'SELECT id, username, display_name, role, coin_balance, created_at FROM users ORDER BY id',
  );
  return rows;
};

exports.setRole = (pool, id, role) => pool.query('UPDATE users SET role = ? WHERE id = ?', [role, id]);

exports.listReports = async (pool) => {
  const [rows] = await pool.query(
    `SELECT r.id, r.film_id, f.title AS film_title, r.reason, r.status, r.created_at,
            u.username AS reporter
       FROM reports r JOIN films f ON f.id = r.film_id JOIN users u ON u.id = r.reporter_id
      ORDER BY (r.status = 'open') DESC, r.id DESC`,
  );
  return rows;
};

exports.resolveReport = async (pool, id) => {
  const [result] = await pool.query("UPDATE reports SET status = 'resolved' WHERE id = ?", [id]);
  return result.affectedRows;
};
