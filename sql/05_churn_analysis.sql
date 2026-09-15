-- ============================================================
-- FLOWPILOT CHURN ANALYSIS
-- ============================================================

SELECT
    COUNT(*) AS total_subscriptions,

    COUNT(*) FILTER (
        WHERE status = 'Cancelled'
    ) AS cancelled_subscriptions,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE status = 'Cancelled'
        ) / COUNT(*),
        2
    ) AS churn_rate

FROM subscriptions;

SELECT
    plan_name,
    COUNT(*) AS total_subscriptions,

    COUNT(*) FILTER (
        WHERE status = 'Cancelled'
    ) AS cancelled_subscriptions,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE status = 'Cancelled'
        ) / COUNT(*),
        2
    ) AS churn_rate

FROM subscriptions
GROUP BY plan_name
ORDER BY churn_rate DESC;

WITH user_activation AS (
    SELECT
        u.user_id,
        u.account_id,

        MAX(
            CASE
                WHEN e.event_name = 'workflow_run_success'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS activated

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY
        u.user_id,
        u.account_id
),

paid_accounts AS (
    SELECT
        s.account_id,
        MAX(
            CASE
                WHEN s.status = 'Cancelled' THEN 1
                ELSE 0
            END
        ) AS churned
    FROM subscriptions s
    GROUP BY s.account_id
)

SELECT
    ua.activated,
    COUNT(DISTINCT ua.account_id) AS paid_accounts,

    COUNT(DISTINCT CASE
        WHEN pa.churned = 1
        THEN ua.account_id
    END) AS churned_accounts,

    ROUND(
        100.0 * COUNT(DISTINCT CASE
            WHEN pa.churned = 1
            THEN ua.account_id
        END)
        / COUNT(DISTINCT ua.account_id),
        2
    ) AS churn_rate

FROM user_activation ua
JOIN paid_accounts pa
    ON ua.account_id = pa.account_id

GROUP BY ua.activated
ORDER BY ua.activated DESC;

SELECT
    cancellation_reason,
    COUNT(*) AS cancelled_subscriptions,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS cancellation_share_pct

FROM subscriptions

WHERE status = 'Cancelled'

GROUP BY cancellation_reason
ORDER BY cancelled_subscriptions DESC;

SELECT
    plan_name,

    ROUND(
        AVG(
            cancellation_date - subscription_start_date
        )::numeric,
        1
    ) AS avg_days_to_churn,

    ROUND(
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY cancellation_date - subscription_start_date
        )::numeric,
        1
    ) AS median_days_to_churn,

    COUNT(*) AS cancelled_subscriptions

FROM subscriptions

WHERE status = 'Cancelled'
  AND cancellation_date IS NOT NULL
  AND subscription_start_date IS NOT NULL

GROUP BY plan_name
ORDER BY avg_days_to_churn;

WITH account_acquisition AS (
    SELECT
        u.account_id,
        a.channel,
        ROW_NUMBER() OVER (
            PARTITION BY u.account_id
            ORDER BY a.acquisition_timestamp
        ) AS rn
    FROM users u
    JOIN acquisition a
        ON u.user_id = a.user_id
),

account_channel AS (
    SELECT
        account_id,
        channel
    FROM account_acquisition
    WHERE rn = 1
)

SELECT
    ac.channel,

    COUNT(*) AS total_subscriptions,

    COUNT(*) FILTER (
        WHERE s.status = 'Cancelled'
    ) AS cancelled_subscriptions,

    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE s.status = 'Cancelled'
        ) / COUNT(*),
        2
    ) AS churn_rate

FROM subscriptions s
JOIN account_channel ac
    ON s.account_id = ac.account_id

GROUP BY ac.channel
ORDER BY churn_rate DESC;