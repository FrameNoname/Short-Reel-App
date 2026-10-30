const jwt = require('jsonwebtoken');
const ApiError = require('../utils/ApiError');

function readUser(req) {
  const match = /^Bearer (.+)$/.exec(req.headers.authorization ?? '');
  if (!match) throw new ApiError(401, 'UNAUTHENTICATED', 'Login is required');
  try {
    const payload = jwt.verify(match[1], req.app.locals.jwtSecret, { algorithms: ['HS256'] });
    return { id: Number(payload.sub), role: payload.role };
  } catch {
    throw new ApiError(401, 'UNAUTHENTICATED', 'Token is invalid or expired');
  }
}

function requireAuth(req, res, next) {
  req.user = readUser(req);
  next();
}

// Guests pass through, but a token that was sent must still be valid.
function optionalAuth(req, res, next) {
  if (req.headers.authorization !== undefined) req.user = readUser(req);
  next();
}

module.exports = { requireAuth, optionalAuth };
