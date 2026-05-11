-- ============================================================
-- Notivo Analytics Platform — Executive KPI Dashboard SQL
-- ============================================================
-- Board-level metrics. These queries produce the numbers
-- that go into the monthly business review and investor deck.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. MONTHLY EXECUTIVE SCORECARD
--
-- Single query producing all top-line KPIs for current month
-- vs. prior month. Designed for board pack automation.
-- ─────────────────────────────────────────────────────────────
WITH current_month AS (
    SELECT DATE_TRUNC('month', NOW())::DATE  AS month_start
),

-- Active workspaces (paying)
paying_workspaces AS (
    SELECT
        COUNT(DISTINCT w.workspace_id)          AS count_paying,
        SUM(s.mrr)                              AS total_mrr
    FROM workspaces w
    JOIN subscriptions s ON w.workspace_id = s.workspace_id
        AND s.status = 'active'
    WHERE w.is_deleted = FALSE
),

-- Active users (MAU)
mau AS (
    SELECT COUNT(DISTINCT user_id) AS mau_count
    FROM sessions
    WHERE started_at >= DATE_TRUNC('month', NOW())
),

-- DAU (today)
dau AS (
    SELECT COUNT(DISTINCT user_id) AS dau_count
    FROM sessions
    WHERE started_at >= CURRENT_DATE
),

-- MRR current
mrr_current AS (
    SELECT SUM(mrr) AS current_mrr
    FROM subscriptions
    WHERE status = 'active'
),

-- MRR prior month
mrr_prior AS (
    SELECT SUM(mrr) AS prior_mrr
    FROM subscriptions
    WHERE status = 'active'
      AND started_at < DATE_TRUNC('month', NOW())
),

-- Gross logo churn this month
logo_churn AS (
    SELECT COUNT(DISTINCT workspace_id) AS churned_logos
    FROM cancellations
    WHERE canceled_at >= DATE_TRUNC('month', NOW())
),

-- New logos this month
new_logos AS (
    SELECT COUNT(DISTINCT workspace_id) AS new_workspaces
    FROM workspaces
    WHERE created_at >= DATE_TRUNC('month', NOW())
),

-- Trial conversions this month
trial_conversions AS (
    SELECT COUNT(*) AS conversions
    FROM subscriptions
    WHERE plan_id != 'free'
      AND started_at >= DATE_TRUNC('month', NOW())
      AND trial_started_at IS NOT NULL
),

-- Failed payment rate
payment_health AS (
    SELECT
        COUNT(*) FILTER (WHERE status = 'failed')::NUMERIC /
        NULLIF(COUNT(*), 0) * 100   AS failed_payment_pct
    FROM invoices
    WHERE issued_at >= DATE_TRUNC('month', NOW())
)

SELECT
    TO_CHAR(NOW(), 'YYYY-MM')                             AS report_month,
    (SELECT current_mrr FROM mrr_current)                 AS mrr,
    (SELECT current_mrr FROM mrr_current) * 12            AS arr,
    ROUND(
        ((SELECT current_mrr FROM mrr_current)
         - (SELECT prior_mrr FROM mrr_prior))
        / NULLIF((SELECT prior_mrr FROM mrr_prior), 0) * 100,
        1
    )                                                     AS mrr_growth_mom_pct,
    (SELECT count_paying FROM paying_workspaces)          AS paying_workspaces,
    (SELECT total_mrr FROM paying_workspaces)
        / NULLIF((SELECT count_paying FROM paying_workspaces), 0)
                                                          AS arpw,
    (SELECT mau_count FROM mau)                           AS mau,
    (SELECT dau_count FROM dau)                           AS dau,
    ROUND(
        (SELECT dau_count FROM dau)::NUMERIC
        / NULLIF((SELECT mau_count FROM mau), 0) * 100,
        1
    )                                                     AS stickiness_dau_mau,
    (SELECT new_workspaces FROM new_logos)                AS new_logos,
    (SELECT churned_logos FROM logo_churn)                AS churned_logos,
    ROUND(
        (SELECT churned_logos FROM logo_churn)::NUMERIC
        / NULLIF((SELECT count_paying FROM paying_workspaces), 0) * 100,
        2
    )                                                     AS gross_logo_churn_pct,
    (SELECT conversions FROM trial_conversions)           AS trial_conversions,
    ROUND((SELECT failed_payment_pct FROM payment_health), 1)
                                                          AS failed_payment_pct;


-- ─────────────────────────────────────────────────────────────
-- 2. TRAILING 13-MONTH KPI TREND
--
-- Shows all key metrics month-over-month for 13 months.
-- Used to build trend charts in the executive dashboard.
-- ─────────────────────────────────────────────────────────────
WITH months AS (
    SELECT generate_series(
        DATE_TRUNC('month', NOW() - INTERVAL '12 months'),
        DATE_TRUNC('month', NOW()),
        INTERVAL '1 month'
    )::DATE AS month
),

monthly_mrr_trend AS (
    SELECT
        DATE_TRUNC('month', current_period_start)::DATE   AS month,
        SUM(mrr)                                          AS mrr
    FROM subscriptions
    WHERE status IN ('active', 'past_due')
    GROUP BY DATE_TRUNC('month', current_period_start)::DATE
),

monthly_mau_trend AS (
    SELECT
        DATE_TRUNC('month', started_at)::DATE             AS month,
        COUNT(DISTINCT user_id)                           AS mau
    FROM sessions
    GROUP BY DATE_TRUNC('month', started_at)::DATE
),

monthly_new_workspaces AS (
    SELECT
        DATE_TRUNC('month', created_at)::DATE             AS month,
        COUNT(*)                                          AS new_workspaces
    FROM workspaces
    GROUP BY DATE_TRUNC('month', created_at)::DATE
),

monthly_churn AS (
    SELECT
        DATE_TRUNC('month', canceled_at)::DATE            AS month,
        COUNT(DISTINCT workspace_id)                      AS churned_workspaces,
        SUM(mrr_lost)                                     AS churned_mrr
    FROM cancellations
    GROUP BY DATE_TRUNC('month', canceled_at)::DATE
)

SELECT
    m.month,
    COALESCE(mrr.mrr, 0)                                  AS mrr,
    COALESCE(mrr.mrr, 0) * 12                             AS arr,
    -- MoM growth
    ROUND(
        (COALESCE(mrr.mrr, 0) - LAG(COALESCE(mrr.mrr, 0)) OVER (ORDER BY m.month))
        / NULLIF(LAG(COALESCE(mrr.mrr, 0)) OVER (ORDER BY m.month), 0) * 100,
        1
    )                                                     AS mrr_growth_pct,
    COALESCE(mau.mau, 0)                                  AS mau,
    COALESCE(nw.new_workspaces, 0)                        AS new_workspaces,
    COALESCE(ch.churned_workspaces, 0)                    AS churned_workspaces,
    COALESCE(ch.churned_mrr, 0)                           AS churned_mrr
FROM months m
LEFT JOIN monthly_mrr_trend mrr ON m.month = mrr.month
LEFT JOIN monthly_mau_trend mau ON m.month = mau.month
LEFT JOIN monthly_new_workspaces nw ON m.month = nw.month
LEFT JOIN monthly_churn ch ON m.month = ch.month
ORDER BY m.month;


-- ─────────────────────────────────────────────────────────────
-- 3. PLAN MIX ANALYSIS
--
-- How is revenue distributed across plans?
-- Concentration risk + upsell opportunity sizing.
-- ─────────────────────────────────────────────────────────────
WITH plan_distribution AS (
    SELECT
        s.plan_id,
        sp.plan_name,
        COUNT(DISTINCT s.workspace_id)                    AS workspace_count,
        SUM(s.seat_count)                                 AS total_seats,
        SUM(s.mrr)                                        AS total_mrr,
        AVG(s.mrr)                                        AS avg_mrr_per_workspace,
        AVG(s.seat_count)                                 AS avg_seats
    FROM subscriptions s
    JOIN subscription_plans sp ON s.plan_id = sp.plan_id
    WHERE s.status = 'active'
    GROUP BY s.plan_id, sp.plan_name
)

SELECT
    plan_id,
    plan_name,
    workspace_count,
    total_seats,
    ROUND(total_mrr, 0)                                   AS total_mrr,
    ROUND(avg_mrr_per_workspace, 0)                       AS avg_mrr_per_workspace,
    ROUND(avg_seats, 1)                                   AS avg_seats,
    -- Revenue share
    ROUND(total_mrr / SUM(total_mrr) OVER () * 100, 1)    AS mrr_share_pct,
    -- Workspace share
    ROUND(workspace_count::NUMERIC / SUM(workspace_count) OVER () * 100, 1)
                                                          AS workspace_share_pct
FROM plan_distribution
ORDER BY total_mrr DESC;
