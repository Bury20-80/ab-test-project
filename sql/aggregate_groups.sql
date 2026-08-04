-- A/B test group-level conversion metrics
-- SQL dialect: SQLite (database opened in DBeaver)
-- Assumptions:
--   1. The imported table is named marketing_AB.
--   2. "converted" is stored as a SQLite Boolean-like value (0/1)
--      or as equivalent text such as True/False.
--   3. Column names with spaces were preserved during CSV import
--      and therefore require double quotes.

WITH normalized_data AS (
    SELECT
        "test group" AS test_group,
        CASE
            WHEN LOWER(TRIM(CAST("converted" AS TEXT)))
                 IN ('1', 'true', 't', 'yes', 'y')
                THEN 1
            ELSE 0
        END AS converted_flag
    FROM marketing_AB
),
group_metrics AS (
    SELECT
        test_group,
        COUNT(*) AS n_users,
        SUM(converted_flag) AS n_converted
    FROM normalized_data
    GROUP BY test_group
),
total_metrics AS (
    SELECT SUM(n_users) AS total_users
    FROM group_metrics
)
SELECT
    g.test_group,
    g.n_users,
    g.n_converted,
    ROUND(
        1.0 * g.n_converted / NULLIF(g.n_users, 0),
        6
    ) AS conversion_rate,
    ROUND(
        100.0 * g.n_users / NULLIF(t.total_users, 0),
        2
    ) AS traffic_share_pct
FROM group_metrics AS g
CROSS JOIN total_metrics AS t
ORDER BY g.test_group;
