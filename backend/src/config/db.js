const mysql = require('mysql2/promise');

function createPool(dbConfig) {
  return mysql.createPool({
    ...dbConfig,
    connectionLimit: 10,
    charset: 'utf8mb4',
    timezone: '+07:00',
  });
}

module.exports = { createPool };
