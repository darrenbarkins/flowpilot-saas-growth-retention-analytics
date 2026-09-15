-- ============================================================
-- FLOWPILOT RETENTION ANALYSIS
-- ============================================================

-- Meaningful activity includes:
-- workflow_created
-- workflow_run_success
-- workflow_edited
-- integration_connected
-- ai_action_used
-- workflow_shared
-- scheduled_automation_created
-- scheduled_automation_run
-- dashboard_viewed


WITH user_retention AS (
    SELECT
        u.user_id,
        u.signup_timestamp,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                AND e.event_timestamp >= u.signup_timestamp + INTERVAL '7 days'
                AND e.event_timestamp <  u.signup_timestamp + INTERVAL '14 days'
                THEN 1
                ELSE 0
            END
        ) AS retained_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                AND e.event_timestamp <  u.signup_timestamp + INTERVAL '37 days'
                THEN 1
                ELSE 0
            END
        ) AS retained_30d

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY
        u.user_id,
        u.signup_timestamp
)

SELECT
    COUNT(*) AS total_users,

    SUM(retained_7d) AS retained_7d_users,

    ROUND(
        100.0 * SUM(retained_7d) / COUNT(*),
        2
    ) AS retention_7d_rate,

    SUM(retained_30d) AS retained_30d_users,

    ROUND(
        100.0 * SUM(retained_30d) / COUNT(*),
        2
    ) AS retention_30d_rate

FROM user_retention;

WITH user_metrics AS (
    SELECT
        u.user_id,

        MAX(
            CASE
                WHEN e.event_name = 'workflow_run_success'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS activated,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                AND e.event_timestamp >= u.signup_timestamp + INTERVAL '7 days'
                AND e.event_timestamp < u.signup_timestamp + INTERVAL '14 days'
                THEN 1
                ELSE 0
            END
        ) AS retained_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                THEN 1
                ELSE 0
            END
        ) AS retained_30d

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY u.user_id
)

SELECT
    activated,
    COUNT(*) AS total_users,

    SUM(retained_7d) AS retained_7d_users,

    ROUND(
        100.0 * SUM(retained_7d) / COUNT(*),
        2
    ) AS retention_7d_rate,

    SUM(retained_30d) AS retained_30d_users,

    ROUND(
        100.0 * SUM(retained_30d) / COUNT(*),
        2
    ) AS retention_30d_rate

FROM user_metrics
GROUP BY activated
ORDER BY activated DESC;

WITH user_retention AS (
    SELECT
        u.user_id,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                AND e.event_timestamp >= u.signup_timestamp + INTERVAL '7 days'
                AND e.event_timestamp < u.signup_timestamp + INTERVAL '14 days'
                THEN 1
                ELSE 0
            END
        ) AS retained_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                THEN 1
                ELSE 0
            END
        ) AS retained_30d

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY u.user_id
)

SELECT
    a.channel,
    COUNT(*) AS total_users,

    SUM(ur.retained_7d) AS retained_7d_users,

    ROUND(
        100.0 * SUM(ur.retained_7d) / COUNT(*),
        2
    ) AS retention_7d_rate,

    SUM(ur.retained_30d) AS retained_30d_users,

    ROUND(
        100.0 * SUM(ur.retained_30d) / COUNT(*),
        2
    ) AS retention_30d_rate

FROM user_retention ur
JOIN acquisition a
    ON ur.user_id = a.user_id

GROUP BY a.channel
ORDER BY retention_30d_rate DESC;

WITH user_behavior AS (
    SELECT
        u.user_id,

        MAX(
            CASE
                WHEN e.event_name = 'scheduled_automation_created'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS scheduled_automation_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                AND e.event_timestamp >= u.signup_timestamp + INTERVAL '7 days'
                AND e.event_timestamp < u.signup_timestamp + INTERVAL '14 days'
                THEN 1
                ELSE 0
            END
        ) AS retained_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                THEN 1
                ELSE 0
            END
        ) AS retained_30d

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY u.user_id
)

SELECT
    scheduled_automation_7d,
    COUNT(*) AS total_users,

    SUM(retained_7d) AS retained_7d_users,

    ROUND(
        100.0 * SUM(retained_7d) / COUNT(*),
        2
    ) AS retention_7d_rate,

    SUM(retained_30d) AS retained_30d_users,

    ROUND(
        100.0 * SUM(retained_30d) / COUNT(*),
        2
    ) AS retention_30d_rate

FROM user_behavior
GROUP BY scheduled_automation_7d
ORDER BY scheduled_automation_7d DESC;

WITH user_behavior AS (
    SELECT
        u.user_id,

        MAX(
            CASE
                WHEN e.event_name = 'user_invited'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS invited_user_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                AND e.event_timestamp >= u.signup_timestamp + INTERVAL '7 days'
                AND e.event_timestamp < u.signup_timestamp + INTERVAL '14 days'
                THEN 1
                ELSE 0
            END
        ) AS retained_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                THEN 1
                ELSE 0
            END
        ) AS retained_30d

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY u.user_id
)

SELECT
    invited_user_7d,
    COUNT(*) AS total_users,

    SUM(retained_7d) AS retained_7d_users,

    ROUND(
        100.0 * SUM(retained_7d) / COUNT(*),
        2
    ) AS retention_7d_rate,

    SUM(retained_30d) AS retained_30d_users,

    ROUND(
        100.0 * SUM(retained_30d) / COUNT(*),
        2
    ) AS retention_30d_rate

FROM user_behavior
GROUP BY invited_user_7d
ORDER BY invited_user_7d DESC;

WITH user_behavior AS (
    SELECT
        u.user_id,

        MAX(
            CASE
                WHEN e.event_name = 'workflow_shared'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS shared_workflow_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                AND e.event_timestamp >= u.signup_timestamp + INTERVAL '7 days'
                AND e.event_timestamp < u.signup_timestamp + INTERVAL '14 days'
                THEN 1
                ELSE 0
            END
        ) AS retained_7d,

        MAX(
            CASE
                WHEN e.event_name IN (
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
                THEN 1
                ELSE 0
            END
        ) AS retained_30d

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY u.user_id
)

SELECT
    shared_workflow_7d,
    COUNT(*) AS total_users,

    SUM(retained_7d) AS retained_7d_users,

    ROUND(
        100.0 * SUM(retained_7d) / COUNT(*),
        2
    ) AS retention_7d_rate,

    SUM(retained_30d) AS retained_30d_users,

    ROUND(
        100.0 * SUM(retained_30d) / COUNT(*),
        2
    ) AS retention_30d_rate

FROM user_behavior
GROUP BY shared_workflow_7d
ORDER BY shared_workflow_7d DESC;
