const test = require('node:test');
const assert = require('node:assert/strict');
const { pathId, text, int, bool } = require('../src/utils/validate');

const isValidation = (err) => err.status === 400 && err.code === 'VALIDATION_ERROR';

test('pathId accepts digits and rejects anything else', () => {
  assert.equal(pathId('42'), 42);
  assert.equal(pathId(7), 7);
  for (const bad of ['', '-1', '1.5', 'abc', '1234567890', undefined]) {
    assert.throws(() => pathId(bad), isValidation, `"${bad}" should fail`);
  }
});

test('text trims, checks length and handles optional fields', () => {
  assert.equal(text({ name: '  hi  ' }, 'name'), 'hi');
  assert.equal(text({}, 'name', { optional: true }), undefined);
  assert.throws(() => text({}, 'name'), isValidation);
  assert.throws(() => text({ name: 5 }, 'name'), isValidation);
  assert.throws(() => text({ name: 'abcdef' }, 'name', { max: 5 }), isValidation);
  assert.throws(() => text({ name: 'ab' }, 'name', { min: 3, max: 10 }), isValidation);
});

test('int accepts numbers and numeric strings inside the range', () => {
  assert.equal(int({ n: 5 }, 'n', { min: 0, max: 10 }), 5);
  assert.equal(int({ n: ' 7 ' }, 'n', { min: 0, max: 10 }), 7);
  assert.equal(int({}, 'n', { min: 0, max: 10, optional: true }), undefined);
  assert.throws(() => int({ n: 11 }, 'n', { min: 0, max: 10 }), isValidation);
  assert.throws(() => int({ n: -1 }, 'n', { min: 0, max: 10 }), isValidation);
  assert.throws(() => int({ n: 1.5 }, 'n', { min: 0, max: 10 }), isValidation);
  assert.throws(() => int({ n: 'x' }, 'n', { min: 0, max: 10 }), isValidation);
});

test('bool reads true/false in their common forms', () => {
  for (const v of [true, 'true', '1', 1]) assert.equal(bool({ b: v }, 'b'), true);
  for (const v of [false, 'false', '0', 0]) assert.equal(bool({ b: v }, 'b'), false);
  assert.equal(bool({}, 'b', { optional: true }), undefined);
  assert.throws(() => bool({ b: 'yes' }, 'b'), isValidation);
});
