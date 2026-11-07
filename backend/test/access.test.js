const test = require('node:test');
const assert = require('node:assert/strict');
const { accessOf, canPlay, canSeeFilm, isAdmin, viewerContext } = require('../src/models/access');
const { fakePool } = require('./helpers/fakes');

const viewer = { id: 2, role: 'viewer' };
const admin = { id: 1, role: 'admin' };
const paid = { id: 10, is_free: 0 };
const free = { id: 11, is_free: 1 };

test('the admin can play every episode', () => {
  assert.equal(accessOf({ user: admin, unlocked: new Set() }, paid), 'owner');
  assert.equal(isAdmin(admin), true);
  assert.equal(isAdmin(viewer), false);
  assert.equal(isAdmin(null), false);
});

test('a free episode is open to everyone, guests included', () => {
  assert.equal(accessOf({ user: null, unlocked: new Set() }, free), 'free');
  assert.equal(accessOf({ user: viewer, unlocked: new Set() }, free), 'free');
});

test('a paid episode asks guests to log in and viewers to unlock', () => {
  assert.equal(accessOf({ user: null, unlocked: new Set() }, paid), 'login_required');
  assert.equal(accessOf({ user: viewer, unlocked: new Set() }, paid), 'locked');
  assert.equal(accessOf({ user: viewer, unlocked: new Set([10]) }, paid), 'unlocked');
});

test('canPlay is false only for locked and login_required', () => {
  assert.equal(canPlay('owner'), true);
  assert.equal(canPlay('free'), true);
  assert.equal(canPlay('unlocked'), true);
  assert.equal(canPlay('locked'), false);
  assert.equal(canPlay('login_required'), false);
});

test('a taken-down film is visible to the admin only', () => {
  const live = { status: 'approved' };
  const down = { status: 'taken_down' };
  assert.equal(canSeeFilm(live, null), true);
  assert.equal(canSeeFilm(down, null), false);
  assert.equal(canSeeFilm(down, viewer), false);
  assert.equal(canSeeFilm(down, admin), true);
});

test('viewerContext loads the unlocked episode ids of a signed-in user', async () => {
  const pool = fakePool([['FROM unlocked_episodes', [{ episode_id: 3 }, { episode_id: 9 }]]]);
  const ctx = await viewerContext(pool, viewer);
  assert.deepEqual([...ctx.unlocked], [3, 9]);
  const guest = await viewerContext(pool, null);
  assert.equal(guest.user, null);
  assert.equal(pool.calls.length, 1, 'a guest needs no query');
});
