// Who may play which episode. Every playback decision goes through here.

async function unlockedIds(db, userId) {
  const [rows] = await db.query('SELECT episode_id FROM unlocked_episodes WHERE user_id = ?', [
    userId,
  ]);
  return new Set(rows.map((r) => r.episode_id));
}

async function viewerContext(db, user) {
  if (!user) return { user: null, unlocked: new Set() };
  return { user, unlocked: await unlockedIds(db, user.id) };
}

const isAdmin = (user) => Boolean(user && user.role === 'admin');

// 'owner' | 'free' | 'unlocked' | 'locked' | 'login_required'
// The admin runs the catalogue, so every episode is open to them.
function accessOf(ctx, episode) {
  const { user } = ctx;
  if (isAdmin(user)) return 'owner';
  if (episode.is_free) return 'free';
  if (!user) return 'login_required';
  if (ctx.unlocked.has(episode.id)) return 'unlocked';
  return 'locked';
}

const canPlay = (access) => access !== 'locked' && access !== 'login_required';

// A film that is not approved exists only for the admin.
const canSeeFilm = (film, user) => film.status === 'approved' || isAdmin(user);

module.exports = { viewerContext, accessOf, canPlay, canSeeFilm, isAdmin };
