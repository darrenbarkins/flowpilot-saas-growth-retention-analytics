-- ============================================================
-- FlowPilot SaaS Product Growth & Retention Analytics
-- 07_experiment_analysis.sql
--
-- Purpose:
-- Evaluate the Guided Onboarding A/B experiment.
--
-- Primary metric:
--   Activation rate
--
-- Secondary metrics:
--   7-day retention
--   30-day retention
--   Integration connection
--   Template adoption
--   Paid conversion
--
-- Guardrail metrics:
--   Support ticket rate
--   Cancellation rate
-- ============================================================


-- ------------------------------------------------------------
-- 1. Inspect experiment table
-- ------------------------------------------------------------

SELECT *
FROM experiments
LIMIT 20;

-- ------------------------------------------------------------
-- 2. Inspect experiment table column names
-- ------------------------------------------------------------

SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'experiments'
ORDER BY ordinal_position;

-- ------------------------------------------------------------
-- 3. Check experiment sample size by variant
-- ------------------------------------------------------------

SELECT
    variant,
    COUNT(*) AS assignments,
    COUNT(DISTINCT user_id) AS unique_users
FROM experiments
WHERE experiment_id = 'EXP001'
GROUP BY variant
ORDER BY variant;

-- ------------------------------------------------------------
-- 4. Check for duplicate or cross-variant assignments
-- ------------------------------------------------------------

SELECT
    user_id,
    COUNT(*) AS assignment_count,
    COUNT(DISTINCT variant) AS variant_count
FROM experiments
WHERE experiment_id = 'EXP001'
GROUP BY user_id
HAVING
    COUNT(*) > 1
    OR COUNT(DISTINCT variant) > 1
ORDER BY assignment_count DESC, user_id;

-- ------------------------------------------------------------
-- 5. Primary metric: activation rate by experiment variant
-- ------------------------------------------------------------

WITH experiment_users AS (
    SELECT
        e.user_id,
        e.variant,
        u.signup_timestamp
    FROM experiments e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.experiment_id = 'EXP001'
),

activation AS (
    SELECT DISTINCT
        eu.user_id
    FROM experiment_users eu
    JOIN events ev
        ON eu.user_id = ev.user_id
    WHERE ev.event_name = 'workflow_run_success'
      AND ev.event_timestamp >= eu.signup_timestamp
      AND ev.event_timestamp < eu.signup_timestamp + INTERVAL '7 days'
)

SELECT
    eu.variant,
    COUNT(*) AS users,
    COUNT(a.user_id) AS activated_users,
    ROUND(
        100.0 * COUNT(a.user_id) / COUNT(*),
        2
    ) AS activation_rate
FROM experiment_users eu
LEFT JOIN activation a
    ON eu.user_id = a.user_id
GROUP BY eu.variant
ORDER BY eu.variant;

-- ------------------------------------------------------------
-- 6. Secondary metric: 7-day retention by experiment variant
-- ------------------------------------------------------------

WITH experiment_users AS (
    SELECT
        e.user_id,
        e.variant,
        u.signup_timestamp
    FROM experiments e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.experiment_id = 'EXP001'
),

retained_7d AS (
    SELECT DISTINCT
        eu.user_id
    FROM experiment_users eu
    JOIN events ev
        ON eu.user_id = ev.user_id
    WHERE ev.event_name IN (
        'workflow_created',
        'workflow_run_success',
        'workflow_edited',
        'integration_connected',
        'ai_action_used',
        'workflow_shared',
        'scheduled_automation_created',
        'scheduled_automation_run',
        'dashboard_viewed'
    )
      AND ev.event_timestamp >= eu.signup_timestamp + INTERVAL '7 days'
      AND ev.event_timestamp < eu.signup_timestamp + INTERVAL '14 days'
)

SELECT
    eu.variant,
    COUNT(*) AS users,
    COUNT(r.user_id) AS retained_users,
    ROUND(
        100.0 * COUNT(r.user_id) / COUNT(*),
        2
    ) AS retention_7d_rate
FROM experiment_users eu
LEFT JOIN retained_7d r
    ON eu.user_id = r.user_id
GROUP BY eu.variant
ORDER BY eu.variant;

-- ------------------------------------------------------------
-- 7. Secondary metric: 30-day retention by experiment variant
-- ------------------------------------------------------------

WITH experiment_users AS (
    SELECT
        e.user_id,
        e.variant,
        u.signup_timestamp
    FROM experiments e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.experiment_id = 'EXP001'
),

retained_30d AS (
    SELECT DISTINCT
        eu.user_id
    FROM experiment_users eu
    JOIN events ev
        ON eu.user_id = ev.user_id
    WHERE ev.event_name IN (
        'workflow_created',
        'workflow_run_success',
        'workflow_edited',
        'integration_connected',
        'ai_action_used',
        'workflow_shared',
        'scheduled_automation_created',
        'scheduled_automation_run',
        'dashboard_viewed'
    )
      AND ev.event_timestamp >= eu.signup_timestamp + INTERVAL '30 days'
      AND ev.event_timestamp < eu.signup_timestamp + INTERVAL '37 days'
)

SELECT
    eu.variant,
    COUNT(*) AS users,
    COUNT(r.user_id) AS retained_users,
    ROUND(
        100.0 * COUNT(r.user_id) / COUNT(*),
        2
    ) AS retention_30d_rate
FROM experiment_users eu
LEFT JOIN retained_30d r
    ON eu.user_id = r.user_id
GROUP BY eu.variant
ORDER BY eu.variant;

-- ------------------------------------------------------------
-- 8. Secondary metric: early integration connection
-- ------------------------------------------------------------

WITH experiment_users AS (
    SELECT
        e.user_id,
        e.variant,
        u.signup_timestamp
    FROM experiments e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.experiment_id = 'EXP001'
),

integration_users AS (
    SELECT DISTINCT
        eu.user_id
    FROM experiment_users eu
    JOIN events ev
        ON eu.user_id = ev.user_id
    WHERE ev.event_name = 'integration_connected'
      AND ev.event_timestamp >= eu.signup_timestamp
      AND ev.event_timestamp < eu.signup_timestamp + INTERVAL '7 days'
)

SELECT
    eu.variant,
    COUNT(*) AS users,
    COUNT(i.user_id) AS integration_users,
    ROUND(
        100.0 * COUNT(i.user_id) / COUNT(*),
        2
    ) AS integration_rate
FROM experiment_users eu
LEFT JOIN integration_users i
    ON eu.user_id = i.user_id
GROUP BY eu.variant
ORDER BY eu.variant;

-- ------------------------------------------------------------
-- 9. Secondary metric: early template adoption
-- ------------------------------------------------------------

WITH experiment_users AS (
    SELECT
        e.user_id,
        e.variant,
        u.signup_timestamp
    FROM experiments e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.experiment_id = 'EXP001'
),

template_users AS (
    SELECT DISTINCT
        eu.user_id
    FROM experiment_users eu
    JOIN events ev
        ON eu.user_id = ev.user_id
    WHERE ev.event_name = 'template_used'
      AND ev.event_timestamp >= eu.signup_timestamp
      AND ev.event_timestamp < eu.signup_timestamp + INTERVAL '7 days'
)

SELECT
    eu.variant,
    COUNT(*) AS users,
    COUNT(t.user_id) AS template_users,
    ROUND(
        100.0 * COUNT(t.user_id) / COUNT(*),
        2
    ) AS template_rate
FROM experiment_users eu
LEFT JOIN template_users t
    ON eu.user_id = t.user_id
GROUP BY eu.variant
ORDER BY eu.variant;

-- ------------------------------------------------------------
-- 10. Secondary metric: paid conversion by experiment variant
-- ------------------------------------------------------------

WITH experiment_users AS (
    SELECT
        e.user_id,
        e.variant,
        u.account_id
    FROM experiments e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.experiment_id = 'EXP001'
),

paid_accounts AS (
    SELECT DISTINCT
        account_id
    FROM subscriptions
    WHERE status = 'Active'
)

SELECT
    eu.variant,
    COUNT(*) AS users,
    COUNT(pa.account_id) AS paid_users,
    ROUND(
        100.0 * COUNT(pa.account_id) / COUNT(*),
        2
    ) AS paid_conversion_rate
FROM experiment_users eu
LEFT JOIN paid_accounts pa
    ON eu.account_id = pa.account_id
GROUP BY eu.variant
ORDER BY eu.variant;

-- ------------------------------------------------------------
-- 11. Inspect support ticket table column names
-- ------------------------------------------------------------

SELECT
    ordinal_position,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_name = 'support_tickets'
ORDER BY ordinal_position;

-- ------------------------------------------------------------
-- 12. Guardrail metric: support ticket rate by variant
-- ------------------------------------------------------------

WITH experiment_users AS (
    SELECT
        user_id,
        variant,
        assigned_timestamp
    FROM experiments
    WHERE experiment_id = 'EXP001'
),

support_users AS (
    SELECT DISTINCT
        eu.user_id
    FROM experiment_users eu
    JOIN support_tickets st
        ON eu.user_id = st.user_id
    WHERE st.created_timestamp >= eu.assigned_timestamp
      AND st.created_timestamp < eu.assigned_timestamp + INTERVAL '7 days'
)

SELECT
    eu.variant,
    COUNT(*) AS users,
    COUNT(su.user_id) AS users_with_support_ticket,
    ROUND(
        100.0 * COUNT(su.user_id) / COUNT(*),
        2
    ) AS support_ticket_rate
FROM experiment_users eu
LEFT JOIN support_users su
    ON eu.user_id = su.user_id
GROUP BY eu.variant
ORDER BY eu.variant;

-- ------------------------------------------------------------
-- 13. Guardrail metric: cancellation rate by variant
-- ------------------------------------------------------------

WITH experiment_users AS (
    SELECT
        e.user_id,
        e.variant,
        u.account_id
    FROM experiments e
    JOIN users u
        ON e.user_id = u.user_id
    WHERE e.experiment_id = 'EXP001'
),

cancelled_accounts AS (
    SELECT DISTINCT
        account_id
    FROM subscriptions
    WHERE status = 'Cancelled'
)

SELECT
    eu.variant,
    COUNT(*) AS users,
    COUNT(ca.account_id) AS users_on_cancelled_accounts,
    ROUND(
        100.0 * COUNT(ca.account_id) / COUNT(*),
        2
    ) AS cancellation_rate
FROM experiment_users eu
LEFT JOIN cancelled_accounts ca
    ON eu.account_id = ca.account_id
GROUP BY eu.variant
ORDER BY eu.variant;
