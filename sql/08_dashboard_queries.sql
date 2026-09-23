-- ============================================================
-- FlowPilot SaaS Product Growth & Retention Analytics
-- 08_dashboard_queries.sql
--
-- Purpose:
-- Create clean, dashboard-ready datasets for Power BI.
--
-- Dashboard Sections:
--   1. Executive KPIs
--   2. Monthly Trends
--   3. Acquisition
--   4. Product Funnel
--   5. Cohort Retention
--   6. Feature Adoption
--   7. Churn
--   8. Revenue
--   9. Experiment Results
-- ============================================================


-- ------------------------------------------------------------
-- 1. Executive KPI Summary
-- ------------------------------------------------------------

WITH activation AS (
    SELECT
        u.user_id,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name = 'workflow_run_success'
                  AND e.event_timestamp >= u.signup_timestamp
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            )
            THEN 1
            ELSE 0
        END AS activated
    FROM users u
),

retention_30d AS (
    SELECT
        u.user_id,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name IN (
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
                  AND e.event_timestamp >= u.signup_timestamp + INTERVAL '30 days'
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '37 days'
            )
            THEN 1
            ELSE 0
        END AS retained_30d
    FROM users u
),

subscription_summary AS (
    SELECT
        COUNT(*) AS total_subscriptions,
        COUNT(*) FILTER (
            WHERE status = 'Cancelled'
        ) AS cancelled_subscriptions,
        COUNT(*) FILTER (
            WHERE status = 'Active'
        ) AS active_subscriptions,
        SUM(monthly_equivalent_price) FILTER (
            WHERE status = 'Active'
        ) AS current_mrr
    FROM subscriptions
),

account_summary AS (
    SELECT
        COUNT(DISTINCT a.account_id) AS total_accounts,
        COUNT(DISTINCT s.account_id) FILTER (
            WHERE s.status = 'Active'
        ) AS paid_accounts
    FROM accounts a
    LEFT JOIN subscriptions s
        ON a.account_id = s.account_id
)

SELECT
    'Activation Rate' AS metric,
    ROUND(
        100.0 * SUM(activated) / COUNT(*),
        2
    ) AS value,
    '%' AS unit
FROM activation

UNION ALL

SELECT
    '30-Day Retention',
    ROUND(
        100.0 * SUM(retained_30d) / COUNT(*),
        2
    ),
    '%'
FROM retention_30d

UNION ALL

SELECT
    'Subscription Churn Rate',
    ROUND(
        100.0 * cancelled_subscriptions / total_subscriptions,
        2
    ),
    '%'
FROM subscription_summary

UNION ALL

SELECT
    'Current MRR',
    ROUND(current_mrr, 2),
    '$'
FROM subscription_summary

UNION ALL

SELECT
    'ARPA',
    ROUND(
        current_mrr / active_subscriptions,
        2
    ),
    '$'
FROM subscription_summary

UNION ALL

SELECT
    'Current Paid Account Rate',
    ROUND(
        100.0 * paid_accounts / total_accounts,
        2
    ),
    '%'
FROM account_summary;

-- ------------------------------------------------------------
-- 2. Monthly KPI Trends
-- ------------------------------------------------------------

WITH user_metrics AS (
    SELECT
        u.user_id,
        DATE_TRUNC('month', u.signup_timestamp)::date AS signup_month,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name = 'workflow_run_success'
                  AND e.event_timestamp >= u.signup_timestamp
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            )
            THEN 1
            ELSE 0
        END AS activated,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name IN (
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
                  AND e.event_timestamp >= u.signup_timestamp + INTERVAL '30 days'
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '37 days'
            )
            THEN 1
            ELSE 0
        END AS retained_30d

    FROM users u
)

SELECT
    signup_month,
    COUNT(*) AS signups,
    SUM(activated) AS activated_users,

    ROUND(
        1.0 * SUM(activated) / COUNT(*),
        4
    ) AS activation_rate,

    SUM(retained_30d) AS retained_30d_users,

    ROUND(
        1.0 * SUM(retained_30d) / COUNT(*),
        4
    ) AS retention_30d_rate

FROM user_metrics

GROUP BY signup_month
ORDER BY signup_month;
-- ------------------------------------------------------------
-- 3. Acquisition Performance
-- ------------------------------------------------------------

WITH user_metrics AS (
    SELECT
        u.user_id,
        u.account_id,
        a.channel,
        u.signup_timestamp,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name = 'workflow_run_success'
                  AND e.event_timestamp >= u.signup_timestamp
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            )
            THEN 1
            ELSE 0
        END AS activated,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name IN (
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
                  AND e.event_timestamp >= u.signup_timestamp + INTERVAL '30 days'
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '37 days'
            )
            THEN 1
            ELSE 0
        END AS retained_30d

    FROM users u
    JOIN acquisition a
        ON u.user_id = a.user_id
),

account_channel AS (
    SELECT
        account_id,
        channel
    FROM (
        SELECT
            u.account_id,
            a.channel,
            u.signup_timestamp,
            ROW_NUMBER() OVER (
                PARTITION BY u.account_id
                ORDER BY u.signup_timestamp
            ) AS rn
        FROM users u
        JOIN acquisition a
            ON u.user_id = a.user_id
    ) x
    WHERE rn = 1
),

active_revenue AS (
    SELECT
        ac.channel,
        COUNT(DISTINCT s.account_id) AS active_paid_accounts,
        SUM(s.monthly_equivalent_price) AS current_mrr
    FROM subscriptions s
    JOIN account_channel ac
        ON s.account_id = ac.account_id
    WHERE s.status = 'Active'
    GROUP BY ac.channel
),

user_summary AS (
    SELECT
        channel,
        COUNT(*) AS signups,
        SUM(activated) AS activated_users,
        ROUND(
            100.0 * SUM(activated) / COUNT(*),
            2
        ) AS activation_rate,
        SUM(retained_30d) AS retained_30d_users,
        ROUND(
            100.0 * SUM(retained_30d) / COUNT(*),
            2
        ) AS retention_30d_rate
    FROM user_metrics
    GROUP BY channel
)

SELECT
    us.channel,
    us.signups,
    us.activated_users,
    us.activation_rate,
    us.retained_30d_users,
    us.retention_30d_rate,
    COALESCE(ar.active_paid_accounts, 0) AS active_paid_accounts,
    COALESCE(ar.current_mrr, 0) AS current_mrr

FROM user_summary us
LEFT JOIN active_revenue ar
    ON us.channel = ar.channel

ORDER BY us.signups DESC;

-- ------------------------------------------------------------
-- 4. Product Funnel
-- ------------------------------------------------------------

WITH funnel_users AS (
    SELECT
        u.user_id,
        u.signup_timestamp,

        MIN(e.event_timestamp) FILTER (
            WHERE e.event_name = 'workspace_created'
              AND e.event_timestamp >= u.signup_timestamp
        ) AS workspace_created_at,

        MIN(e.event_timestamp) FILTER (
            WHERE e.event_name = 'integration_connected'
              AND e.event_timestamp >= u.signup_timestamp
        ) AS integration_connected_at,

        MIN(e.event_timestamp) FILTER (
            WHERE e.event_name = 'workflow_created'
              AND e.event_timestamp >= u.signup_timestamp
        ) AS workflow_created_at,

        MIN(e.event_timestamp) FILTER (
            WHERE e.event_name = 'workflow_run_success'
              AND e.event_timestamp >= u.signup_timestamp
        ) AS workflow_run_success_at

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id
    GROUP BY
        u.user_id,
        u.signup_timestamp
),

sequential_funnel AS (
    SELECT
        user_id,

        1 AS signup,

        CASE
            WHEN workspace_created_at IS NOT NULL
            THEN 1 ELSE 0
        END AS workspace_created,

        CASE
            WHEN workspace_created_at IS NOT NULL
             AND integration_connected_at >= workspace_created_at
            THEN 1 ELSE 0
        END AS integration_connected,

        CASE
            WHEN workspace_created_at IS NOT NULL
             AND integration_connected_at >= workspace_created_at
             AND workflow_created_at >= integration_connected_at
            THEN 1 ELSE 0
        END AS workflow_created,

        CASE
            WHEN workspace_created_at IS NOT NULL
             AND integration_connected_at >= workspace_created_at
             AND workflow_created_at >= integration_connected_at
             AND workflow_run_success_at >= workflow_created_at
            THEN 1 ELSE 0
        END AS workflow_run_success

    FROM funnel_users
),

stage_counts AS (
    SELECT
        SUM(signup) AS signup_users,
        SUM(workspace_created) AS workspace_users,
        SUM(integration_connected) AS integration_users,
        SUM(workflow_created) AS workflow_users,
        SUM(workflow_run_success) AS successful_run_users
    FROM sequential_funnel
)

SELECT
    1 AS stage_order,
    'Signup' AS stage,
    signup_users AS users
FROM stage_counts

UNION ALL

SELECT
    2,
    'Workspace Created',
    workspace_users
FROM stage_counts

UNION ALL

SELECT
    3,
    'Integration Connected',
    integration_users
FROM stage_counts

UNION ALL

SELECT
    4,
    'Workflow Created',
    workflow_users
FROM stage_counts

UNION ALL

SELECT
    5,
    'Successful Workflow Run',
    successful_run_users
FROM stage_counts

ORDER BY stage_order;

-- ------------------------------------------------------------
-- 5. Cohort Retention Heatmap
-- ------------------------------------------------------------

WITH meaningful_activity AS (
    SELECT
        u.user_id,
        DATE_TRUNC('month', u.signup_timestamp)::date AS signup_month,
        DATE_TRUNC('month', e.event_timestamp)::date AS activity_month
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
),

cohort_activity AS (
    SELECT DISTINCT
        user_id,
        signup_month,
        activity_month,
        (
            EXTRACT(YEAR FROM AGE(activity_month, signup_month)) * 12
            + EXTRACT(MONTH FROM AGE(activity_month, signup_month))
        )::int AS cohort_month
    FROM meaningful_activity
    WHERE activity_month >= signup_month
),

cohort_sizes AS (
    SELECT
        DATE_TRUNC('month', signup_timestamp)::date AS signup_month,
        COUNT(*) AS cohort_size
    FROM users
    GROUP BY 1
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
),

retention_rates AS (
    SELECT
        rc.signup_month,
        cs.cohort_size,
        rc.cohort_month,
        ROUND(
            100.0 * rc.retained_users / cs.cohort_size,
            2
        ) AS retention_rate
    FROM retention_counts rc
    JOIN cohort_sizes cs
        ON rc.signup_month = cs.signup_month
)

SELECT
    signup_month,
    cohort_size,

    MAX(retention_rate) FILTER (
        WHERE cohort_month = 0
    ) AS month_0,

    MAX(retention_rate) FILTER (
        WHERE cohort_month = 1
    ) AS month_1,

    MAX(retention_rate) FILTER (
        WHERE cohort_month = 2
    ) AS month_2,

    MAX(retention_rate) FILTER (
        WHERE cohort_month = 3
    ) AS month_3,

    MAX(retention_rate) FILTER (
        WHERE cohort_month = 4
    ) AS month_4,

    MAX(retention_rate) FILTER (
        WHERE cohort_month = 5
    ) AS month_5,

    MAX(retention_rate) FILTER (
        WHERE cohort_month = 6
    ) AS month_6

FROM retention_rates

GROUP BY
    signup_month,
    cohort_size

ORDER BY signup_month;

-- ------------------------------------------------------------
-- 6. Feature Adoption & 30-Day Retention
-- ------------------------------------------------------------

WITH user_features AS (
    SELECT
        u.user_id,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name = 'integration_connected'
                  AND e.event_timestamp >= u.signup_timestamp
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            )
            THEN 1 ELSE 0
        END AS used_integration,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name = 'template_used'
                  AND e.event_timestamp >= u.signup_timestamp
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            )
            THEN 1 ELSE 0
        END AS used_template,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name = 'scheduled_automation_created'
                  AND e.event_timestamp >= u.signup_timestamp
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            )
            THEN 1 ELSE 0
        END AS used_scheduled_automation,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name = 'user_invited'
                  AND e.event_timestamp >= u.signup_timestamp
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            )
            THEN 1 ELSE 0
        END AS invited_teammate,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name = 'workflow_shared'
                  AND e.event_timestamp >= u.signup_timestamp
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
            )
            THEN 1 ELSE 0
        END AS shared_workflow,

        CASE
            WHEN EXISTS (
                SELECT 1
                FROM events e
                WHERE e.user_id = u.user_id
                  AND e.event_name IN (
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
                  AND e.event_timestamp >= u.signup_timestamp + INTERVAL '30 days'
                  AND e.event_timestamp < u.signup_timestamp + INTERVAL '37 days'
            )
            THEN 1 ELSE 0
        END AS retained_30d

    FROM users u
),

feature_rows AS (
    SELECT
        'Integration Connected' AS feature,
        used_integration AS adopted,
        retained_30d
    FROM user_features

    UNION ALL

    SELECT
        'Template Used',
        used_template,
        retained_30d
    FROM user_features

    UNION ALL

    SELECT
        'Scheduled Automation',
        used_scheduled_automation,
        retained_30d
    FROM user_features

    UNION ALL

    SELECT
        'Teammate Invited',
        invited_teammate,
        retained_30d
    FROM user_features

    UNION ALL

    SELECT
        'Workflow Shared',
        shared_workflow,
        retained_30d
    FROM user_features
)

SELECT
    feature,
    CASE
        WHEN adopted = 1 THEN 'Adopted'
        ELSE 'Not Adopted'
    END AS adoption_status,
    COUNT(*) AS users,
    SUM(retained_30d) AS retained_30d_users,
    ROUND(
        100.0 * SUM(retained_30d) / COUNT(*),
        2
    ) AS retention_30d_rate
FROM feature_rows
GROUP BY
    feature,
    adopted
ORDER BY
    feature,
    adopted DESC;

-- ------------------------------------------------------------
-- 7. Churn Summary
-- ------------------------------------------------------------

WITH churn_by_plan AS (
    SELECT
        plan_name,
        COUNT(*) AS subscriptions,
        COUNT(*) FILTER (
            WHERE status = 'Cancelled'
        ) AS cancelled_subscriptions,
        ROUND(
            100.0
            * COUNT(*) FILTER (WHERE status = 'Cancelled')
            / COUNT(*),
            2
        ) AS churn_rate
    FROM subscriptions
    GROUP BY plan_name
),

cancellation_reasons AS (
    SELECT
        cancellation_reason,
        COUNT(*) AS cancellations,
        ROUND(
            100.0
            * COUNT(*)
            / SUM(COUNT(*)) OVER (),
            2
        ) AS cancellation_share
    FROM subscriptions
    WHERE status = 'Cancelled'
      AND cancellation_reason IS NOT NULL
    GROUP BY cancellation_reason
)

SELECT
    'Plan' AS churn_type,
    plan_name AS category,
    subscriptions AS total_records,
    cancelled_subscriptions AS churned_records,
    churn_rate AS metric_value
FROM churn_by_plan

UNION ALL

SELECT
    'Cancellation Reason',
    cancellation_reason,
    NULL,
    cancellations,
    cancellation_share
FROM cancellation_reasons

ORDER BY
    churn_type,
    metric_value DESC;

-- ------------------------------------------------------------
-- 8. Revenue Summary
-- ------------------------------------------------------------

WITH current_revenue_by_plan AS (
    SELECT
        plan_name,
        COUNT(*) AS active_subscriptions,
        SUM(monthly_equivalent_price) AS current_mrr,
        ROUND(
            AVG(monthly_equivalent_price),
            2
        ) AS avg_mrr_per_subscription
    FROM subscriptions
    WHERE status = 'Active'
    GROUP BY plan_name
),

account_size_revenue AS (
    SELECT
        a.employee_band,
        COUNT(DISTINCT s.account_id) AS active_accounts,
        SUM(s.monthly_equivalent_price) AS current_mrr,
        ROUND(
            SUM(s.monthly_equivalent_price)
            / COUNT(DISTINCT s.account_id),
            2
        ) AS avg_mrr_per_account
    FROM subscriptions s
    JOIN accounts a
        ON s.account_id = a.account_id
    WHERE s.status = 'Active'
    GROUP BY a.employee_band
)

SELECT
    'Plan' AS revenue_type,
    plan_name AS category,
    active_subscriptions AS active_records,
    current_mrr,
    avg_mrr_per_subscription AS avg_mrr
FROM current_revenue_by_plan

UNION ALL

SELECT
    'Company Size',
    employee_band,
    active_accounts,
    current_mrr,
    avg_mrr_per_account
FROM account_size_revenue

ORDER BY
    revenue_type,
    current_mrr DESC;

-- ------------------------------------------------------------
-- 9. Experiment Results
-- ------------------------------------------------------------

SELECT *
FROM (
    VALUES
        (
            'Activation',
            35.62::numeric,
            36.82::numeric,
            1.21::numeric,
            0.7606::numeric,
            'Not Significant'
        ),
        (
            '7-Day Retention',
            38.70::numeric,
            43.92::numeric,
            5.22::numeric,
            0.1987::numeric,
            'Not Significant'
        ),
        (
            '30-Day Retention',
            26.03::numeric,
            26.69::numeric,
            0.66::numeric,
            0.8555::numeric,
            'Not Significant'
        ),
        (
            'Integration Connection',
            52.40::numeric,
            48.31::numeric,
            -4.09::numeric,
            0.3217::numeric,
            'Not Significant'
        ),
        (
            'Template Adoption',
            28.08::numeric,
            25.00::numeric,
            -3.08::numeric,
            0.3973::numeric,
            'Not Significant'
        ),
        (
            'Paid Conversion',
            11.30::numeric,
            12.50::numeric,
            1.20::numeric,
            0.6536::numeric,
            'Not Significant'
        ),
        (
            'Support Ticket Rate',
            0.34::numeric,
            0.00::numeric,
            -0.34::numeric,
            0.3136::numeric,
            'Not Significant'
        ),
        (
            'Cancellation Rate',
            1.71::numeric,
            1.69::numeric,
            -0.02::numeric,
            0.9827::numeric,
            'Not Significant'
        )
) AS experiment_results (
    metric,
    control_rate,
    treatment_rate,
    absolute_lift_pp,
    p_value,
    significance
);