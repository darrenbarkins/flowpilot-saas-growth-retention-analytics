-- ============================================================
-- FLOWPILOT COHORT RETENTION ANALYSIS
-- ============================================================

WITH meaningful_activity AS (
    SELECT
        u.user_id,
        DATE_TRUNC('month', u.signup_timestamp) AS signup_month,
        DATE_TRUNC('month', e.event_timestamp) AS activity_month

    FROM users u
    JOIN events e
        ON u.user_id = e.user_id

    WHERE e.event_name IN (
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

    AND e.event_timestamp >= u.signup_timestamp
),

cohort_activity AS (
    SELECT DISTINCT
        user_id,
        signup_month,
        activity_month,

        (
            EXTRACT(YEAR FROM activity_month)
            - EXTRACT(YEAR FROM signup_month)
        ) * 12
        +
        (
            EXTRACT(MONTH FROM activity_month)
            - EXTRACT(MONTH FROM signup_month)
        ) AS cohort_month

    FROM meaningful_activity
)

SELECT
    signup_month,
    cohort_month,
    COUNT(DISTINCT user_id) AS retained_users

FROM cohort_activity

WHERE cohort_month BETWEEN 0 AND 6

GROUP BY
    signup_month,
    cohort_month

ORDER BY
    signup_month,
    cohort_month;

-- ============================================================
-- MONTHLY COHORT RETENTION RATES
-- ============================================================

WITH user_cohorts AS (
    SELECT
        user_id,
        DATE_TRUNC('month', signup_timestamp) AS signup_month
    FROM users
),

cohort_sizes AS (
    SELECT
        signup_month,
        COUNT(*) AS cohort_size
    FROM user_cohorts
    GROUP BY signup_month
),

meaningful_activity AS (
    SELECT DISTINCT
        u.user_id,
        DATE_TRUNC('month', u.signup_timestamp) AS signup_month,
        DATE_TRUNC('month', e.event_timestamp) AS activity_month
    FROM users u
    JOIN events e
        ON u.user_id = e.user_id
    WHERE e.event_name IN (
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
      AND e.event_timestamp >= u.signup_timestamp
),

cohort_activity AS (
    SELECT
        user_id,
        signup_month,
        activity_month,

        (
            EXTRACT(YEAR FROM activity_month)
            - EXTRACT(YEAR FROM signup_month)
        ) * 12
        +
        (
            EXTRACT(MONTH FROM activity_month)
            - EXTRACT(MONTH FROM signup_month)
        ) AS cohort_month

    FROM meaningful_activity
),

retention_counts AS (
    SELECT
        signup_month,
        cohort_month,
        COUNT(DISTINCT user_id) AS retained_users
    FROM cohort_activity
    WHERE cohort_month BETWEEN 0 AND 6
    GROUP BY
        signup_month,
        cohort_month
)

SELECT
    rc.signup_month,
    cs.cohort_size,
    rc.cohort_month,
    rc.retained_users,

    ROUND(
        100.0 * rc.retained_users / cs.cohort_size,
        2
    ) AS retention_rate

FROM retention_counts rc
JOIN cohort_sizes cs
    ON rc.signup_month = cs.signup_month

ORDER BY
    rc.signup_month,
    rc.cohort_month;

-- ============================================================
-- COHORT RETENTION HEATMAP TABLE
-- ============================================================

WITH user_cohorts AS (
    SELECT
        user_id,
        DATE_TRUNC('month', signup_timestamp) AS signup_month
    FROM users
),

cohort_sizes AS (
    SELECT
        signup_month,
        COUNT(*) AS cohort_size
    FROM user_cohorts
    GROUP BY signup_month
),

meaningful_activity AS (
    SELECT DISTINCT
        u.user_id,
        DATE_TRUNC('month', u.signup_timestamp) AS signup_month,
        DATE_TRUNC('month', e.event_timestamp) AS activity_month
    FROM users u
    JOIN events e
        ON u.user_id = e.user_id
    WHERE e.event_name IN (
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
      AND e.event_timestamp >= u.signup_timestamp
),

cohort_activity AS (
    SELECT
        user_id,
        signup_month,

        (
            EXTRACT(YEAR FROM activity_month)
            - EXTRACT(YEAR FROM signup_month)
        ) * 12
        +
        (
            EXTRACT(MONTH FROM activity_month)
            - EXTRACT(MONTH FROM signup_month)
        ) AS cohort_month

    FROM meaningful_activity
),

retention_rates AS (
    SELECT
        ca.signup_month,
        ca.cohort_month,

        ROUND(
            100.0 * COUNT(DISTINCT ca.user_id)
            / cs.cohort_size,
            2
        ) AS retention_rate

    FROM cohort_activity ca
    JOIN cohort_sizes cs
        ON ca.signup_month = cs.signup_month

    WHERE ca.cohort_month BETWEEN 0 AND 6

    GROUP BY
        ca.signup_month,
        ca.cohort_month,
        cs.cohort_size
)

SELECT
    cs.signup_month,
    cs.cohort_size,

    MAX(CASE WHEN rr.cohort_month = 0
        THEN rr.retention_rate END) AS month_0,

    MAX(CASE WHEN rr.cohort_month = 1
        THEN rr.retention_rate END) AS month_1,

    MAX(CASE WHEN rr.cohort_month = 2
        THEN rr.retention_rate END) AS month_2,

    MAX(CASE WHEN rr.cohort_month = 3
        THEN rr.retention_rate END) AS month_3,

    MAX(CASE WHEN rr.cohort_month = 4
        THEN rr.retention_rate END) AS month_4,

    MAX(CASE WHEN rr.cohort_month = 5
        THEN rr.retention_rate END) AS month_5,

    MAX(CASE WHEN rr.cohort_month = 6
        THEN rr.retention_rate END) AS month_6

FROM cohort_sizes cs
LEFT JOIN retention_rates rr
    ON cs.signup_month = rr.signup_month

GROUP BY
    cs.signup_month,
    cs.cohort_size

ORDER BY cs.signup_month;
