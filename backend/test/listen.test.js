const test = require('node:test');
const assert = require('node:assert/strict');
const net = require('node:net');
const { listen } = require('../src/listen');
const { makeApp } = require('./helpers');

test('listen rejects when the port is taken', async () => {
  const blocker = net.createServer();
  await new Promise((resolve) => blocker.listen(0, '127.0.0.1', resolve));
  const { port } = blocker.address();
  await assert.rejects(listen(makeApp(), port, '127.0.0.1'), { code: 'EADDRINUSE' });
  blocker.close();
});

test('listen resolves with the running server', async () => {
  const server = await listen(makeApp(), 0, '127.0.0.1');
  assert.ok(server.address().port > 0);
  server.close();
});
