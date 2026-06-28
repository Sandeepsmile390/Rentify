const { drizzle } = require('drizzle-orm/node-postgres');
const { Pool } = require('pg');
const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../.env') });

const connectionString = process.env.DATABASE_URL || 'postgresql://postgres:postgres@localhost:5432/postgres';

const pool = new Pool({
  connectionString: connectionString,
  max: 10,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 5000,
  ssl: connectionString.includes('supabase') || connectionString.includes('supabase.co')
    ? { rejectUnauthorized: false }
    : false,
});

pool.query('SELECT NOW()', (err, res) => {
  if (err) {
    console.error('❌ PostgreSQL Connection Error:', err.message);
    console.log('👉 Please check your credentials inside api/.env');
  } else {
    console.log('✅ PostgreSQL connected successfully via connection pool.');
  }
});

const db = drizzle(pool);

module.exports = { db, pool };
