#!/usr/bin/env node
// A small, dependency-free runner for the Sprint 1-2 collection. It exists for
// machines where Newman is not installed; it is NOT Newman and supports only the
// part of the Postman API that build-collection.js uses. Run the same file in
// Postman or `npx newman run ...` for the official tools.
//
//   node docs/postman/run-collection.js \
//     --env docs/postman/ShortReel-local.postman_environment.example.json \
//     [--report docs/postman/last-run.json]
//
// Optional: E2E_JWT_SECRET=<secret of the test server> lets the "expired" request
// use a genuinely expired token (the secret is read from the environment and is
// never written to the report).
const fs = require('node:fs');
const path = require('node:path');

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(`--${name}`);
  return i === -1 ? undefined : args[i + 1];
};

const collectionPath = flag('collection') ?? path.join(__dirname, 'ShortReel-Sprint1-2.postman_collection.json');
const envPath = flag('env') ?? path.join(__dirname, 'ShortReel-local.postman_environment.example.json');
const reportPath = flag('report');

const collection = JSON.parse(fs.readFileSync(collectionPath, 'utf8'));
const envFile = JSON.parse(fs.readFileSync(envPath, 'utf8'));
const vars = Object.fromEntries(envFile.values.filter((v) => v.enabled !== false).map((v) => [v.key, v.value]));
for (const [key, value] of Object.entries(process.env)) {
  if (key.startsWith('PM_')) vars[key.slice(3).toLowerCase()] = value; // PM_BASE_URL=... overrides base_url, PM_ADMIN_PASSWORD=... fills admin_password
}

const fill = (text) =>
  String(text).replace(/\{\{([^}]+)\}\}/g, (match, name) => {
    if (name === '$timestamp') return String(Math.floor(Date.now() / 1000));
    if (name === '$randomInt') return String(Math.floor(Math.random() * 1000));
    return name in vars ? String(vars[name]) : match;
  });

function expectation(actual) {
  const fail = (message) => {
    throw new Error(message);
  };
  const show = (v) => JSON.stringify(v);
  const base = {
    eql: (expected) => {
      if (JSON.stringify(actual) !== JSON.stringify(expected)) fail(`expected ${show(actual)} to equal ${show(expected)}`);
    },
    above: (n) => {
      if (!(actual > n)) fail(`expected ${show(actual)} to be above ${n}`);
    },
    include: (part) => {
      if (!String(actual).includes(part)) fail(`expected ${show(actual)} to include ${show(part)}`);
    },
  };
  return { to: { ...base, be: base } };
}

async function send(item) {
  const { request } = item;
  const url = fill(request.url.raw);
  const headers = {};
  for (const h of request.header ?? []) headers[h.key] = fill(h.value);
  let body;
  if (request.body?.mode === 'raw') body = fill(request.body.raw);
  if (request.body?.mode === 'formdata') {
    body = new FormData();
    for (const part of request.body.formdata) {
      if (part.type === 'file') {
        const file = fill(part.src);
        const isVideo = part.key === 'video' && !file.endsWith('.txt');
        body.append(part.key, new Blob([fs.readFileSync(file)], { type: isVideo ? 'video/mp4' : 'text/plain' }), path.basename(file));
      } else {
        body.append(part.key, fill(part.value));
      }
    }
  }
  const started = Date.now();
  const response = await fetch(url, { method: request.method, headers, body });
  const raw = await response.text();
  let json;
  try {
    json = JSON.parse(raw);
  } catch {
    json = undefined;
  }
  return { code: response.status, raw, json, ms: Date.now() - started };
}

async function main() {
  if (process.env.E2E_JWT_SECRET) {
    // Resolved lazily: only needed to mint an expired token for the test server.
    globalThis.mintExpired = (sub) =>
      require(path.join(__dirname, '..', '..', 'backend', 'node_modules', 'jsonwebtoken')).sign(
        { sub: String(sub), role: 'viewer', exp: Math.floor(Date.now() / 1000) - 3600 },
        process.env.E2E_JWT_SECRET,
      );
  }
  const results = [];
  let requests = 0;
  for (const group of collection.item) {
    console.log(`\n## ${group.name}`);
    for (const item of group.item) {
      requests += 1;
      if (item.name.startsWith('Token expired') && globalThis.mintExpired) vars.token_expired = globalThis.mintExpired(vars.viewer_id);
      let res;
      try {
        res = await send(item);
      } catch (err) {
        results.push({ group: group.name, request: item.name, test: 'request sent', ok: false, message: err.message });
        console.log(`  FAIL ${item.name}: ${err.message}`);
        continue;
      }
      const pm = {
        response: { code: res.code, json: () => res.json ?? {} },
        environment: { get: (k) => vars[k], set: (k, v) => { vars[k] = v; } },
        expect: expectation,
        test: (name, fn) => {
          try {
            fn();
            results.push({ group: group.name, request: item.name, test: name, ok: true });
            console.log(`  ok   ${name}`);
          } catch (err) {
            results.push({ group: group.name, request: item.name, test: name, ok: false, message: err.message });
            console.log(`  FAIL ${name}: ${err.message}`);
          }
        },
      };
      const script = item.event.find((e) => e.listen === 'test').script.exec.join('\n');
      try {
        new Function('pm', 'Number', 'String', script)(pm, Number, String);
      } catch (err) {
        results.push({ group: group.name, request: item.name, test: 'script ran', ok: false, message: err.message });
        console.log(`  FAIL ${item.name}: script error ${err.message}`);
      }
    }
  }
  const failed = results.filter((r) => !r.ok);
  console.log(`\n${requests} requests, ${results.length} assertions, ${failed.length} failed`);
  if (reportPath) {
    fs.writeFileSync(
      reportPath,
      `${JSON.stringify({ tool: 'docs/postman/run-collection.js (not Newman)', base_url: vars.base_url, requests, assertions: results.length, failed: failed.length, results }, null, 2)}\n`,
    );
  }
  process.exit(failed.length === 0 ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(2);
});
