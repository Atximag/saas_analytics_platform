-- ============================================================
-- Notivo Analytics Platform — LTV, CAC & Unit Economics SQL
-- ============================================================
-- Customer Lifetime Value, Customer Acquisition Cost, and
-- the unit economics that determine business model health.
-- These are the metrics the CFO and board care most about.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. MRR WATERFALL (monthly revenue motion)
--
-- The most important revenue metric for SaaS. Decomposes
-- net new MRR into its 5 components. Used in board packs.
-- ─────────────────────────────────────────────────────────────
WITH monthly_mrr AS (
    -- MRR per workspace per month (handle plan changes)
    SELECT
        workspace_id,
        DATE_TRUNC('month', current_period_start)::DATE  AS mrr_month,
        SUM(mrr)                                          AS total_mrr
    FROM subscriptions
    WHERE status IN ('active', 'past_due')
    GROUP BY workspace_id, DATE_TRUNC('month', current_period_start)::DATE
),

mrr_with_lag AS (
    SELECT
        workspace_id,
        mrr_month,
        total_mrr                                         AS current_mrr,
        LAG(total_mrr) OVER (
            PARTITION BY workspace_id
            ORDER BY mrr_month
        )                                                 AS prev_mrr
    FROM monthly_mrr
),

mrr_classification AS (
    SELECT
        mrr_month,
        workspace_id,
        current_mrr,
        prev_mrr,
        CASE
            WHEN prev_mrr IS NULL THEN 'new'              -- first payment
            WHEN current_mrr > prev_mrr THEN 'expansion'  -- seat upgrade or plan upgrade
            WHEN current_mrr < prev_mrr THEN 'contraction'-- seat downgrade or plan downgrade
            WHEN current_mrr = prev_mrr THEN 'retained'
            ELSE 'other'
        END                                               AS mrr_type
    FROM mrr_with_lag
),

-- Churned MRR: workspaces that had MRR last month but none this month
churned_mrr AS (
    SELECT
        DATE_TRUNC('month', canceled_at)::DATE            AS mrr_month,
        SUM(mrr_lost)                                     AS churned_mrr,
        COUNT(*)                                          AS churned_workspaces
    FROM cancellations
    GROUP BY DATE_TRUNC('month', canceled_at)::DATE
)

SELECT
    mc.mrr_month,
    SUM(CASE WHEN mc.mrr_type = 'new'
        THEN mc.current_mrr ELSE 0 END)                   AS new_mrr,
    SUM(CASE WHEN mc.mrr_type = 'expansion'
        THEN mc.current_mrr - mc.prev_mrr ELSE 0 END)     AS expansion_mrr,
    SUM(CASE WHEN mc.mrr_type = 'contraction'
        THEN mc.current_mrr - mc.prev_mrr ELSE 0 END)     AS contraction_mrr,  -- negative
    COALESCE(cm.churned_mrr, 0) * -1                      AS churned_mrr,      -- negative
    SUM(CASE WHEN mc.mrr_type = 'retained'
        THEN mc.current_mrr ELSE 0 END)                   AS retained_mrr,
    SUM(mc.current_mrr)                                   AS total_mrr,
    -- Net new MRR = new + expansion + contraction (neg) + churn (neg)
    SUM(CASE WHEN mc.mrr_type = 'new' THEN mc.current_mrr ELSE 0 END)
    + SUM(CASE WHEN mc.mrr_type = 'expansion' THEN mc.current_mrr - mc.prev_mrr ELSE 0 END)
    + SUM(CASE WHEN mc.mrr_type = 'contraction' THEN mc.current_mrr - mc.prev_mrr ELSE 0 END)
    - COALESCE(cm.churned_mrr, 0)                         AS net_new_mrr
FROM mrr_classification mc
LEFT JOIN churned_mrr cm ON mc.mrr_month = cm.mrr_month
GROUP BY mc.mrr_month, cm.churned_mrr
ORDER BY mc.mrr_month;


-- ─────────────────────────────────────────────────────────────
-- 2. NET REVENUE RETENTION (NRR) BY COHORT
--
-- NRR > 100% means a cohort grows revenue even without new logos.
-- This is the most important growth-quality metric for SaaS.
-- ─────────────────────────────────────────────────────────────
WITH cohort_mrr AS (
    SELECT
        w.workspace_id,
        DATE_TRUNC('month', w.created_at)::DATE           AS cohort_month,
        DATE_TRUNC('month', s.current_period_start)::DATE AS mrr_month,
        SUM(s.mrr)                                        AS mrr
    FROM subscriptions s
    JOIN workspaces w ON s.workspace_id = w.workspace_id
    WHERE s.status IN ('active', 'past_due')
    GROUP BY w.workspace_id, DATE_TRUNC('month', w.created_at)::DATE,
             DATE_TRUNC('month', s.current_period_start)::DATE
),

cohort_baseline AS (
    -- MRR in the cohort's first full month
    SELECT
        workspace_id,
        cohort_month,
        mrr    AS baseline_mrr
    FROM cohort_mrr
    WHERE mrr_month = cohort_month
),

cohort_current AS (
    SELECT
        cm.cohort_month,
        -- 12 months after cohort month
        SUM(cb.baseline_mrr)                              AS baseline_mrr_sum,
        SUM(cm.mrr)                                       AS current_mrr_sum
    FROM cohort_mrr cm
    JOIN cohort_baseline cb ON cm.workspace_id = cb.workspace_id
    WHERE cm.mrr_month = cm.cohort_month + INTERVAL '12 months'
    GROUP BY cm.cohort_month
)

SELECT
    cohort_month,
    baseline_mrr_sum,
    current_mrr_sum,
    ROUND(
        current_mrr_sum::NUMERIC / NULLIF(baseline_mrr_sum, 0) * 100,
        1
    )   AS nrr_12m_pct
FROM cohort_current
ORDER BY cohort_month;


-- ─────────────────────────────────────────────────────────────
-- 3. LTV BY ACQUISITION CHANNEL
--
-- Lifetime Value = ARPU × Gross Margin % × Avg Lifetime (months)
-- This tells us which channels to invest in for profitable growth.
-- ─────────────────────────────────────────────────────────────
WITH channel_metrics AS (
    SELECT
        mc.channel_name,
        mc.channel_type,
        mc.cac_estimate,
        COUNT(DISTINCT w.workspace_id)                    AS total_workspaces,
        -- Average MRR per workspace
        AVG(s.mrr)                                        AS avg_mrr_per_workspace,
        -- Average tenure: months from subscription start to now or cancellation
        AVG(
            CASE
                WHEN s.canceled_at IS NOT NULL
                THEN DATE_PART('month', AGE(s.canceled_at, s.started_at))
                ELSE DATE_PART('month', AGE(NOW(), s.started_at))
            END
        )                                                 AS avg_lifetime_months
    FROM workspaces w
    JOIN marketing_channels mc ON w.channel_id = mc.channel_id
    LEFT JOIN subscriptions s ON w.workspace_id = s.workspace_id
        AND s.started_at = (
            SELECT MIN(started_at) FROM subscriptions s2
            WHERE s2.workspace_id = w.workspace_id
        )
    GROUP BY mc.channel_name, mc.channel_type, mc.cac_estimate
)

SELECT
    channel_name,
    channel_type,
    total_workspaces,
    ROUND(avg_mrr_per_workspace, 2)                       AS avg_mrr,
    ROUND(avg_lifetime_months, 1)                         AS avg_lifetime_months,
    -- LTV = MRR × lifetime × assumed 70% gross margin
    ROUND(avg_mrr_per_workspace * avg_lifetime_months * 0.70, 0)
                                                          AS estimated_ltv,
    ROUND(cac_estimate, 0)                                AS cac,
    ROUND(
        (avg_mrr_per_workspace * avg_lifetime_months * 0.70)
        / NULLIF(cac_estimate, 0),
        2
    )                                                     AS ltv_cac_ratio,
    -- CAC payback = months to recover CAC from gross profit
    ROUND(
        cac_estimate / NULLIF(avg_mrr_per_workspace * 0.70, 0),
        1
    )                                                     AS cac_payback_months
FROM channel_metrics
ORDER BY ltv_cac_ratio DESC NULLS LAST;


-- ─────────────────────────────────────────────────────────────
-- 4. ARPU & ARPW TRENDS (Average Revenue Per User / Workspace)
-- ─────────────────────────────────────────────────────────────
WITH monthly_active_counts AS (
    SELECT
        DATE_TRUNC('month', started_at)::DATE             AS month,
        COUNT(DISTINCT user_id)                           AS mau,
        COUNT(DISTINCT workspace_id)                      AS active_workspaces
    FROM sessions
    GROUP BY DATE_TRUNC('month', started_at)::DATE
),

monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', issued_at)::DATE              AS month,
        SUM(amount)                                       AS total_revenue
    FROM invoices
    WHERE status = 'paid'
    GROUP BY DATE_TRUNC('month', issued_at)::DATE
)

SELECT
    mr.month,
    mr.total_revenue,
    mac.mau,
    mac.active_workspaces,
    ROUND(mr.total_revenue / NULLIF(mac.mau, 0), 2)       AS arpu,
    ROUND(mr.total_revenue / NULLIF(mac.active_workspaces, 0), 2)
                                                          AS arpw,
    -- Rolling 3-month average ARPU for trend analysis
    ROUND(
        AVG(mr.total_revenue / NULLIF(mac.mau, 0))
        OVER (ORDER BY mr.month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),
        2
    )                                                     AS arpu_3m_avg
FROM monthly_revenue mr
JOIN monthly_active_counts mac ON mr.month = mac.month
ORDER BY mr.month;
