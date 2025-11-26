-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create index on email for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Seed with 100,000 users
INSERT INTO users (name, email)
SELECT
    'User ' || generate_series,
    'user' || generate_series || '@example.com'
FROM generate_series(1, 100000)
ON CONFLICT (email) DO NOTHING;

-- Analyze table for query optimization
ANALYZE users;
