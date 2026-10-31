const ApiError = require('../utils/ApiError');
const { withTransaction } = require('../utils/transaction');
const { hasActiveSubscription } = require('./access');

async function setting(db, name, fallback) {
  const [rows] = await db.query('SELECT value FROM settings WHERE name = ?', [name]);
  return rows[0]?.value ?? fallback;
}

exports.setting = setting;

exports.adminSharePercent = async (db) => {
  const percent = Number(await setting(db, 'admin_share_percent', 30));
  return Number.isInteger(percent) && percent >= 0 && percent <= 100 ? percent : 30;
};

exports.listCoinPacks = async (pool) => {
  const [rows] = await pool.query('SELECT id, name, coins, price_usd FROM coin_packs ORDER BY coins');
  return rows.map((r) => ({ ...r, price_usd: Number(r.price_usd) }));
};

exports.getBalance = async (pool, userId) => {
  const [rows] = await pool.query('SELECT coin_balance FROM users WHERE id = ?', [userId]);
  return rows[0].coin_balance;
};

exports.listTransactions = async (pool, userId, { limit, offset }) => {
  const [rows] = await pool.query(
    `SELECT t.id, t.type, t.amount, t.balance_after, t.price_usd, t.coin_pack_id, t.episode_id,
            t.created_at, p.name AS pack_name, e.episode_no, f.id AS film_id, f.title AS film_title
       FROM coin_transactions t
       LEFT JOIN coin_packs p ON p.id = t.coin_pack_id
       LEFT JOIN episodes e ON e.id = t.episode_id
       LEFT JOIN films f ON f.id = e.film_id
      WHERE t.user_id = ?
      ORDER BY t.id DESC LIMIT ? OFFSET ?`,
    [userId, limit, offset],
  );
  return rows.map((r) => ({
    ...r,
    price_usd: r.price_usd === null ? null : Number(r.price_usd),
  }));
};

// Simulated purchase: the client names a pack (or the demo button) and the
// server alone decides how many coins that is worth.
exports.topUp = (pool, userId, { packId }) =>
  withTransaction(pool, async (conn) => {
    let coins;
    let priceUsd;
    if (packId === undefined) {
      coins = Number(await setting(conn, 'demo_topup_coins', 100));
      priceUsd = 0;
    } else {
      const [packs] = await conn.query('SELECT coins, price_usd FROM coin_packs WHERE id = ?', [
        packId,
      ]);
      if (packs.length === 0) throw new ApiError(404, 'NOT_FOUND', 'Coin pack not found');
      coins = packs[0].coins;
      priceUsd = Number(packs[0].price_usd);
    }
    const [[user]] = await conn.query('SELECT coin_balance FROM users WHERE id = ? FOR UPDATE', [
      userId,
    ]);
    const balance = user.coin_balance + coins;
    await conn.query('UPDATE users SET coin_balance = ? WHERE id = ?', [balance, userId]);
    const [result] = await conn.query(
      `INSERT INTO coin_transactions (user_id, type, amount, balance_after, price_usd, coin_pack_id)
       VALUES (?, 'topup', ?, ?, ?, ?)`,
      [userId, coins, balance, priceUsd, packId ?? null],
    );
    return { transaction_id: result.insertId, coins_added: coins, price_usd: priceUsd, balance };
  });

// Everything that makes an unlock real happens in one DB transaction: the user
// row is locked, the price is read, coins leave, the unlock row and the ledger
// row are written. A repeat or concurrent request finds the unlock row and
// returns without charging; UNIQUE(user_id, episode_id) is the final guard.
exports.unlock = (pool, user, episodeId) =>
  withTransaction(pool, async (conn) => {
    const [[locked]] = await conn.query(
      'SELECT coin_balance FROM users WHERE id = ? FOR UPDATE',
      [user.id],
    );
    const [episodes] = await conn.query(
      `SELECT e.id, e.is_free, e.price_coins, f.creator_id, f.status, u.role AS owner_role
         FROM episodes e JOIN films f ON f.id = e.film_id JOIN users u ON u.id = f.creator_id
        WHERE e.id = ?`,
      [episodeId],
    );
    const episode = episodes[0];
    const isOwner = episode && (user.role === 'admin' || user.id === episode.creator_id);
    if (!episode || (episode.status !== 'approved' && !isOwner)) {
      throw new ApiError(404, 'NOT_FOUND', 'Episode not found');
    }
    const result = (access, charged = 0) => ({
      access,
      charged,
      already_unlocked: access === 'unlocked' && charged === 0,
      balance: locked.coin_balance,
    });
    if (isOwner) return result('owner');
    if (episode.is_free) return result('free');

    const [existing] = await conn.query(
      'SELECT id FROM unlocked_episodes WHERE user_id = ? AND episode_id = ? FOR UPDATE',
      [user.id, episodeId],
    );
    if (existing.length > 0) return result('unlocked');
    if (await hasActiveSubscription(conn, user.id)) return result('subscription');

    const price = episode.price_coins;
    const [debit] = await conn.query(
      'UPDATE users SET coin_balance = coin_balance - ? WHERE id = ? AND coin_balance >= ?',
      [price, user.id, price],
    );
    if (debit.affectedRows === 0) {
      throw new ApiError(402, 'INSUFFICIENT_COINS', 'Not enough coins to unlock this episode');
    }
    const balance = locked.coin_balance - price;

    // Shares are fixed now, so a later change of the percentage cannot touch them.
    const percent = await exports.adminSharePercent(conn);
    const creatorShare = episode.owner_role === 'admin' ? 0 : Math.floor((price * (100 - percent)) / 100);
    const adminShare = price - creatorShare;
    await conn.query(
      `INSERT INTO unlocked_episodes (user_id, episode_id, coins_spent, creator_share, admin_share)
       VALUES (?, ?, ?, ?, ?)`,
      [user.id, episodeId, price, creatorShare, adminShare],
    );
    await conn.query(
      `INSERT INTO coin_transactions (user_id, type, amount, balance_after, episode_id)
       VALUES (?, 'unlock', ?, ?, ?)`,
      [user.id, -price, balance, episodeId],
    );
    return { access: 'unlocked', charged: price, already_unlocked: false, balance };
  });
