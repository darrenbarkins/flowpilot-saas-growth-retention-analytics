-- ============================================================
-- FLOWPILOT PRODUCT FUNNEL ANALYSIS
-- ============================================================

-- Business Funnel:
-- Signup
-- -> Workspace Created
-- -> Integration Connected
-- -> Workflow Created
-- -> Successful Workflow Run
--
-- Activation KPI:
-- Successful workflow run within 7 days of signup
--
-- Paid KPI:
-- User belongs to an account currently on Pro or Business


-- ============================================================
-- 1. STRICT SEQUENTIAL ONBOARDING FUNNEL
-- ============================================================

WITH funnel_times AS (
    SELECT
        u.user_id,
        u.signup_timestamp,

        MIN(
            CASE
                WHEN e.event_name = 'workspace_created'
                THEN e.event_timestamp
            END
        ) AS workspace_created_at,

        MIN(
            CASE
                WHEN e.event_name = 'integration_connected'
                THEN e.event_timestamp
            END
        ) AS integration_connected_at,

        MIN(
            CASE
                WHEN e.event_name = 'workflow_created'
                THEN e.event_timestamp
            END
        ) AS workflow_created_at,

        MIN(
            CASE
                WHEN e.event_name = 'workflow_run_success'
                THEN e.event_timestamp
            END
        ) AS workflow_run_success_at

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY
        u.user_id,
        u.signup_timestamp
),

user_funnel AS (
    SELECT
        user_id,

        CASE
            WHEN workspace_created_at >= signup_timestamp
            THEN 1
            ELSE 0
        END AS created_workspace,

        CASE
            WHEN workspace_created_at >= signup_timestamp
             AND integration_connected_at >= workspace_created_at
            THEN 1
            ELSE 0
        END AS connected_integration,

        CASE
            WHEN workspace_created_at >= signup_timestamp
             AND integration_connected_at >= workspace_created_at
             AND workflow_created_at >= integration_connected_at
            THEN 1
            ELSE 0
        END AS created_workflow,

        CASE
            WHEN workspace_created_at >= signup_timestamp
             AND integration_connected_at >= workspace_created_at
             AND workflow_created_at >= integration_connected_at
             AND workflow_run_success_at >= workflow_created_at
            THEN 1
            ELSE 0
        END AS successful_workflow_run

    FROM funnel_times
)

SELECT
    COUNT(*) AS total_signups,

    SUM(created_workspace) AS workspace_created_users,

    SUM(connected_integration) AS integration_connected_users,

    SUM(created_workflow) AS workflow_created_users,

    SUM(successful_workflow_run) AS successful_workflow_run_users,

    ROUND(
        100.0 * SUM(created_workspace) / COUNT(*),
        2
    ) AS signup_to_workspace_pct,

    ROUND(
        100.0 * SUM(connected_integration)
        / NULLIF(SUM(created_workspace), 0),
        2
    ) AS workspace_to_integration_pct,

    ROUND(
        100.0 * SUM(created_workflow)
        / NULLIF(SUM(connected_integration), 0),
        2
    ) AS integration_to_workflow_pct,

    ROUND(
        100.0 * SUM(successful_workflow_run)
        / NULLIF(SUM(created_workflow), 0),
        2
    ) AS workflow_to_success_pct

FROM user_funnel;


-- ============================================================
-- 2. ACTIVATION KPI
-- Definition:
-- User completes at least one successful workflow run
-- within 7 days of signup
-- ============================================================

SELECT
    COUNT(DISTINCT u.user_id) AS total_signups,

    COUNT(DISTINCT CASE
        WHEN e.event_name = 'workflow_run_success'
         AND e.event_timestamp >= u.signup_timestamp
         AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
        THEN u.user_id
    END) AS activated_users,

    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN e.event_name = 'workflow_run_success'
             AND e.event_timestamp >= u.signup_timestamp
             AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            THEN u.user_id
        END)
        / COUNT(DISTINCT u.user_id),
        2
    ) AS activation_rate

FROM users u
LEFT JOIN events e
    ON u.user_id = e.user_id;


-- ============================================================
-- 3. USER-LEVEL PAID ACCOUNT BASELINE
-- Paid = account is currently Pro or Business
-- ============================================================

SELECT
    COUNT(DISTINCT u.user_id) AS total_signups,

    COUNT(DISTINCT CASE
        WHEN a.current_plan IN ('Pro', 'Business')
        THEN u.user_id
    END) AS users_on_paid_accounts,

    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN a.current_plan IN ('Pro', 'Business')
            THEN u.user_id
        END)
        / COUNT(DISTINCT u.user_id),
        2
    ) AS user_paid_account_pct

FROM users u
JOIN accounts a
    ON u.account_id = a.account_id;


-- ============================================================
-- 4. ACTIVATED USERS ON PAID ACCOUNTS
-- ============================================================

WITH activated_users AS (
    SELECT DISTINCT
        u.user_id,
        u.account_id

    FROM users u
    JOIN events e
        ON u.user_id = e.user_id

    WHERE e.event_name = 'workflow_run_success'
      AND e.event_timestamp >= u.signup_timestamp
      AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
)

SELECT
    COUNT(*) AS activated_users,

    COUNT(*) FILTER (
        WHERE a.current_plan IN ('Pro', 'Business')
    ) AS activated_users_on_paid_accounts,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE a.current_plan IN ('Pro', 'Business')
        )
        / COUNT(*),
        2
    ) AS activated_to_paid_pct

FROM activated_users au
JOIN accounts a
    ON au.account_id = a.account_id;


-- ============================================================
-- EXPECTED VALIDATION RESULTS
-- ============================================================

-- Strict sequential funnel:
-- Total Signups:                 5000
-- Workspace Created:             2400
-- Integration Connected:         1281
-- Workflow Created:               464
-- Successful Workflow Run:        326
--
-- Signup -> Workspace:           48.00%
-- Workspace -> Integration:      53.38%
-- Integration -> Workflow:       36.22%
-- Workflow -> Success:           70.26%
--
-- Activation KPI:
-- Activated Users:               2166
-- Activation Rate:               43.32%
--
-- User Paid Account Baseline:
-- Users on Paid Accounts:         442
-- User Paid Account Rate:         8.84%
--
-- Activated -> Paid Account:
-- Activated Users:               2166
-- Activated Users on Paid:        267
-- Activated-to-Paid Rate:        12.33%