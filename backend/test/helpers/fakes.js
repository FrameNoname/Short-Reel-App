// Test doubles for unit tests: no database and no HTTP server.
//
// fakePool(rules) answers pool.query(sql, params) from a list of
// [pattern, answer] rules. The first rule whose pattern (a RegExp or a
// substring) matches the SQL wins. An answer is either the value to return as
// the first element of mysql2's [rows, fields] pair, or a function
// (params, sql) => value. A query that no rule matches throws, so a test fails
// loudly when the code runs SQL the test did not expect.
function fakePool(rules = []) {
  const calls = [];
  const tx = { begun: 0, committed: 0, rolledBack: 0, released: 0 };

  async function query(sql, params = []) {
    calls.push({ sql, params });
    for (const [pattern, answer] of rules) {
      const hit = pattern instanceof RegExp ? pattern.test(sql) : sql.includes(pattern);
      if (hit) {
        const value = typeof answer === 'function' ? await answer(params, sql) : answer;
        return [value, []];
      }
    }
    throw new Error(`Unexpected SQL in test: ${sql.replace(/\s+/g, ' ').trim()}`);
  }

  const conn = {
    query,
    beginTransaction: async () => { tx.begun += 1; },
    commit: async () => { tx.committed += 1; },
    rollback: async () => { tx.rolledBack += 1; },
    release: () => { tx.released += 1; },
  };

  return {
    query,
    getConnection: async () => conn,
    calls,
    tx,
    // The calls whose SQL matches, for asserting on what was written.
    callsMatching: (pattern) =>
      calls.filter(({ sql }) => (pattern instanceof RegExp ? pattern.test(sql) : sql.includes(pattern))),
  };
}

// A request as the controllers see it.
function fakeReq({ pool, user, body, params = {}, query = {}, headers = {}, locals = {} } = {}) {
  return {
    app: { locals: { pool, jwtSecret: 'test-secret', jwtExpiresIn: '1h', ...locals } },
    user,
    body,
    params,
    query,
    headers,
  };
}

// A response that records what the controller sent.
function fakeRes() {
  const res = {
    statusCode: 200,
    body: undefined,
    ended: false,
    status(code) {
      res.statusCode = code;
      return res;
    },
    json(body) {
      res.body = body;
      res.ended = true;
      return res;
    },
    end() {
      res.ended = true;
      return res;
    },
  };
  return res;
}

module.exports = { fakePool, fakeReq, fakeRes };
