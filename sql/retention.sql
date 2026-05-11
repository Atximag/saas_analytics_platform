-- ============================================================
-- Notivo Analytics Platform — Retention Analysis SQL
-- ============================================================
-- Cohort retention matrix, rolling retention, and survival
-- analysis queries. These power the retention dashboards.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. COHORT RETENTION MATRIX (monthly, user-level)
--
-- Classic N-month retention. Shows what % of users from each
-- signup cohort are still active M months after signup.
-- "Active" = at least one session in the calendar month.
-- ─────────────────────────────────────────────────────────────
WITH user_cohorts AS (
    -- Assign each user to their signup month cohort
    SELECT
        u.user_id,
        DATE_TRUNC('month', u.created_at)::DATE          AS cohort_month,
        u.workspace_id
    FROM users u
    WHERE u.is_deleted = FALSE
),

monthly_activity AS (
    -- For each user, find all months they were active
    SELECT DISTINCT
        s.user_id,
        DATE_TRUNC('month', s.started_at)::DATE           AS activity_month
    FROM sessions s
),

cohort_activity AS (
    -- Join to get months since signup for each activity month
    SELECT
        uc.cohort_month,
        uc.user_id,
        ma.activity_month,
        -- Number of full months between cohort month and activity month
        (DATE_PART('year', ma.activity_month) - DATE_PART('year', uc.cohort_month)) * 12
        + (DATE_PART('month', ma.activity_month) - DATE_PART('month', uc.cohort_month))
            AS months_since_signup
    FROM user_cohorts uc
    JOIN monthly_activity ma ON uc.user_id = ma.user_id
),

cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT user_id)   AS cohort_size
    FROM user_cohorts
    GROUP BY cohort_month
),

retention_counts AS (
    SELECT
        ca.cohort_month,
        ca.months_since_signup,
        COUNT(DISTINCT ca.user_id)  AS retained_users
    FROM cohort_activity ca
    WHERE ca.months_since_signup BETWEEN 0 AND 12
    GROUP BY ca.cohort_month, ca.months_since_signup
)

SELECT
    rc.cohort_month,
    cs.cohort_size,
    rc.months_since_signup,
    rc.retained_users,
    ROUND(
        rc.retained_users::NUMERIC / NULLIF(cs.cohort_size, 0) * 100,
        1
    )                                           AS retention_rate_pct
FROM retention_counts rc
JOIN cohort_sizes cs ON rc.cohort_month = cs.cohort_month
ORDER BY rc.cohort_month, rc.months_since_signup;


-- ─────────────────────────────────────────────────────────────
-- 2. WORKSPACE-LEVEL COHORT RETENTION (logo retention)
--
-- For B2B SaaS, logo retention is often more important than
-- user-level retention. This shows what % of workspaces
-- (companies) remain active month over month.
-- ─────────────────────────────────────────────────────────────
WITH workspace_cohorts AS (
    SELECT
        workspace_id,
        DATE_TRUNC('month', created_at)::DATE   AS cohort_month
    FROM workspaces
    WHERE is_deleted = FALSE
),

workspace_monthly_activity AS (
    SELECT DISTINCT
        workspace_id,
        DATE_TRUNC('month', started_at)::DATE   AS activity_month
    FROM sessions
),

cohort_workspace_activity AS (
    SELECT
        wc.cohort_month,
        wc.workspace_id,
        wma.activity_month,
        (DATE_PART('year', wma.activity_month) - DATE_PART('year', wc.cohort_month)) * 12
        + (DATE_PART('month', wma.activity_month) - DATE_PART('month', wc.cohort_month))
            AS months_since_signup
    FROM workspace_cohorts wc
    JOIN workspace_monthly_activity wma ON wc.workspace_id = wma.workspace_id
),

workspace_cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT workspace_id) AS cohort_size
    FROM workspace_cohorts
    GROUP BY cohort_month
)

SELECT
    cwa.cohort_month,
    wcs.cohort_size,
    cwa.months_since_signup,
    COUNT(DISTINCT cwa.workspace_id)              AS retained_workspaces,
    ROUND(
        COUNT(DISTINCT cwa.workspace_id)::NUMERIC
        / NULLIF(wcs.cohort_size, 0) * 100,
        1
    )                                             AS logo_retention_pct
FROM cohort_workspace_activity cwa
JOIN workspace_cohort_sizes wcs ON cwa.cohort_month = wcs.cohort_month
WHERE cwa.months_since_signup BETWEEN 0 AND 12
GROUP BY cwa.cohort_month, wcs.cohort_size, cwa.months_since_signup
ORDER BY cwa.cohort_month, cwa.months_since_signup;


-- ─────────────────────────────────────────────────────────────
-- 3. ROLLING 28-DAY RETENTION RATE (daily trend)
--
-- Measures: of users active on day D, what % are also active
-- 28 days later. A leading indicator for monthly retention.
-- ─────────────────────────────────────────────────────────────
WITH daily_active_users AS (
    SELECT
        user_id,
        DATE_TRUNC('day', started_at)::DATE     AS activity_date
    FROM sessions
    GROUP BY user_id, DATE_TRUNC('day', started_at)::DATE
),

retention_base AS (
    SELECT
        d1.activity_date                        AS base_date,
        d1.user_id,
        CASE WHEN d2.user_id IS NOT NULL THEN 1 ELSE 0 END AS retained
    FROM daily_active_users d1
    LEFT JOIN daily_active_users d2
        ON d1.user_id = d2.user_id
        AND d2.activity_date = d1.activity_date + INTERVAL '28 days'
)

SELECT
    base_date,
    COUNT(*)                                    AS active_users,
    SUM(retained)                               AS retained_after_28d,
    ROUND(
        SUM(retained)::NUMERIC / NULLIF(COUNT(*), 0) * 100,
        2
    )                                           AS retention_28d_pct,
    -- 7-day moving average for trend smoothing
    ROUND(
        AVG(
            SUM(retained)::NUMERIC / NULLIF(COUNT(*), 0) * 100
        ) OVER (
            ORDER BY base_date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ),
        2
    )                                           AS retention_28d_7d_avg
FROM retention_base
GROUP BY base_date
ORDER BY base_date;


-- ─────────────────────────────────────────────────────────────
-- 4. WEEK-1 RETENTION BY SIGNUP SOURCE
--
-- Critical for PLG: does the acquisition channel predict
-- early retention? Used to optimize channel spend allocation.
-- ─────────────────────────────────────────────────────────────
WITH user_first_week AS (
    SELECT
        u.user_id,
        u.signup_source,
        u.created_at::DATE                      AS signup_date,
        MAX(s.started_at::DATE)                 AS last_active_date,
        COUNT(DISTINCT s.started_at::DATE)      AS active_days_week1
    FROM users u
    LEFT JOIN sessions s
        ON u.user_id = s.user_id
        AND s.started_at BETWEEN u.created_at AND u.created_at + INTERVAL '7 days'
    WHERE u.is_deleted = FALSE
    GROUP BY u.user_id, u.signup_source, u.created_at::DATE
)

SELECT
    signup_source,
    COUNT(*)                                            AS total_users,
    SUM(CASE WHEN active_days_week1 >= 2 THEN 1 ELSE 0 END) AS week1_retained,
    ROUND(
        SUM(CASE WHEN active_days_week1 >= 2 THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100,
        1
    )                                                   AS week1_retention_pct,
    ROUND(AVG(active_days_week1), 2)                    AS avg_active_days_week1
FROM user_first_week
GROUP BY signup_source
ORDER BY week1_retention_pct DESC;


-- ─────────────────────────────────────────────────────────────
-- 5. FEATURE-CORRELATED RETENTION
--
-- Which features, when adopted in the first 7 days, are most
-- correlated with 90-day retention? This drives product and
-- onboarding prioritization decisions.
-- ─────────────────────────────────────────────────────────────
WITH user_features_week1 AS (
    -- Features adopted within first 7 days
    SELECT
        fu.user_id,
        fu.feature_name,
        fu.first_used_at <= u.created_at + INTERVAL '7 days'  AS adopted_week1
    FROM feature_usage fu
    JOIN users u ON fu.user_id = u.user_id
),

user_90d_retention AS (
    -- Was the user active between day 75 and day 90?
    SELECT
        u.user_id,
        MAX(CASE
            WHEN s.started_at BETWEEN u.created_at + INTERVAL '75 days'
                                  AND u.created_at + INTERVAL '90 days'
            THEN 1 ELSE 0
        END)    AS is_retained_90d
    FROM users u
    LEFT JOIN sessions s ON u.user_id = s.user_id
    WHERE u.created_at <= NOW() - INTERVAL '90 days'
    GROUP BY u.user_id
),

feature_retention_correlation AS (
    SELECT
        ufw.feature_name,
        COUNT(DISTINCT ufw.user_id)                             AS users_with_feature,
        SUM(CASE WHEN ufw.adopted_week1 AND ur.is_retained_90d = 1 THEN 1 ELSE 0 END)
                                                                AS retained_with_feature_week1,
        SUM(CASE WHEN NOT ufw.adopted_week1 AND ur.is_retained_90d = 1 THEN 1 ELSE 0 END)
                                                                AS retained_without_feature_week1,
        COUNT(CASE WHEN ufw.adopted_week1 THEN 1 END)           AS users_adopted_week1,
        COUNT(CASE WHEN NOT ufw.adopted_week1 THEN 1 END)       AS users_not_adopted_week1
    FROM user_features_week1 ufw
    JOIN user_90d_retention ur ON ufw.user_id = ur.user_id
    GROUP BY ufw.feature_name
)

SELECT
    feature_name,
    users_adopted_week1,
    ROUND(
        retained_with_feature_week1::NUMERIC
        / NULLIF(users_adopted_week1, 0) * 100,
        1
    )   AS retention_90d_with_feature_pct,
    ROUND(
        retained_without_feature_week1::NUMERIC
        / NULLIF(users_not_adopted_week1, 0) * 100,
        1
    )   AS retention_90d_without_feature_pct,
    -- Lift = how much better is retention when this feature is adopted
    ROUND(
        (retained_with_feature_week1::NUMERIC / NULLIF(users_adopted_week1, 0))
        / NULLIF(retained_without_feature_week1::NUMERIC / NULLIF(users_not_adopted_week1, 0), 0),
        2
    )   AS retention_lift_ratio
FROM feature_retention_correlation
ORDER BY retention_lift_ratio DESC NULLS LAST;
