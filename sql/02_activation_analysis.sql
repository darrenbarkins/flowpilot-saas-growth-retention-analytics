WITH user_activation AS (
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
        ) AS activated

    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id

    GROUP BY u.user_id
)

SELECT
    a.channel,
    COUNT(*) AS total_users,
    SUM(ua.activated) AS activated_users,

    ROUND(
        100.0 * SUM(ua.activated) / COUNT(*),
        2
    ) AS activation_rate

FROM user_activation ua
JOIN acquisition a
    ON ua.user_id = a.user_id

GROUP BY a.channel
ORDER BY activation_rate DESC;

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
)

SELECT
    a.employee_band,
    COUNT(*) AS total_users,
    SUM(ua.activated) AS activated_users,

    ROUND(
        100.0 * SUM(ua.activated) / COUNT(*),
        2
    ) AS activation_rate

FROM user_activation ua
JOIN accounts a
    ON ua.account_id = a.account_id

GROUP BY a.employee_band
ORDER BY activation_rate DESC;

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
)

SELECT
    a.industry,
    COUNT(*) AS total_users,
    SUM(ua.activated) AS activated_users,

    ROUND(
        100.0 * SUM(ua.activated) / COUNT(*),
        2
    ) AS activation_rate

FROM user_activation ua
JOIN accounts a
    ON ua.account_id = a.account_id

GROUP BY a.industry
ORDER BY activation_rate DESC;

WITH user_activation AS (
    SELECT
        u.user_id,
        u.signup_device,

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
        u.signup_device
)

SELECT
    signup_device,
    COUNT(*) AS total_users,
    SUM(activated) AS activated_users,

    ROUND(
        100.0 * SUM(activated) / COUNT(*),
        2
    ) AS activation_rate

FROM user_activation

GROUP BY signup_device
ORDER BY activation_rate DESC;

WITH user_behavior AS (
    SELECT
        u.user_id,

        MAX(
            CASE
                WHEN e.event_name = 'integration_connected'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS connected_integration_7d,

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

    GROUP BY u.user_id
)

SELECT
    connected_integration_7d,
    COUNT(*) AS total_users,
    SUM(activated) AS activated_users,

    ROUND(
        100.0 * SUM(activated) / COUNT(*),
        2
    ) AS activation_rate

FROM user_behavior
GROUP BY connected_integration_7d
ORDER BY connected_integration_7d DESC;

WITH user_behavior AS (
    SELECT
        u.user_id,

        MAX(
            CASE
                WHEN e.event_name = 'template_used'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS used_template_7d,

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

    GROUP BY u.user_id
)

SELECT
    used_template_7d,
    COUNT(*) AS total_users,
    SUM(activated) AS activated_users,

    ROUND(
        100.0 * SUM(activated) / COUNT(*),
        2
    ) AS activation_rate

FROM user_behavior
GROUP BY used_template_7d
ORDER BY used_template_7d DESC;

WITH user_behavior AS (
    SELECT
        u.user_id,

        MAX(
            CASE
                WHEN e.event_name = 'integration_connected'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS connected_integration_7d,

        MAX(
            CASE
                WHEN e.event_name = 'template_used'
                 AND e.event_timestamp >= u.signup_timestamp
                 AND e.event_timestamp < u.signup_timestamp + INTERVAL '7 days'
                THEN 1
                ELSE 0
            END
        ) AS used_template_7d,

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

    GROUP BY u.user_id
)

SELECT
    CASE
        WHEN connected_integration_7d = 1
         AND used_template_7d = 1
            THEN 'Integration + Template'

        WHEN connected_integration_7d = 1
         AND used_template_7d = 0
            THEN 'Integration Only'

        WHEN connected_integration_7d = 0
         AND used_template_7d = 1
            THEN 'Template Only'

        ELSE 'Neither'
    END AS behavior_group,

    COUNT(*) AS total_users,
    SUM(activated) AS activated_users,

    ROUND(
        100.0 * SUM(activated) / COUNT(*),
        2
    ) AS activation_rate

FROM user_behavior

GROUP BY
    connected_integration_7d,
    used_template_7d

ORDER BY activation_rate DESC;
