-- ============================================================
-- dbt mart model: fct_mrr
-- Monthly Recurring Revenue fact table.
-- One row per workspace per month with full MRR motion.
-- This is the single source of truth for all revenue metrics.
-- ============================================================

{{ config(
    materialized='table',
    tags=['marts', 'finance', 'daily'],
    indexes=[
        {'columns': ['mrr_month'], 'type': 'btree'},
        {'columns': ['workspace_id', 'mrr_month'], 'unique': True},
    ]
) }}

WITH subscription_monthly AS (
    SELECT
        s.workspace_id,
        DATE_TRUNC('month', s.current_period_start)::DATE   AS mrr_month,
        s.plan_id,
        s.seat_count,
        SUM(s.mrr)                                          AS mrr
    FROM {{ ref('stg_subscriptions') }} s
    WHERE s.status IN ('active', 'past_due')
    GROUP BY 1, 2, 3, 4
),

mrr_with_lag AS (
    SELECT
        sm.*,
        LAG(sm.mrr) OVER (
            PARTITION BY sm.workspace_id
            ORDER BY sm.mrr_month
        )                                                   AS prev_mrr,
        LAG(sm.plan_id) OVER (
            PARTITION BY sm.workspace_id
            ORDER BY sm.mrr_month
        )                                                   AS prev_plan_id
    FROM subscription_monthly sm
),

mrr_classified AS (
    SELECT
        mwl.mrr_month,
        mwl.workspace_id,
        mwl.plan_id,
        mwl.seat_count,
        mwl.mrr,
        mwl.prev_mrr,
        -- MRR motion classification
        CASE
            WHEN mwl.prev_mrr IS NULL           THEN 'new'
            WHEN mwl.mrr > mwl.prev_mrr         THEN 'expansion'
            WHEN mwl.mrr < mwl.prev_mrr         THEN 'contraction'
            WHEN mwl.mrr = mwl.prev_mrr         THEN 'retained'
            ELSE 'other'
        END                                                 AS mrr_type,
        -- MRR delta
        COALESCE(mwl.mrr - mwl.prev_mrr, mwl.mrr)          AS mrr_delta,
        -- Plan change flag
        mwl.plan_id != COALESCE(mwl.prev_plan_id, mwl.plan_id)
                                                            AS is_plan_change
    FROM mrr_with_lag mwl
)

SELECT
    mc.mrr_month,
    mc.workspace_id,
    mc.plan_id,
    mc.seat_count,
    mc.mrr,
    mc.prev_mrr,
    mc.mrr_type,
    mc.mrr_delta,
    mc.is_plan_change,
    -- Enrichment from workspace dimension
    w.company_size,
    w.industry,
    w.country_code,
    w.channel_id,
    ch.channel_name,
    ch.channel_type,
    -- Workspace age at measurement point
    DATE_PART('month', AGE(mc.mrr_month, w.created_at::DATE))
                                                            AS workspace_age_months
FROM mrr_classified mc
LEFT JOIN {{ ref('dim_workspaces') }} w
    ON mc.workspace_id = w.workspace_id
LEFT JOIN {{ ref('dim_channels') }} ch
    ON w.channel_id = ch.channel_id
