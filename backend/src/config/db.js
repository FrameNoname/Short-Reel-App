const mysql = require('mysql2/promise');

function createPool(dbConfig) {
  return mysql.createPool({
    ...dbConfig,
    connectionLimit: 10,
    charset: 'utf8mb4',
    timezone: '+07:00',
    // DATE/DATETIME stay as 'YYYY-MM-DD[ HH:MM:SS]' text, so the API never shifts a day.
    dateStrings: true,
  });
}

module.exports = { createPool };
