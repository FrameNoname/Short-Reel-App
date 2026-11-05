// Series Jeen series sold for coins. The early episodes are free; a later one
// is paid once and stays open. A series and its paid episodes become rows in
// films/episodes the first time someone unlocks one, so unlocking, the ledger
// and admin sales all run through the same tables as the app's own films.
const { setting } = require('./wallet');
const { isAdmin } = require('./access');

const TITLE_MAX = 100;

exports.pricing = async (db) => ({
  free_episodes: Number(await setting(db, 'catalog_free_episodes', 5)),
  price_coins: Number(await setting(db, 'catalog_price_coins', 10)),
});

// Episode numbers of one series that this user paid for.
async function unlockedNumbers(db, userId, dramaId) {
  const [rows] = await db.query(
    `SELECT e.episode_no FROM unlocked_episodes ue
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
      WHERE ue.user_id = ? AND f.catalog_drama_id = ?`,
    [userId, dramaId],
  );
  return new Set(rows.map((r) => r.episode_no));
}

// The episode numbers in [from, to] this caller may not play yet.
exports.lockedIn = async (db, user, dramaId, from, to) => {
  if (isAdmin(user)) return [];
  const { free_episodes: free } = await exports.pricing(db);
  const paid = [];
  for (let n = Math.max(from, free + 1); n <= to; n++) paid.push(n);
  if (paid.length === 0) return [];
  if (!user) return paid;
  const unlocked = await unlockedNumbers(db, user.id, dramaId);
  return paid.filter((n) => !unlocked.has(n));
};

// Every catalog episode this user paid for, as { drama_id, episode_no }.
exports.unlocksOf = async (db, userId) => {
  const [rows] = await db.query(
    `SELECT f.catalog_drama_id AS drama_id, e.episode_no
       FROM unlocked_episodes ue
       JOIN episodes e ON e.id = ue.episode_id
       JOIN films f ON f.id = e.film_id
      WHERE ue.user_id = ? AND f.catalog_drama_id IS NOT NULL
      ORDER BY f.catalog_drama_id, e.episode_no`,
    [userId],
  );
  return rows;
};

// The id of the episodes row for a paid catalog episode, creating the film and
// episode rows on first use. Both inserts are idempotent (unique keys), so two
// viewers unlocking the same new series at once end up with the same rows. The
// price follows the current setting, so a change applies to the next unlock.
exports.ensureEpisode = async (db, { dramaId, title, episodeNo, priceCoins }) => {
  await db.query(
    `INSERT INTO films (title, is_ai_generated, catalog_drama_id) VALUES (?, 0, ?)
     ON DUPLICATE KEY UPDATE title = VALUES(title)`,
    [String(title).slice(0, TITLE_MAX), dramaId],
  );
  const [[film]] = await db.query('SELECT id FROM films WHERE catalog_drama_id = ?', [dramaId]);
  await db.query(
    `INSERT INTO episodes (film_id, episode_no, title, is_free, price_coins) VALUES (?, ?, ?, 0, ?)
     ON DUPLICATE KEY UPDATE price_coins = VALUES(price_coins)`,
    [film.id, episodeNo, `Episode ${episodeNo}`, priceCoins],
  );
  const [[episode]] = await db.query(
    'SELECT id FROM episodes WHERE film_id = ? AND episode_no = ?',
    [film.id, episodeNo],
  );
  return episode.id;
};
