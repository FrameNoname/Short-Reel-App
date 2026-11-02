#!/usr/bin/env node
// Builds ShortReel-Sprint1-2.postman_collection.json (Postman Collection v2.1).
//
//   node docs/postman/build-collection.js
//
// The collection is generated so every request, its expected status and the
// checks on the response live in one readable place. Test scripts only use a
// small part of the Postman API (pm.test, pm.response.code / json(),
// pm.expect(...).to.eql / .above / .include, pm.environment.get / set), so the
// file is meant to run in docs/postman/run-collection.js (verified), Postman and
// Newman (NOT yet verified: file paths given as {{variables}} may need to be
// re-selected by hand in those tools, see docs/postman/README.md).
const fs = require('node:fs');
const path = require('node:path');

const folders = [];
let current;
const folder = (name, description) => {
  current = { name, description, item: [] };
  folders.push(current);
};

/** One request. `tests` is the body of the Postman test script. */
function request(name, method, url, { auth, json, formdata, expect, tests = '' } = {}) {
  const header = [];
  if (auth) header.push({ key: 'Authorization', value: `Bearer {{${auth}}}` });
  const body = json
    ? { mode: 'raw', raw: JSON.stringify(json, null, 2), options: { raw: { language: 'json' } } }
    : formdata
      ? { mode: 'formdata', formdata }
      : undefined;
  if (json) header.push({ key: 'Content-Type', value: 'application/json' });
  const script = [`pm.test("${name}: status is ${expect}", function () { pm.expect(pm.response.code).to.eql(${expect}); });`, tests]
    .filter(Boolean)
    .join('\n');
  current.item.push({
    name,
    event: [{ listen: 'test', script: { type: 'text/javascript', exec: script.split('\n') } }],
    request: {
      method: method.toUpperCase(),
      header,
      body,
      url: { raw: `{{base_url}}${url}`, host: ['{{base_url}}'], path: url.replace(/^\//, '').split('/') },
    },
  });
}

const file = (key, src, type = 'file') => ({ key, type, src });
const text = (key, value) => ({ key, value, type: 'text' });

// ---------------------------------------------------------------------------
folder('1 Guest and public', 'No token: what a guest can and cannot see.');
request('Health check', 'GET', '/health', {
  expect: 200,
  tests: `
var body = pm.response.json();
pm.test("API and database are up", function () { pm.expect(body.status).to.eql("ok"); pm.expect(body.db).to.eql("up"); });
pm.environment.set("run_id", Date.now().toString(36));`,
});
request('Guest: feed lists approved films only', 'GET', '/films?page_size=100', {
  expect: 200,
  tests: `
var films = pm.response.json().films;
pm.test("feed has films", function () { pm.expect(films.length).to.above(0); });
pm.test("every film is approved", function () { pm.expect(films.filter(function (f) { return f.status !== "approved"; }).length).to.eql(0); });
pm.environment.set("seed_film_id", String(films[0].id));`,
});
request('Guest: film detail shows episodes with access labels', 'GET', '/films/{{seed_film_id}}', {
  expect: 200,
  tests: `
var eps = pm.response.json().episodes;
var free = eps.filter(function (e) { return e.is_free; })[0];
var paid = eps.filter(function (e) { return !e.is_free; })[0];
pm.test("a free and a paid episode exist", function () { pm.expect(!!free && !!paid).to.eql(true); });
pm.test("free episode is labelled free, paid one login_required", function () { pm.expect(free.access).to.eql("free"); pm.expect(paid.access).to.eql("login_required"); });
pm.environment.set("free_episode_id", String(free.id));
pm.environment.set("paid_episode_id", String(paid.id));`,
});
request('Guest: free episode gives a playback link', 'GET', '/episodes/{{free_episode_id}}', {
  expect: 200,
  tests: `
var body = pm.response.json();
pm.test("stream_url is a short-lived link", function () { pm.expect(typeof body.stream_url).to.eql("string"); pm.expect(body.stream_url).to.include("/stream?t="); });
pm.environment.set("free_stream_url", body.stream_url);`,
});
request('Guest: paid episode has no playback link', 'GET', '/episodes/{{paid_episode_id}}', {
  expect: 200,
  tests: `
var body = pm.response.json();
pm.test("stream_url is null and access is login_required", function () { pm.expect(body.stream_url).to.eql(null); pm.expect(body.episode.access).to.eql("login_required"); });`,
});
request('Guest: paid episode stream is denied', 'GET', '/episodes/{{paid_episode_id}}/stream', {
  expect: 401,
  tests: `pm.test("error code", function () { pm.expect(pm.response.json().error.code).to.eql("UNAUTHENTICATED"); });`,
});
request('Guest: unlock needs a login', 'POST', '/episodes/{{paid_episode_id}}/unlock', { expect: 401 });
request('Public: lookups', 'GET', '/lookups', {
  expect: 200,
  tests: `pm.test("genres and tools", function () { var b = pm.response.json(); pm.expect(b.genres.length).to.above(0); pm.expect(b.ai_tools.length).to.above(0); });`,
});
request('Public: coin packs are labelled simulated', 'GET', '/coin-packs', {
  expect: 200,
  tests: `pm.test("simulated", function () { var b = pm.response.json(); pm.expect(b.simulated_payment).to.eql(true); pm.expect(b.coin_packs.length).to.above(0); });`,
});

// ---------------------------------------------------------------------------
folder('2 Auth and roles', 'Register, login, tokens and role checks.');
request('Register viewer: valid', 'POST', '/auth/register', {
  json: { username: 'viewer_{{run_id}}', password: 'Sprint12pw', role: 'viewer' },
  expect: 201,
  tests: `
var b = pm.response.json();
pm.test("token and viewer role, no password in the answer", function () { pm.expect(typeof b.token).to.eql("string"); pm.expect(b.user.role).to.eql("viewer"); pm.expect(b.user.password).to.eql(undefined); pm.expect(b.user.coin_balance).to.eql(0); });
pm.environment.set("token_viewer", b.token); pm.environment.set("viewer_id", String(b.user.id));`,
});
request('Register viewer: duplicate username', 'POST', '/auth/register', {
  json: { username: 'viewer_{{run_id}}', password: 'Sprint12pw' },
  expect: 409,
});
request('Register: password too short', 'POST', '/auth/register', {
  json: { username: 'short_{{run_id}}', password: 'a1' },
  expect: 400,
});
request('Register: password without a number', 'POST', '/auth/register', {
  json: { username: 'nonum_{{run_id}}', password: 'onlyletters' },
  expect: 400,
});
request('Register: missing username', 'POST', '/auth/register', { json: { password: 'Sprint12pw' }, expect: 400 });
request('Register: admin role is refused', 'POST', '/auth/register', {
  json: { username: 'sneaky_{{run_id}}', password: 'Sprint12pw', role: 'admin' },
  expect: 403,
});
request('Register creator: valid', 'POST', '/auth/register', {
  json: { username: 'creator_{{run_id}}', password: 'Sprint12pw', role: 'creator' },
  expect: 201,
  tests: `var b = pm.response.json(); pm.environment.set("token_creator", b.token); pm.environment.set("creator_id", String(b.user.id)); pm.test("creator role", function () { pm.expect(b.user.role).to.eql("creator"); });`,
});
request('Register second creator (for ownership checks)', 'POST', '/auth/register', {
  json: { username: 'other_{{run_id}}', password: 'Sprint12pw', role: 'creator' },
  expect: 201,
  tests: `pm.environment.set("token_other_creator", pm.response.json().token);`,
});
request('Login: valid', 'POST', '/auth/login', {
  json: { username: 'viewer_{{run_id}}', password: 'Sprint12pw' },
  expect: 200,
  tests: `pm.test("token returned", function () { pm.expect(typeof pm.response.json().token).to.eql("string"); });`,
});
request('Login: wrong password', 'POST', '/auth/login', {
  json: { username: 'viewer_{{run_id}}', password: 'wrong-password' },
  expect: 401,
});
request('Login: unknown user gives the same message', 'POST', '/auth/login', {
  json: { username: 'nobody_{{run_id}}', password: 'whatever1' },
  expect: 401,
  tests: `pm.test("same message as a wrong password", function () { pm.expect(pm.response.json().error.message).to.eql("Username or password is wrong"); });`,
});
request('Login admin (seed account)', 'POST', '/auth/login', {
  json: { username: '{{admin_username}}', password: '{{admin_password}}' },
  expect: 200,
  tests: `var b = pm.response.json(); pm.environment.set("token_admin", b.token); pm.environment.set("admin_id", String(b.user.id)); pm.test("admin role", function () { pm.expect(b.user.role).to.eql("admin"); });`,
});
request('Token missing', 'GET', '/auth/me', { expect: 401 });
request('Token expired or invalid', 'GET', '/auth/me', { auth: 'token_expired', expect: 401 });
request('Me: valid token', 'GET', '/auth/me', {
  auth: 'token_viewer',
  expect: 200,
  tests: `pm.test("own account", function () { pm.expect(pm.response.json().user.id).to.eql(Number(pm.environment.get("viewer_id"))); });`,
});
request('Role: viewer cannot create a film', 'POST', '/films', {
  auth: 'token_viewer',
  json: { title: 'x', genre: 'Drama', ai_tool: 'Mixed', prompt_credit: 'p', is_ai_generated: true },
  expect: 403,
});
request('Role: viewer cannot open the admin queue', 'GET', '/admin/reviews', { auth: 'token_viewer', expect: 403 });
request('Role: creator cannot open the admin queue', 'GET', '/admin/reviews', { auth: 'token_creator', expect: 403 });
request('Role: creator cannot change the revenue share', 'PUT', '/admin/settings/revenue-share', {
  auth: 'token_creator',
  json: { admin_share_percent: 10 },
  expect: 403,
});
request('Role: viewer has no creator earnings', 'GET', '/creator/earnings', { auth: 'token_viewer', expect: 403 });

// ---------------------------------------------------------------------------
folder('3 Upload and review', 'Creator uploads a film, admin approves it, visibility follows the status.');
request('Creator: film without the AI label is refused', 'POST', '/films', {
  auth: 'token_creator',
  json: { title: 'No label', genre: 'Drama', ai_tool: 'Mixed', prompt_credit: 'p', is_ai_generated: false },
  expect: 400,
});
request('Creator: film with an unknown genre is refused', 'POST', '/films', {
  auth: 'token_creator',
  json: { title: 'Bad genre', genre: 'Nope', ai_tool: 'Mixed', prompt_credit: 'p', is_ai_generated: true },
  expect: 400,
});
request('Creator: create film (pending)', 'POST', '/films', {
  auth: 'token_creator',
  json: { title: 'Sprint film {{run_id}}', genre: 'Drama', ai_tool: 'Mixed', prompt_credit: 'prompt credit', is_ai_generated: true },
  expect: 201,
  tests: `var f = pm.response.json().film; pm.test("starts pending", function () { pm.expect(f.status).to.eql("pending"); }); pm.environment.set("film_id", String(f.id));`,
});
request('Upload: other creator cannot add an episode to a pending film (hidden, 404)', 'POST', '/films/{{film_id}}/episodes', {
  auth: 'token_other_creator',
  formdata: [file('video', '{{sample_video_path}}'), text('price_coins', '0')],
  expect: 404,
});
request('Upload: not a video (wrong type)', 'POST', '/films/{{film_id}}/episodes', {
  auth: 'token_creator',
  formdata: [file('video', '{{text_file_path}}', 'file'), text('price_coins', '0')],
  expect: 400,
});
request('Upload: MP4 header only, no video track', 'POST', '/films/{{film_id}}/episodes', {
  auth: 'token_creator',
  formdata: [file('video', '{{header_only_path}}'), text('price_coins', '0')],
  expect: 400,
  tests: `pm.test("says why", function () { pm.expect(pm.response.json().error.message).to.include("not a playable MP4"); });`,
});
request('Upload: price above 500 is refused', 'POST', '/films/{{film_id}}/episodes', {
  auth: 'token_creator',
  formdata: [file('video', '{{sample_video_path}}'), text('price_coins', '501')],
  expect: 400,
});
request('Upload: episode 1, free (multipart)', 'POST', '/films/{{film_id}}/episodes', {
  auth: 'token_creator',
  formdata: [file('video', '{{sample_video_path}}'), text('price_coins', '0'), text('episode_no', '1')],
  expect: 201,
  tests: `var e = pm.response.json().episode; pm.test("free", function () { pm.expect(e.is_free).to.eql(true); }); pm.environment.set("new_free_episode_id", String(e.id));`,
});
request('Upload: episode 2, 30 coins (multipart)', 'POST', '/films/{{film_id}}/episodes', {
  auth: 'token_creator',
  formdata: [file('video', '{{sample_video_path}}'), text('price_coins', '30'), text('episode_no', '2')],
  expect: 201,
  tests: `var e = pm.response.json().episode; pm.test("priced", function () { pm.expect(e.price_coins).to.eql(30); }); pm.environment.set("new_paid_episode_id", String(e.id));`,
});
request('Review visibility: guest cannot see a pending film', 'GET', '/films/{{film_id}}', { expect: 404 });
request('Review visibility: pending film is not in the feed', 'GET', '/films?q=Sprint%20film%20{{run_id}}', {
  expect: 200,
  tests: `pm.test("not listed", function () { pm.expect(pm.response.json().films.length).to.eql(0); });`,
});
request('Review visibility: guest cannot stream a pending film', 'GET', '/episodes/{{new_free_episode_id}}/stream', { expect: 404 });
request('Review visibility: owner can see it', 'GET', '/films/{{film_id}}', {
  auth: 'token_creator',
  expect: 200,
  tests: `pm.test("two episodes", function () { pm.expect(pm.response.json().episodes.length).to.eql(2); });`,
});
request('Review: viewer cannot approve', 'POST', '/admin/films/{{film_id}}/review', { auth: 'token_viewer', json: { status: 'approved' }, expect: 403 });
request('Review: admin sees the film in the queue', 'GET', '/admin/reviews', {
  auth: 'token_admin',
  expect: 200,
  tests: `pm.test("queued", function () { pm.expect(pm.response.json().films.filter(function (f) { return String(f.id) === pm.environment.get("film_id"); }).length).to.eql(1); });`,
});
request('Review: rejecting needs a note', 'POST', '/admin/films/{{film_id}}/review', { auth: 'token_admin', json: { status: 'rejected' }, expect: 400 });
request('Review: a pending film cannot be taken down', 'POST', '/admin/films/{{film_id}}/review', {
  auth: 'token_admin',
  json: { status: 'taken_down', note: 'x' },
  expect: 409,
});
request('Review: admin approves', 'POST', '/admin/films/{{film_id}}/review', {
  auth: 'token_admin',
  json: { status: 'approved' },
  expect: 200,
  tests: `pm.test("approved", function () { pm.expect(pm.response.json().film.status).to.eql("approved"); });`,
});
request('Review visibility: guest now sees the film', 'GET', '/films/{{film_id}}', { expect: 200 });
request('Ownership: other creator cannot edit the film', 'PUT', '/films/{{film_id}}', {
  auth: 'token_other_creator',
  json: { title: 'Hijack', genre: 'Drama', ai_tool: 'Mixed' },
  expect: 403,
});
request('Ownership: other creator cannot delete the film', 'DELETE', '/films/{{film_id}}', { auth: 'token_other_creator', expect: 403 });

// ---------------------------------------------------------------------------
folder('4 Wallet and unlock', 'Balance, ledger, atomic unlock and repeated unlock.');
request('Guest sees the new free episode, paid one is locked for a viewer', 'GET', '/episodes/{{new_paid_episode_id}}', {
  auth: 'token_viewer',
  expect: 200,
  tests: `var b = pm.response.json(); pm.test("locked, no link", function () { pm.expect(b.episode.access).to.eql("locked"); pm.expect(b.stream_url).to.eql(null); });`,
});
request('Unlock with no coins is refused (402)', 'POST', '/episodes/{{new_paid_episode_id}}/unlock', {
  auth: 'token_viewer',
  expect: 402,
  tests: `pm.test("code", function () { pm.expect(pm.response.json().error.code).to.eql("INSUFFICIENT_COINS"); });`,
});
request('Wallet: balance is still 0 after the refusal', 'GET', '/wallet', {
  auth: 'token_viewer',
  expect: 200,
  tests: `pm.test("0 coins", function () { pm.expect(pm.response.json().coin_balance).to.eql(0); });`,
});
request('Top-up: the client cannot choose the amount', 'POST', '/wallet/topup', { auth: 'token_viewer', json: { coins: 99999 }, expect: 400 });
request('Top-up: demo +100 (simulated)', 'POST', '/wallet/topup', {
  auth: 'token_viewer',
  json: { demo: true },
  expect: 201,
  tests: `var b = pm.response.json(); pm.test("100 coins, simulated", function () { pm.expect(b.coins_added).to.eql(100); pm.expect(b.balance).to.eql(100); pm.expect(b.simulated_payment).to.eql(true); });`,
});
request('Unlock: first time charges the server price', 'POST', '/episodes/{{new_paid_episode_id}}/unlock', {
  auth: 'token_viewer',
  expect: 200,
  tests: `var b = pm.response.json(); pm.test("charged 30, balance 70", function () { pm.expect(b.charged).to.eql(30); pm.expect(b.balance).to.eql(70); pm.expect(b.already_unlocked).to.eql(false); });`,
});
request('Unlock: repeating does not charge again', 'POST', '/episodes/{{new_paid_episode_id}}/unlock', {
  auth: 'token_viewer',
  expect: 200,
  tests: `var b = pm.response.json(); pm.test("charged 0, balance still 70", function () { pm.expect(b.charged).to.eql(0); pm.expect(b.balance).to.eql(70); pm.expect(b.already_unlocked).to.eql(true); });`,
});
request('Wallet: balance read from the server', 'GET', '/wallet', {
  auth: 'token_viewer',
  expect: 200,
  tests: `pm.test("70 coins", function () { pm.expect(pm.response.json().coin_balance).to.eql(70); });`,
});
request('Wallet: ledger lists the top-up and one unlock', 'GET', '/wallet/transactions?limit=50', {
  auth: 'token_viewer',
  expect: 200,
  tests: `
var b = pm.response.json();
pm.test("two rows, newest first, with a paging flag", function () { pm.expect(b.transactions.length).to.eql(2); pm.expect(b.transactions[0].type).to.eql("unlock"); pm.expect(b.transactions[0].amount).to.eql(-30); pm.expect(b.has_more).to.eql(false); });`,
});
request('Wallet: unlocked list reads the rights themselves', 'GET', '/wallet/unlocked', {
  auth: 'token_viewer',
  expect: 200,
  tests: `pm.test("one purchase", function () { var u = pm.response.json().unlocked; pm.expect(u.length).to.eql(1); pm.expect(String(u[0].episode_id)).to.eql(pm.environment.get("new_paid_episode_id")); });`,
});
request('Unlocked episode now has a playback link', 'GET', '/episodes/{{new_paid_episode_id}}', {
  auth: 'token_viewer',
  expect: 200,
  tests: `var b = pm.response.json(); pm.test("unlocked with link", function () { pm.expect(b.episode.access).to.eql("unlocked"); pm.expect(typeof b.stream_url).to.eql("string"); });`,
});
request('Another viewer is still locked out', 'GET', '/episodes/{{new_paid_episode_id}}/stream', { auth: 'token_other_creator', expect: 403 });
request('A film with paid unlocks cannot be deleted', 'DELETE', '/films/{{film_id}}', { auth: 'token_creator', expect: 409 });
request('A paid-for episode cannot be deleted', 'DELETE', '/episodes/{{new_paid_episode_id}}', { auth: 'token_creator', expect: 409 });

// ---------------------------------------------------------------------------
folder('5 Subscription', 'Plus: active, renewal without overlapping dates, cancel keeps access.');
request('Subscription: none yet', 'GET', '/subscription', {
  auth: 'token_viewer',
  expect: 200,
  tests: `pm.test("inactive", function () { var b = pm.response.json(); pm.expect(b.active).to.eql(false); pm.expect(b.subscription).to.eql(null); });`,
});
request('Subscription: subscribe (simulated)', 'POST', '/subscription', {
  auth: 'token_viewer',
  expect: 201,
  tests: `var b = pm.response.json(); pm.test("active with inclusive dates", function () { pm.expect(b.active).to.eql(true); pm.expect(b.simulated_payment).to.eql(true); pm.expect(b.subscription.end_date > b.subscription.start_date).to.eql(true); }); pm.environment.set("sub1_end", b.subscription.end_date); pm.environment.set("sub1_start", b.subscription.start_date);`,
});
request('Subscription: renew twice, plans never overlap', 'POST', '/subscription', {
  auth: 'token_viewer',
  expect: 201,
  tests: `pm.environment.set("sub_paid_through_after_2", pm.response.json().paid_through);`,
});
request('Subscription: third purchase starts after the second ends', 'POST', '/subscription', {
  auth: 'token_viewer',
  expect: 201,
  tests: `
var b = pm.response.json();
pm.test("paid through moved further and 3 plans remain", function () { pm.expect(b.paid_through > pm.environment.get("sub_paid_through_after_2")).to.eql(true); pm.expect(b.plans_remaining).to.eql(3); });`,
});
request('Subscription: the latest plan is read back', 'GET', '/subscription', {
  auth: 'token_viewer',
  expect: 200,
  tests: `var b = pm.response.json(); pm.test("active, paid through is after the first end date", function () { pm.expect(b.active).to.eql(true); pm.expect(b.paid_through > pm.environment.get("sub1_end")).to.eql(true); });`,
});
request('Subscription: cancel keeps access until the end', 'DELETE', '/subscription', {
  auth: 'token_viewer',
  expect: 200,
  tests: `var b = pm.response.json(); pm.test("still active, flagged cancelled", function () { pm.expect(b.active).to.eql(true); pm.expect(b.subscription.is_cancelled).to.eql(true); });`,
});
request('Subscription: another user has nothing to cancel', 'DELETE', '/subscription', { auth: 'token_other_creator', expect: 404 });

// ---------------------------------------------------------------------------
folder('6 Revenue and share setting', 'Creator earnings, admin sales and the revenue-share setting.');
request('Creator earnings match the stored 70/30 split', 'GET', '/creator/earnings', {
  auth: 'token_creator',
  expect: 200,
  tests: `var b = pm.response.json(); pm.test("30 coins spent, creator earned 21, in coins", function () { pm.expect(b.unit).to.eql("coins"); pm.expect(b.coins_spent_by_viewers).to.eql(30); pm.expect(b.coins_earned).to.eql(21); pm.expect(b.unlock_count).to.eql(1); });`,
});
request('Admin sales: coins and simulated dollars stay separate', 'GET', '/admin/sales', {
  auth: 'token_admin',
  expect: 200,
  tests: `var b = pm.response.json(); pm.test("coin totals add up", function () { pm.expect(b.coins.creator_share + b.coins.admin_share).to.eql(b.coins.coins_spent); pm.expect(b.coins.unlock_count > 0).to.eql(true); pm.expect(typeof b.simulated_payments).to.eql("object"); });`,
});
request('Share setting: read', 'GET', '/admin/settings/revenue-share', {
  auth: 'token_admin',
  expect: 200,
  tests: `pm.test("a percentage", function () { var p = pm.response.json().admin_share_percent; pm.expect(p >= 0 && p <= 100).to.eql(true); });`,
});
request('Share setting: out of range is refused', 'PUT', '/admin/settings/revenue-share', { auth: 'token_admin', json: { admin_share_percent: 101 }, expect: 400 });
request('Share setting: admin changes it to 50', 'PUT', '/admin/settings/revenue-share', {
  auth: 'token_admin',
  json: { admin_share_percent: 50 },
  expect: 200,
});
request('Share setting: earnings recorded earlier do not change', 'GET', '/creator/earnings', {
  auth: 'token_creator',
  expect: 200,
  tests: `pm.test("still 21", function () { pm.expect(pm.response.json().coins_earned).to.eql(21); });`,
});
request('Share setting: put it back to 30', 'PUT', '/admin/settings/revenue-share', { auth: 'token_admin', json: { admin_share_percent: 30 }, expect: 200 });
request('Role change: admin promotes the creator', 'PUT', '/admin/users/{{creator_id}}/role', { auth: 'token_admin', json: { role: 'admin' }, expect: 200 });
request('Role change: past earnings do not change', 'GET', '/creator/earnings', {
  auth: 'token_creator',
  expect: 200,
  tests: `pm.test("still 21 after becoming admin", function () { pm.expect(pm.response.json().coins_earned).to.eql(21); });`,
});
request('Role change: demote again', 'PUT', '/admin/users/{{creator_id}}/role', { auth: 'token_admin', json: { role: 'creator' }, expect: 200 });
request('Admin cannot change their own role', 'PUT', '/admin/users/{{admin_id}}/role', { auth: 'token_admin', json: { role: 'viewer' }, expect: 409 });

// ---------------------------------------------------------------------------
folder('7 Profile, social and the other endpoints', 'Profile, creator lists, episode edit, like, watchlist, comments, follow, report, admin lists.');
request('Profile: update display name and bio', 'PUT', '/auth/me', {
  auth: 'token_viewer',
  json: { display_name: 'Collection viewer', bio: 'hello' },
  expect: 200,
  tests: `pm.test("saved", function () { pm.expect(pm.response.json().user.display_name).to.eql("Collection viewer"); });`,
});
request('Profile: display name is required', 'PUT', '/auth/me', { auth: 'token_viewer', json: { bio: 'x' }, expect: 400 });
request('Creator: lists their own films with every status', 'GET', '/creator/films', {
  auth: 'token_creator',
  expect: 200,
  tests: `pm.test("includes the uploaded film", function () { pm.expect(pm.response.json().films.filter(function (f) { return String(f.id) === pm.environment.get("film_id"); }).length).to.eql(1); });`,
});
request('Episode: owner changes the price of an episode', 'PUT', '/episodes/{{new_free_episode_id}}', {
  auth: 'token_creator',
  json: { price_coins: 5 },
  expect: 200,
  tests: `pm.test("now paid", function () { var e = pm.response.json().episode; pm.expect(e.price_coins).to.eql(5); pm.expect(e.is_free).to.eql(false); });`,
});
request('Episode: another creator cannot change it', 'PUT', '/episodes/{{new_free_episode_id}}', { auth: 'token_other_creator', json: { price_coins: 1 }, expect: 403 });
request('Episode: a price above 500 is refused', 'PUT', '/episodes/{{new_free_episode_id}}', { auth: 'token_creator', json: { price_coins: 501 }, expect: 400 });
request('Episode: owner puts it back to free', 'PUT', '/episodes/{{new_free_episode_id}}', { auth: 'token_creator', json: { is_free: true }, expect: 200 });
request('Like: viewer likes the film', 'POST', '/films/{{film_id}}/like', { auth: 'token_viewer', expect: 200, tests: `pm.test("liked", function () { pm.expect(pm.response.json().liked).to.eql(true); });` });
request('Like: guest cannot like', 'POST', '/films/{{film_id}}/like', { expect: 401 });
request('Like: viewer removes the like', 'DELETE', '/films/{{film_id}}/like', { auth: 'token_viewer', expect: 200 });
request('Watchlist: save the film', 'POST', '/films/{{film_id}}/watchlist', { auth: 'token_viewer', expect: 200 });
request('Watchlist: the saved list holds it', 'GET', '/watchlist', {
  auth: 'token_viewer',
  expect: 200,
  tests: `pm.test("contains the film", function () { pm.expect(pm.response.json().film_ids.map(String).indexOf(pm.environment.get("film_id")) >= 0).to.eql(true); });`,
});
request('Watchlist: remove it', 'DELETE', '/films/{{film_id}}/watchlist', { auth: 'token_viewer', expect: 200 });
request('Comments: guest can read', 'GET', '/films/{{film_id}}/comments', { expect: 200 });
request('Comments: guest cannot write', 'POST', '/films/{{film_id}}/comments', { json: { body: 'hi' }, expect: 401 });
request('Comments: empty comment is refused', 'POST', '/films/{{film_id}}/comments', { auth: 'token_viewer', json: { body: '' }, expect: 400 });
request('Comments: viewer writes one', 'POST', '/films/{{film_id}}/comments', {
  auth: 'token_viewer',
  json: { body: 'Nice film' },
  expect: 201,
  tests: `pm.environment.set("comment_id", String(pm.response.json().id));`,
});
request('Comments: someone else cannot delete it', 'DELETE', '/comments/{{comment_id}}', { auth: 'token_other_creator', expect: 403 });
request('Comments: the author deletes it', 'DELETE', '/comments/{{comment_id}}', { auth: 'token_viewer', expect: 204 });
request('Follow: viewer follows the creator', 'POST', '/creators/{{creator_id}}/follow', { auth: 'token_viewer', expect: 200 });
request('Follow: unfollow', 'DELETE', '/creators/{{creator_id}}/follow', { auth: 'token_viewer', expect: 200 });
request('Report: viewer reports the film', 'POST', '/films/{{film_id}}/reports', {
  auth: 'token_viewer',
  json: { reason: 'Collection test report' },
  expect: 201,
  tests: `pm.environment.set("report_id", String(pm.response.json().id));`,
});
request('Admin: the report is listed', 'GET', '/admin/reports', {
  auth: 'token_admin',
  expect: 200,
  tests: `pm.test("listed", function () { pm.expect(pm.response.json().reports.filter(function (r) { return String(r.id) === pm.environment.get("report_id"); }).length).to.eql(1); });`,
});
request('Admin: resolve the report', 'POST', '/admin/reports/{{report_id}}/resolve', { auth: 'token_admin', expect: 200 });
request('Admin: viewer cannot resolve reports', 'POST', '/admin/reports/{{report_id}}/resolve', { auth: 'token_viewer', expect: 403 });
request('Admin: user list', 'GET', '/admin/users', { auth: 'token_admin', expect: 200, tests: `pm.test("users", function () { pm.expect(pm.response.json().users.length).to.above(0); });` });
request('Admin: live films', 'GET', '/admin/films?status=approved', { auth: 'token_admin', expect: 200 });
request('Admin: an unknown status filter is refused', 'GET', '/admin/films?status=nope', { auth: 'token_admin', expect: 400 });

request('Film: owner edits prices and details in one request (goes back to review)', 'PUT', '/films/{{film_id}}', {
  auth: 'token_creator',
  json: { title: 'Sprint film {{run_id}}', genre: 'Drama', ai_tool: 'Mixed', prompt_credit: 'prompt credit', episode_prices: [{ id: '{{new_free_episode_id}}', price_coins: 0 }] },
  expect: 200,
});
request('Film: an owner edit puts it back in the review queue', 'GET', '/admin/reviews', {
  auth: 'token_admin',
  expect: 200,
  tests: `pm.test("queued again", function () { pm.expect(pm.response.json().films.filter(function (f) { return String(f.id) === pm.environment.get("film_id"); }).length).to.eql(1); });`,
});
request('Film: admin approves it again', 'POST', '/admin/films/{{film_id}}/review', { auth: 'token_admin', json: { status: 'approved' }, expect: 200 });

// ---------------------------------------------------------------------------
folder('8 Take down', 'A taken-down film disappears from every public path.');
request('Admin takes the film down', 'POST', '/admin/films/{{film_id}}/review', {
  auth: 'token_admin',
  json: { status: 'taken_down', note: 'Sprint 1-2 collection clean-up' },
  expect: 200,
});
request('Guest can no longer see it', 'GET', '/films/{{film_id}}', { expect: 404 });
request('Even an unlocked viewer can no longer stream it', 'GET', '/episodes/{{new_paid_episode_id}}/stream', { auth: 'token_viewer', expect: 404 });

const collection = {
  info: {
    name: 'ShortReel Sprint 1-2',
    description:
      'Positive and negative requests for every Sprint 1-2 feature. Run the folders in order against a throw-away database (see docs/postman/README.md). Uses the seed admin account, so never point it at real data.',
    schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json',
  },
  item: folders,
};

const out = path.join(__dirname, 'ShortReel-Sprint1-2.postman_collection.json');
fs.writeFileSync(out, `${JSON.stringify(collection, null, 2)}\n`);
console.log(`wrote ${path.relative(process.cwd(), out)} (${folders.reduce((n, f) => n + f.item.length, 0)} requests)`);
