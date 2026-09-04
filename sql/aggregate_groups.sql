-- A/B test group-level conversion metrics
-- SQL dialect: SQLite (database opened in DBeaver)
-- Assumptions:
--   1. The imported table is named marketing_AB.
--   2. "converted" is stored as a SQLite Boolean-like value (0/1)
--      or as equivalent text such as True/False.
--   3. Column names with spaces were preserved during CSV import
--      and therefore require double quotes.
--
-- Guardrail:
-- Unsupported experiment-group or conversion values are normalized to NULL.
-- If any such values exist, this query returns no group metrics instead of
-- silently treating invalid observations as valid data. Run validation.sql
-- first to identify the offending rows.

WITH normalized_data AS (
    SELECT
        LOWER(TRIM(CAST("test group" AS TEXT))) AS test_group,
        CASE
            WHEN LOWER(TRIM(CAST("converted" AS TEXT)))
                 IN ('1', 'true', 't', 'yes', 'y')
                THEN 1
            WHEN LOWER(TRIM(CAST("converted" AS TEXT)))
                 IN ('0', 'false', 'f', 'no', 'n')
                THEN 0
            ELSE NULL
        END AS converted_flag
    FROM marketing_AB
),
validation AS (
    SELECT
        SUM(
            CASE
                WHEN test_group NOT IN ('ad', 'psa') OR test_group IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS invalid_test_group_rows,
        SUM(
            CASE
                WHEN converted_flag IS NULL
                    THEN 1
                ELSE 0
            END
        ) AS invalid_converted_rows
    FROM normalized_data
),
group_metrics AS (
    SELECT
        n.test_group,
        COUNT(*) AS n_users,
        SUM(n.converted_flag) AS n_converted
    FROM normalized_data AS n
    CROSS JOIN validation AS v
    WHERE v.invalid_test_group_rows = 0
      AND v.invalid_converted_rows = 0
    GROUP BY n.test_group
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
