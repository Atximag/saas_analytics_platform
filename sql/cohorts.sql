-- ============================================================
-- Notivo Analytics Platform — Cohort Analysis SQL
-- ============================================================
-- Revenue cohorts, behavioral cohorts, and survival analysis.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. REVENUE COHORT ANALYSIS
-- How does revenue evolve from each signup cohort?
-- ─────────────────────────────────────────────────────────────
WITH first_payment AS (
    SELECT
        w.workspace_id,
        DATE_TRUNC('month', MIN(s.started_at))::DATE    AS first_paid_month,
        MIN(s.mrr)                                      AS initial_mrr
    FROM subscriptions s
    JOIN workspaces w ON s.workspace_id = w.workspace_id
    WHERE s.plan_id != 'free' AND s.status IN ('active', 'canceled', 'past_due')
    GROUP BY w.workspace_id
),

cohort_mrr AS (
    SELECT
        fp.first_paid_month                             AS cohort_month,
        DATE_TRUNC('month', s.current_period_start)::DATE AS mrr_month,
        fp.workspace_id,
        SUM(s.mrr)                                      AS current_mrr
    FROM first_payment fp
    JOIN subscriptions s ON fp.workspace_id = s.workspace_id
    WHERE s.status IN ('active', 'past_due')
    GROUP BY 1, 2, fp.workspace_id
)

SELECT
    cm.cohort_month,
    cm.mrr_month,
    (DATE_PART('year', cm.mrr_month) - DATE_PART('year', cm.cohort_month)) * 12
    + (DATE_PART('month', cm.mrr_month) - DATE_PART('month', cm.cohort_month))
        AS months_since_first_payment,
    COUNT(DISTINCT cm.workspace_id)                     AS active_paying_workspaces,
    SUM(cm.current_mrr)                                 AS cohort_mrr,
    SUM(fp.initial_mrr)                                 AS cohort_initial_mrr,
    ROUND(
        SUM(cm.current_mrr) / NULLIF(SUM(fp.initial_mrr), 0) * 100,
        1
    )                                                   AS revenue_retention_pct
FROM cohort_mrr cm
JOIN first_payment fp ON cm.workspace_id = fp.workspace_id
GROUP BY cm.cohort_month, cm.mrr_month,
    (DATE_PART('year', cm.mrr_month) - DATE_PART('year', cm.cohort_month)) * 12
    + (DATE_PART('month', cm.mrr_month) - DATE_PART('month', cm.cohort_month))
ORDER BY cm.cohort_month, months_since_first_payment;


-- ─────────────────────────────────────────────────────────────
-- 2. SURVIVAL ANALYSIS (Time-to-Churn)
-- When do customers churn relative to signup?
-- ─────────────────────────────────────────────────────────────
WITH workspace_lifetimes AS (
    SELECT
        s.workspace_id,
        s.plan_id,
        s.started_at,
        CASE
            WHEN s.canceled_at IS NOT NULL THEN TRUE
            ELSE FALSE
        END                                             AS churned,
        CASE
            WHEN s.canceled_at IS NOT NULL
            THEN DATE_PART('month', AGE(s.canceled_at, s.started_at))
            ELSE DATE_PART('month', AGE(NOW(), s.started_at))
        END                                             AS survival_months
    FROM subscriptions s
    WHERE s.plan_id != 'free'
),

-- Kaplan-Meier style survival table
survival_table AS (
    SELECT
        plan_id,
        FLOOR(survival_months)                          AS month,
        COUNT(*)                                        AS at_risk,
        SUM(CASE WHEN churned THEN 1 ELSE 0 END)        AS events_churned
    FROM workspace_lifetimes
    GROUP BY plan_id, FLOOR(survival_months)
)

SELECT
    plan_id,
    month,
    at_risk,
    events_churned,
    ROUND(1.0 - SUM(events_churned::NUMERIC / NULLIF(at_risk, 0))
              OVER (PARTITION BY plan_id ORDER BY month), 4)
        AS survival_probability
FROM survival_table
ORDER BY plan_id, month;
