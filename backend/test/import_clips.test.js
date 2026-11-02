const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { storedName } = require('../scripts/import-demo-clips');
const { makeMp4 } = require('./db');

test('clips whose names sanitize alike get different stored names, and the same bytes the same name', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'clips-'));
  try {
    const a = path.join(dir, 'ก.mp4');
    const b = path.join(dir, 'ข.mp4');
    const copy = path.join(dir, 'ค.mp4');
    fs.writeFileSync(a, makeMp4(3000));
    fs.writeFileSync(b, makeMp4(4000));
    fs.writeFileSync(copy, makeMp4(3000));
    assert.notEqual(storedName(a), storedName(b));
    assert.equal(storedName(a), storedName(copy));
    assert.match(storedName(a), /^demo_[A-Za-z0-9_-]*[0-9a-f]{12}\.mp4$/);
  } finally {
    fs.rmSync(dir, { recursive: true, force: true });
  }
});
