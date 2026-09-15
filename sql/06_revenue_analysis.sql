-- ============================================================
-- FLOWPILOT REVENUE ANALYSIS
-- ============================================================

-- Current MRR by active subscription plan

SELECT
    plan_name,

    COUNT(*) AS active_subscriptions,

    ROUND(
        SUM(monthly_equivalent_price),
        2
    ) AS monthly_recurring_revenue,

    ROUND(
        AVG(monthly_equivalent_price),
        2
    ) AS avg_mrr_per_subscription

FROM subscriptions

WHERE status = 'Active'

GROUP BY plan_name
ORDER BY monthly_recurring_revenue DESC;

-- ============================================================
-- TOTAL CURRENT MRR + ARPA
-- ============================================================

SELECT
    COUNT(*) AS active_subscriptions,

    ROUND(
        SUM(monthly_equivalent_price),
        2
    ) AS total_mrr,

    ROUND(
        AVG(monthly_equivalent_price),
        2
    ) AS arpa

FROM subscriptions
WHERE status = 'Active';

-- ============================================================
-- MRR OVER TIME
-- Capped at the last observed subscription month
-- ============================================================

WITH date_bounds AS (
    SELECT
        DATE_TRUNC('month', MIN(subscription_start_date)) AS min_month,
        DATE_TRUNC(
            'month',
            MAX(
                COALESCE(
                    subscription_end_date,
                    subscription_start_date
                )
            )
        ) AS max_month
    FROM subscriptions
),

months AS (
    SELECT
        GENERATE_SERIES(
            min_month,
            max_month,
            INTERVAL '1 month'
        ) AS month_start
    FROM date_bounds
)

SELECT
    m.month_start,

    ROUND(
        SUM(
            CASE
                WHEN s.subscription_start_date < m.month_start + INTERVAL '1 month'
                 AND (
                        s.subscription_end_date IS NULL
                        OR s.subscription_end_date >= m.month_start
                     )
                THEN s.monthly_equivalent_price
                ELSE 0
            END
        ),
        2
    ) AS mrr

FROM months m
CROSS JOIN subscriptions s

GROUP BY m.month_start
ORDER BY m.month_start;

-- ============================================================
-- MONTH-OVER-MONTH MRR GROWTH
-- ============================================================

WITH date_bounds AS (
    SELECT
        DATE_TRUNC('month', MIN(subscription_start_date)) AS min_month,
        DATE_TRUNC(
            'month',
            MAX(
                COALESCE(
                    subscription_end_date,
                    subscription_start_date
                )
            )
        ) AS max_month
    FROM subscriptions
),

months AS (
    SELECT
        GENERATE_SERIES(
            min_month,
            max_month,
            INTERVAL '1 month'
        ) AS month_start
    FROM date_bounds
),

monthly_mrr AS (
    SELECT
        m.month_start,

        SUM(
            CASE
                WHEN s.subscription_start_date < m.month_start + INTERVAL '1 month'
                 AND (
                        s.subscription_end_date IS NULL
                        OR s.subscription_end_date >= m.month_start
                     )
                THEN s.monthly_equivalent_price
                ELSE 0
            END
        ) AS mrr

    FROM months m
    CROSS JOIN subscriptions s

    GROUP BY m.month_start
),

mrr_with_previous AS (
    SELECT
        month_start,
        mrr,
        LAG(mrr) OVER (
            ORDER BY month_start
        ) AS previous_month_mrr

    FROM monthly_mrr
)

SELECT
    month_start,

    ROUND(
        mrr,
        2
    ) AS mrr,

    ROUND(
        previous_month_mrr,
        2
    ) AS previous_month_mrr,

    ROUND(
        100.0 * (mrr - previous_month_mrr)
        / NULLIF(previous_month_mrr, 0),
        2
    ) AS mom_mrr_growth_pct

FROM mrr_with_previous
ORDER BY month_start;

-- ============================================================
-- MRR BY PLAN OVER TIME
-- ============================================================

WITH date_bounds AS (
    SELECT
        DATE_TRUNC('month', MIN(subscription_start_date)) AS min_month,
        DATE_TRUNC(
            'month',
            MAX(
                COALESCE(
                    subscription_end_date,
                    subscription_start_date
                )
            )
        ) AS max_month
    FROM subscriptions
),

months AS (
    SELECT
        GENERATE_SERIES(
            min_month,
            max_month,
            INTERVAL '1 month'
        ) AS month_start
    FROM date_bounds
),

monthly_plan_mrr AS (
    SELECT
        m.month_start,
        s.plan_name,

        SUM(
            CASE
                WHEN s.subscription_start_date < m.month_start + INTERVAL '1 month'
                 AND (
                        s.subscription_end_date IS NULL
                        OR s.subscription_end_date >= m.month_start
                     )
                THEN s.monthly_equivalent_price
                ELSE 0
            END
        ) AS mrr

    FROM months m
    CROSS JOIN subscriptions s

    GROUP BY
        m.month_start,
        s.plan_name
)

SELECT
    month_start,

    ROUND(
        SUM(CASE
            WHEN plan_name = 'Pro'
            THEN mrr
            ELSE 0
        END),
        2
    ) AS pro_mrr,

    ROUND(
        SUM(CASE
            WHEN plan_name = 'Business'
            THEN mrr
            ELSE 0
        END),
        2
    ) AS business_mrr,

    ROUND(
        SUM(mrr),
        2
    ) AS total_mrr

FROM monthly_plan_mrr

GROUP BY month_start
ORDER BY month_start;

-- ============================================================
-- CURRENT MRR BY ACCOUNT SIZE
-- ============================================================

SELECT
    a.employee_band,

    COUNT(*) AS active_subscriptions,

    ROUND(
        SUM(s.monthly_equivalent_price),
        2
    ) AS total_mrr,

    ROUND(
        AVG(s.monthly_equivalent_price),
        2
    ) AS avg_mrr_per_account,

    ROUND(
        100.0 * SUM(s.monthly_equivalent_price)
        / SUM(SUM(s.monthly_equivalent_price)) OVER (),
        2
    ) AS mrr_share_pct

FROM subscriptions s
JOIN accounts a
    ON s.account_id = a.account_id

WHERE s.status = 'Active'

GROUP BY a.employee_band
ORDER BY total_mrr DESC;

-- ============================================================
-- CURRENT MRR BY ACQUISITION CHANNEL
-- ============================================================

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

    COUNT(*) AS active_subscriptions,

    ROUND(
        SUM(s.monthly_equivalent_price),
        2
    ) AS total_mrr,

    ROUND(
        AVG(s.monthly_equivalent_price),
        2
    ) AS avg_mrr_per_account,

    ROUND(
        100.0 * SUM(s.monthly_equivalent_price)
        / SUM(SUM(s.monthly_equivalent_price)) OVER (),
        2
    ) AS mrr_share_pct

FROM subscriptions s
JOIN account_channel ac
    ON s.account_id = ac.account_id

WHERE s.status = 'Active'

GROUP BY ac.channel
ORDER BY total_mrr DESC;
