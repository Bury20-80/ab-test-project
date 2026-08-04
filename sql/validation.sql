-- Data-quality checks for the imported marketing A/B dataset
-- SQL dialect: SQLite (database opened in DBeaver)
-- The queries avoid PostgreSQL-only syntax so they can run directly
-- against the local marketing.db file.

-- 1. Row count, user uniqueness, and duplicate-user count
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT "user id") AS distinct_users,
    COUNT(*) - COUNT(DISTINCT "user id") AS duplicate_user_rows
FROM marketing_AB;

-- 2. Missing values in required columns
SELECT
    SUM(CASE WHEN "user id" IS NULL THEN 1 ELSE 0 END) AS missing_user_id,
    SUM(CASE WHEN "test group" IS NULL THEN 1 ELSE 0 END) AS missing_test_group,
    SUM(CASE WHEN "converted" IS NULL THEN 1 ELSE 0 END) AS missing_converted,
    SUM(CASE WHEN "total ads" IS NULL THEN 1 ELSE 0 END) AS missing_total_ads,
    SUM(CASE WHEN "most ads day" IS NULL THEN 1 ELSE 0 END) AS missing_most_ads_day,
    SUM(CASE WHEN "most ads hour" IS NULL THEN 1 ELSE 0 END) AS missing_most_ads_hour
FROM marketing_AB;

-- 3. Duplicate user IDs: this query should return zero rows
SELECT
    "user id",
    COUNT(*) AS row_count
FROM marketing_AB
GROUP BY "user id"
HAVING COUNT(*) > 1
ORDER BY row_count DESC, "user id";

-- 4. Experiment-group and outcome distribution
SELECT
    "test group" AS test_group,
    "converted" AS converted,
    COUNT(*) AS row_count
FROM marketing_AB
GROUP BY "test group", "converted"
ORDER BY "test group", "converted";

-- 5. Invalid domain or range values: every result should be zero
SELECT
    SUM(
        CASE
            WHEN "test group" NOT IN ('ad', 'psa') THEN 1
            ELSE 0
        END
    ) AS invalid_test_group,
    SUM(
        CASE
            WHEN LOWER(TRIM(CAST("converted" AS TEXT))) NOT IN (
                '0', '1', 'false', 'true', 'f', 't', 'no', 'yes', 'n', 'y'
            ) THEN 1
            ELSE 0
        END
    ) AS invalid_converted,
    SUM(CASE WHEN "total ads" < 1 THEN 1 ELSE 0 END) AS invalid_total_ads,
    SUM(
        CASE
            WHEN "most ads hour" NOT BETWEEN 0 AND 23 THEN 1
            ELSE 0
        END
    ) AS invalid_most_ads_hour,
    SUM(
        CASE
            WHEN "most ads day" NOT IN (
                'Monday', 'Tuesday', 'Wednesday', 'Thursday',
                'Friday', 'Saturday', 'Sunday'
            ) THEN 1
            ELSE 0
        END
    ) AS invalid_most_ads_day
FROM marketing_AB;

-- 6. Allocation and descriptive exposure checks
-- SQLite has no built-in PERCENTILE_CONT, so the median is calculated
-- with ROW_NUMBER() and COUNT() window functions.
WITH ranked_exposure AS (
    SELECT
        "test group" AS test_group,
        CAST("total ads" AS REAL) AS total_ads,
        ROW_NUMBER() OVER (
            PARTITION BY "test group"
            ORDER BY "total ads"
        ) AS row_num,
        COUNT(*) OVER (
            PARTITION BY "test group"
        ) AS group_size
    FROM marketing_AB
),
median_exposure AS (
    SELECT
        test_group,
        AVG(total_ads) AS median_total_ads
    FROM ranked_exposure
    WHERE row_num IN (
        (group_size + 1) / 2,
        (group_size + 2) / 2
    )
    GROUP BY test_group
),
group_summary AS (
    SELECT
        "test group" AS test_group,
        COUNT(*) AS n_users,
        AVG(CAST("total ads" AS REAL)) AS mean_total_ads,
        MIN("total ads") AS min_total_ads,
        MAX("total ads") AS max_total_ads
    FROM marketing_AB
    GROUP BY "test group"
),
total_summary AS (
    SELECT COUNT(*) AS total_users
    FROM marketing_AB
)
SELECT
    g.test_group,
    g.n_users,
    ROUND(
        100.0 * g.n_users / NULLIF(t.total_users, 0),
        2
    ) AS traffic_share_pct,
    ROUND(g.mean_total_ads, 2) AS mean_total_ads,
    ROUND(m.median_total_ads, 2) AS median_total_ads,
    g.min_total_ads,
    g.max_total_ads
FROM group_summary AS g
JOIN median_exposure AS m
    ON g.test_group = m.test_group
CROSS JOIN total_summary AS t
ORDER BY g.test_group;
