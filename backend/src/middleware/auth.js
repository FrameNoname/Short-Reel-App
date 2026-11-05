const jwt = require('jsonwebtoken');
const ApiError = require('../utils/ApiError');

function readToken(req) {
  const match = /^Bearer (.+)$/.exec(req.headers.authorization ?? '');
  if (!match) throw new ApiError(401, 'UNAUTHENTICATED', 'Login is required');
  try {
    const payload = jwt.verify(match[1], req.app.locals.jwtSecret, { algorithms: ['HS256'] });
    // Login tokens have a numeric subject and no "typ"; playback links carry a
    // "typ" and must never pass as a login.
    if (payload.typ !== undefined || !/^\d+$/.test(String(payload.sub))) throw new Error('not a login token');
    return { id: Number(payload.sub), role: payload.role };
  } catch {
    throw new ApiError(401, 'UNAUTHENTICATED', 'Token is invalid or expired');
  }
}

// The role is read from the database on every request, so a demoted or deleted
// account loses access at once instead of when its token expires.
async function readUser(req) {
  const claimed = readToken(req);
  const [rows] = await req.app.locals.pool.query('SELECT id, role FROM users WHERE id = ?', [
    claimed.id,
  ]);
  if (rows.length === 0) throw new ApiError(401, 'UNAUTHENTICATED', 'Token is invalid or expired');
  return { id: rows[0].id, role: rows[0].role };
}

async function requireAuth(req, res, next) {
  try {
    req.user = await readUser(req);
    next();
  } catch (err) {
    next(err);
  }
}

// Guests pass through, but a token that was sent must still be valid.
async function optionalAuth(req, res, next) {
  try {
    if (req.headers.authorization !== undefined) req.user = await readUser(req);
    next();
  } catch (err) {
    next(err);
  }
}

module.exports = { requireAuth, optionalAuth };
