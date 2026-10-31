// Who may play which episode. Every playback decision goes through here.

async function hasActiveSubscription(db, userId) {
  const [rows] = await db.query(
    'SELECT 1 FROM subscriptions WHERE user_id = ? AND CURDATE() BETWEEN start_date AND end_date LIMIT 1',
    [userId],
  );
  return rows.length > 0;
}

async function unlockedIds(db, userId) {
  const [rows] = await db.query('SELECT episode_id FROM unlocked_episodes WHERE user_id = ?', [
    userId,
  ]);
  return new Set(rows.map((r) => r.episode_id));
}

async function viewerContext(db, user) {
  if (!user) return { user: null, subscribed: false, unlocked: new Set() };
  const [subscribed, unlocked] = await Promise.all([
    hasActiveSubscription(db, user.id),
    unlockedIds(db, user.id),
  ]);
  return { user, subscribed, unlocked };
}

// 'owner' | 'free' | 'unlocked' | 'subscription' | 'locked' | 'login_required'
function accessOf(ctx, film, episode) {
  const { user } = ctx;
  if (user && (user.role === 'admin' || user.id === film.creator_id)) return 'owner';
  if (episode.is_free) return 'free';
  if (!user) return 'login_required';
  if (ctx.unlocked.has(episode.id)) return 'unlocked';
  if (ctx.subscribed) return 'subscription';
  return 'locked';
}

const canPlay = (access) => access !== 'locked' && access !== 'login_required';

// A film that is not approved exists only for its owner and the admin.
const canSeeFilm = (film, user) =>
  film.status === 'approved' ||
  Boolean(user && (user.role === 'admin' || user.id === film.creator_id));

module.exports = { viewerContext, accessOf, canPlay, canSeeFilm, hasActiveSubscription };
