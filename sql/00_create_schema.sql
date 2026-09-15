DROP TABLE IF EXISTS support_tickets CASCADE;
DROP TABLE IF EXISTS experiments CASCADE;
DROP TABLE IF EXISTS payments CASCADE;
DROP TABLE IF EXISTS subscriptions CASCADE;
DROP TABLE IF EXISTS events CASCADE;
DROP TABLE IF EXISTS acquisition CASCADE;
DROP TABLE IF EXISTS users CASCADE;
DROP TABLE IF EXISTS accounts CASCADE;

CREATE TABLE accounts (
    account_id VARCHAR(20) PRIMARY KEY,
    created_at TIMESTAMP NOT NULL,
    industry VARCHAR(100) NOT NULL,
    employee_band VARCHAR(20) NOT NULL,
    country VARCHAR(100) NOT NULL,
    workspace_type VARCHAR(20) NOT NULL,
    owner_user_id VARCHAR(20) NOT NULL,
    current_plan VARCHAR(20) NOT NULL,
    account_status VARCHAR(20) NOT NULL
);

CREATE TABLE users (
    user_id VARCHAR(20) PRIMARY KEY,
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(account_id),
    signup_timestamp TIMESTAMP NOT NULL,
    signup_date DATE NOT NULL,
    country VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    job_role VARCHAR(50),
    user_type VARCHAR(20) NOT NULL,
    signup_device VARCHAR(20) NOT NULL,
    is_deleted BOOLEAN NOT NULL,
    deleted_at TIMESTAMP
);

CREATE TABLE acquisition (
    user_id VARCHAR(20) PRIMARY KEY REFERENCES users(user_id),
    acquisition_timestamp TIMESTAMP NOT NULL,
    channel VARCHAR(50) NOT NULL,
    source VARCHAR(50),
    medium VARCHAR(50),
    campaign_name VARCHAR(100),
    campaign_type VARCHAR(50),
    landing_page VARCHAR(255),
    signup_offer VARCHAR(100),
    estimated_acquisition_cost NUMERIC(10,2)
);

CREATE TABLE events (
    event_id VARCHAR(30) PRIMARY KEY,
    user_id VARCHAR(20) NOT NULL REFERENCES users(user_id),
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(account_id),
    session_id VARCHAR(50) NOT NULL,
    event_name VARCHAR(100) NOT NULL,
    event_timestamp TIMESTAMP NOT NULL,
    event_date DATE NOT NULL,
    platform VARCHAR(20) NOT NULL,
    feature_category VARCHAR(50) NOT NULL,
    event_success BOOLEAN,
    integration_type VARCHAR(50),
    workflow_type VARCHAR(100),
    template_used VARCHAR(100),
    ai_action_type VARCHAR(100),
    workflow_run_duration_seconds NUMERIC(10,2),
    error_type VARCHAR(100)
);

CREATE TABLE subscriptions (
    subscription_id VARCHAR(30) PRIMARY KEY,
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(account_id),
    plan_name VARCHAR(20) NOT NULL,
    billing_cycle VARCHAR(20) NOT NULL,
    subscription_start_date DATE NOT NULL,
    subscription_end_date DATE,
    status VARCHAR(20) NOT NULL,
    monthly_equivalent_price NUMERIC(12,2) NOT NULL,
    seats_purchased INTEGER NOT NULL CHECK (seats_purchased > 0),
    trial_start_date DATE,
    trial_end_date DATE,
    cancellation_date DATE,
    cancellation_reason VARCHAR(100)
);

CREATE TABLE payments (
    payment_id VARCHAR(30) PRIMARY KEY,
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(account_id),
    subscription_id VARCHAR(30) NOT NULL REFERENCES subscriptions(subscription_id),
    payment_date DATE NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    currency CHAR(3) NOT NULL,
    payment_status VARCHAR(20) NOT NULL,
    billing_cycle VARCHAR(20) NOT NULL
);

CREATE TABLE experiments (
    experiment_id VARCHAR(30) NOT NULL,
    experiment_name VARCHAR(100) NOT NULL,
    user_id VARCHAR(20) NOT NULL REFERENCES users(user_id),
    variant VARCHAR(20) NOT NULL,
    assigned_timestamp TIMESTAMP NOT NULL,
    experiment_start_date DATE NOT NULL,
    experiment_end_date DATE NOT NULL,
    eligibility_group VARCHAR(100) NOT NULL,
    exposure_timestamp TIMESTAMP,
    PRIMARY KEY (experiment_id, user_id)
);

CREATE TABLE support_tickets (
    ticket_id VARCHAR(30) PRIMARY KEY,
    user_id VARCHAR(20) NOT NULL REFERENCES users(user_id),
    account_id VARCHAR(20) NOT NULL REFERENCES accounts(account_id),
    created_timestamp TIMESTAMP NOT NULL,
    category VARCHAR(50) NOT NULL,
    priority VARCHAR(20) NOT NULL,
    resolved_timestamp TIMESTAMP,
    resolution_time_hours NUMERIC(10,2),
    csat_score NUMERIC(3,1),
    resolved BOOLEAN NOT NULL
);

CREATE INDEX idx_users_account_id
    ON users(account_id);

CREATE INDEX idx_users_signup_date
    ON users(signup_date);

CREATE INDEX idx_events_user_timestamp
    ON events(user_id, event_timestamp);

CREATE INDEX idx_events_name_timestamp
    ON events(event_name, event_timestamp);

CREATE INDEX idx_events_account_id
    ON events(account_id);

CREATE INDEX idx_subscriptions_account_id
    ON subscriptions(account_id);

CREATE INDEX idx_payments_subscription_id
    ON payments(subscription_id);

CREATE INDEX idx_support_user_id
    ON support_tickets(user_id);

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

SELECT constraint_name
FROM information_schema.table_constraints
WHERE table_name = 'accounts'
  AND constraint_type = 'FOREIGN KEY';

SELECT 'accounts' AS table_name, COUNT(*) AS row_count FROM accounts
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'acquisition', COUNT(*) FROM acquisition
UNION ALL
SELECT 'subscriptions', COUNT(*) FROM subscriptions
UNION ALL
SELECT 'payments', COUNT(*) FROM payments
UNION ALL
SELECT 'events', COUNT(*) FROM events
UNION ALL
SELECT 'experiments', COUNT(*) FROM experiments
UNION ALL
SELECT 'support_tickets', COUNT(*) FROM support_tickets
ORDER BY table_name;

SELECT COUNT(*) AS users_without_account
FROM users u
LEFT JOIN accounts a
    ON u.account_id = a.account_id
WHERE a.account_id IS NULL;

SELECT COUNT(*) AS accounts_without_valid_owner
FROM accounts a
LEFT JOIN users u
    ON a.owner_user_id = u.user_id
WHERE u.user_id IS NULL;

SELECT COUNT(*) AS events_without_user
FROM events e
LEFT JOIN users u
    ON e.user_id = u.user_id
WHERE u.user_id IS NULL;