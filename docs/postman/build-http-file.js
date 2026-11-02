#!/usr/bin/env node
// Builds docs/api-tests.http (VS Code "REST Client" format, also readable by
// JetBrains HTTP Client) from the Postman collection, so the same 116 requests
// can be run one by one in a light client. Each request lists the status and
// checks to look for; variables that Postman scripts would set are wired up with
// named-request references instead (`{{reg_viewer.response.body.$.token}}`).
//
//   node docs/postman/build-http-file.js
const fs = require('node:fs');
const path = require('node:path');

const collection = require('./ShortReel-Sprint1-2.postman_collection.json');

// Postman request name -> request name used for references in the .http file.
const SLUG = {
  'Register viewer: valid': 'reg_viewer',
  'Register creator: valid': 'reg_creator',
  'Register second creator (for ownership checks)': 'reg_other',
  'Login admin (seed account)': 'login_admin',
  'Creator: create film (pending)': 'new_film',
  'Upload: episode 1, free (multipart)': 'up_free',
  'Upload: episode 2, 30 coins (multipart)': 'up_paid',
  'Subscription: subscribe (simulated)': 'sub1',
  'Subscription: renew twice, plans never overlap': 'sub2',
  'Comments: viewer writes one': 'new_comment',
  'Report: viewer reports the film': 'new_report',
};

const FILES = {
  '{{sample_video_path}}': '../backend/uploads/demo_demo_clip_01.mp4',
  '{{header_only_path}}': './postman/fixtures/header-only.mp4',
  '{{text_file_path}}': './postman/fixtures/not-a-video.txt',
};
const FILE_TYPE = { '.txt': 'text/plain' };

const out = [];
const line = (text = '') => out.push(text);

line('# ShortReel Sprint 1-2 API tests (VS Code "REST Client" extension: humao.rest-client)');
line('#');
line('# HOW TO USE');
line('#  1. Use a THROW-AWAY database and server, never the real `shortreel` (see docs/postman/README.md).');
line('#  2. Edit the variables below, then run the requests TOP TO BOTTOM (click "Send Request" above each one).');
line('#  3. Compare each response with the "Expect" lines above it.');
line('#  4. Change @run_id every time you start a new full run (usernames must be new).');
line('#');
line('# Seed ids below (film 1, episode 1 = free, episode 3 = paid) are valid for a fresh database from shortreel.sql.');
line();
line('@base_url = http://localhost:3100/api');
line('@run_id = r1');
line('@admin_username = admin');
line('# Password of the seed admin account (see README). Not stored in git: type it here locally.');
line('@admin_password = ');
line('@token_expired = expired.invalid.token');
line();
line('@seed_film_id = 1');
line('@free_episode_id = 1');
line('@paid_episode_id = 3');
line();
line('# Filled from earlier responses (do not edit)');
line('@token_viewer = {{reg_viewer.response.body.$.token}}');
line('@viewer_id = {{reg_viewer.response.body.$.user.id}}');
line('@token_creator = {{reg_creator.response.body.$.token}}');
line('@creator_id = {{reg_creator.response.body.$.user.id}}');
line('@token_other_creator = {{reg_other.response.body.$.token}}');
line('@token_admin = {{login_admin.response.body.$.token}}');
line('@admin_id = {{login_admin.response.body.$.user.id}}');
line('@film_id = {{new_film.response.body.$.film.id}}');
line('@new_free_episode_id = {{up_free.response.body.$.episode.id}}');
line('@new_paid_episode_id = {{up_paid.response.body.$.episode.id}}');
line('@comment_id = {{new_comment.response.body.$.id}}');
line('@report_id = {{new_report.response.body.$.id}}');

let count = 0;
for (const group of collection.item) {
  line();
  line('###############################################################');
  line(`# ${group.name.toUpperCase()}`);
  line('###############################################################');
  for (const item of group.item) {
    count += 1;
    const req = item.request;
    const script = item.event[0].script.exec.join('\n');
    const status = /to\.eql\((\d+)\); \}\);/.exec(script)?.[1];
    const checks = [...script.matchAll(/pm\.test\("([^"]+)"/g)].map((m) => m[1]).filter((t) => !t.includes(': status is '));
    line();
    line(`### ${count}. ${item.name}`);
    line(`# Expect: HTTP ${status}`);
    for (const c of checks) line(`#   check: ${c}`);
    if (item.name === 'Subscription: third purchase starts after the second ends') line('#   compare: paid_through is later than the paid_through of the previous request');
    if (item.name === 'Subscription: the latest plan is read back') line('#   compare: paid_through is later than end_date of the first subscription');
    if (SLUG[item.name]) line(`# @name ${SLUG[item.name]}`);

    let url = req.url.raw;
    const headers = req.header.filter((h) => h.key !== 'Content-Type');
    if (item.name === 'Login admin (seed account)') line('# (needs @admin_password set above)');
    line(`${req.method} ${url} HTTP/1.1`);
    for (const h of headers) line(`${h.key}: ${h.value}`);
    if (req.body?.mode === 'raw') {
      line('Content-Type: application/json');
      line();
      line(req.body.raw);
    } else if (req.body?.mode === 'formdata') {
      line('Content-Type: multipart/form-data; boundary=----ShortReelBoundary');
      line();
      for (const part of req.body.formdata) {
        line('------ShortReelBoundary');
        if (part.type === 'file') {
          const file = FILES[part.src];
          const type = FILE_TYPE[path.extname(file)] ?? 'video/mp4';
          line(`Content-Disposition: form-data; name="${part.key}"; filename="${path.basename(file)}"`);
          line(`Content-Type: ${type}`);
          line();
          line(`< ${file}`);
        } else {
          line(`Content-Disposition: form-data; name="${part.key}"`);
          line();
          line(part.value);
        }
      }
      line('------ShortReelBoundary--');
    }
  }
}

const target = path.join(__dirname, '..', 'api-tests.http');
fs.writeFileSync(target, `${out.join('\n')}\n`);
console.log(`wrote ${path.relative(process.cwd(), target)} (${count} requests)`);
