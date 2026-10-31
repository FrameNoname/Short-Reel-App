const argon2 = require('argon2');
const jwt = require('jsonwebtoken');
const ApiError = require('../utils/ApiError');
const { text } = require('../utils/validate');
const users = require('../models/auth');
const { hasActiveSubscription } = require('../models/access');

const USERNAME = /^[A-Za-z0-9_.]{3,30}$/;
const SELF_REGISTER_ROLES = new Set(['viewer', 'creator']);

// Verified against when the username does not exist, so a wrong username and a
// wrong password take the same time.
let dummyHash;
const getDummyHash = () => (dummyHash ??= argon2.hash('not-a-real-password'));

function publicUser(user, subscribed) {
  return {
    id: user.id,
    username: user.username,
    display_name: user.display_name,
    avatar_url: user.avatar_url,
    bio: user.bio,
    role: user.role,
    coin_balance: user.coin_balance,
    has_active_subscription: subscribed,
    created_at: user.created_at,
  };
}

function signToken(req, user) {
  return jwt.sign({ sub: String(user.id), role: user.role }, req.app.locals.jwtSecret, {
    expiresIn: req.app.locals.jwtExpiresIn ?? '7d',
    algorithm: 'HS256',
  });
}

exports.register = async (req, res) => {
  const pool = req.app.locals.pool;
  const username = text(req.body, 'username', { min: 3, max: 30 });
  if (!USERNAME.test(username)) {
    throw new ApiError(400, 'VALIDATION_ERROR', 'username may use letters, numbers, "_" and "."');
  }
  const password = text(req.body, 'password', { min: 6, max: 72 });
  const role = req.body?.role ?? 'viewer';
  // Admin accounts are never created from the outside; an admin promotes users.
  if (role === 'admin') throw new ApiError(403, 'FORBIDDEN', 'Admin accounts cannot be self-registered');
  if (!SELF_REGISTER_ROLES.has(role)) throw new ApiError(400, 'VALIDATION_ERROR', 'role is not valid');
  const displayName = text(req.body, 'display_name', { max: 50, optional: true }) ?? username;

  const passwordHash = await argon2.hash(password, { type: argon2.argon2id });
  let id;
  try {
    id = await users.create(pool, { username, passwordHash, displayName, role });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') throw new ApiError(409, 'CONFLICT', 'Username is already taken');
    throw err;
  }
  const user = await users.findById(pool, id);
  res.status(201).json({ token: signToken(req, user), user: publicUser(user, false) });
};

exports.login = async (req, res) => {
  const pool = req.app.locals.pool;
  const username = text(req.body, 'username', { max: 30 });
  const password = text(req.body, 'password', { max: 72 });
  const user = await users.findByUsername(pool, username);
  const valid = await argon2.verify(user ? user.password : await getDummyHash(), password).catch(() => false);
  if (!user || !valid) throw new ApiError(401, 'UNAUTHENTICATED', 'Username or password is wrong');
  res.json({
    token: signToken(req, user),
    user: publicUser(user, await hasActiveSubscription(pool, user.id)),
  });
};

// Tokens are stateless: the app forgets its copy. The server has nothing to revoke.
exports.logout = (req, res) => res.json({ status: 'ok' });

exports.me = async (req, res) => {
  const pool = req.app.locals.pool;
  const user = await users.findById(pool, req.user.id);
  res.json({ user: publicUser(user, await hasActiveSubscription(pool, user.id)) });
};

exports.updateMe = async (req, res) => {
  const pool = req.app.locals.pool;
  const displayName = text(req.body, 'display_name', { max: 50 });
  const bio = text(req.body, 'bio', { max: 160, optional: true }) ?? null;
  await users.updateProfile(pool, req.user.id, { displayName, bio });
  const user = await users.findById(pool, req.user.id);
  res.json({ user: publicUser(user, await hasActiveSubscription(pool, user.id)) });
};
