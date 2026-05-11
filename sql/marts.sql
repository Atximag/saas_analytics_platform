-- ============================================================
-- Notivo Analytics Platform — Business Mart Tables
-- ============================================================
-- Aggregated, business-ready tables for dashboards and reports.
-- These are materialized tables (not views) for performance.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- mart_workspace_health
-- One row per active workspace with full health context.
-- Used by: CS dashboard, churn model, exec reporting
-- ─────────────────────────────────────────────────────────────
CREATE TABLE mart_workspace_health AS
SELECT
    w.workspace_id,
    w.workspace_name,
    w.company_size,
    w.industry,
    w.country_code,
    w.created_at                                        AS workspace_created_at,
    w.plan_id,
    s.mrr,
    s.seat_count,
    s.status                                            AS subscription_status,
    s.started_at                                        AS subscription_started_at,
    mc.channel_name,
    mc.channel_type,
    -- Engagement signals
    MAX(sess.started_at)                                AS last_session_at,
    DATE_PART('day', NOW() - MAX(sess.started_at))      AS days_since_last_session,
    COUNT(DISTINCT CASE WHEN sess.started_at >= NOW() - INTERVAL '7 days'
          THEN sess.session_id END)                     AS sessions_last_7d,
    COUNT(DISTINCT CASE WHEN sess.started_at >= NOW() - INTERVAL '30 days'
          THEN sess.session_id END)                     AS sessions_last_30d,
    COUNT(DISTINCT CASE WHEN sess.started_at >= NOW() - INTERVAL '30 days'
          THEN sess.user_id END)                        AS dau_last_30d,
    -- Feature usage signals
    COUNT(DISTINCT fu.feature_name)                     AS distinct_features_used,
    SUM(fu.usage_count_30d)                             AS total_feature_events_30d,
    -- Tenure
    DATE_PART('month', AGE(NOW(), s.started_at))        AS subscription_tenure_months,
    -- Computed at query time (use segmentation module for full RFM)
    CASE
        WHEN DATE_PART('day', NOW() - MAX(sess.started_at)) > 21  THEN 'High Risk'
        WHEN DATE_PART('day', NOW() - MAX(sess.started_at)) > 14  THEN 'Medium Risk'
        ELSE 'Healthy'
    END                                                 AS recency_risk_tier
FROM workspaces w
JOIN subscriptions s ON w.workspace_id = s.workspace_id AND s.status = 'active'
LEFT JOIN marketing_channels mc ON w.channel_id = mc.channel_id
LEFT JOIN sessions sess ON w.workspace_id = sess.workspace_id
LEFT JOIN feature_usage fu ON w.workspace_id = fu.workspace_id
WHERE w.is_deleted = FALSE
GROUP BY
    w.workspace_id, w.workspace_name, w.company_size, w.industry,
    w.country_code, w.created_at, w.plan_id, s.mrr, s.seat_count,
    s.status, s.started_at, mc.channel_name, mc.channel_type;


-- ─────────────────────────────────────────────────────────────
-- mart_daily_metrics
-- Daily aggregate for trend dashboards.
-- Refreshed daily via Airflow DAG.
-- ─────────────────────────────────────────────────────────────
CREATE TABLE mart_daily_metrics AS
WITH session_metrics AS (
    SELECT
        started_at::DATE AS metric_date,
        COUNT(DISTINCT user_id) AS dau,
        COUNT(DISTINCT workspace_id) AS daw,  -- Daily Active Workspaces
        COUNT(*) AS total_sessions,
        AVG(duration_seconds) AS avg_session_duration_s,
        SUM(CASE WHEN is_bounce THEN 1 ELSE 0 END)::NUMERIC / NULLIF(COUNT(*), 0)
            AS bounce_rate
    FROM sessions
    GROUP BY started_at::DATE
),
new_users AS (
    SELECT
        created_at::DATE AS metric_date,
        COUNT(*) AS new_users
    FROM users
    WHERE is_deleted = FALSE
    GROUP BY created_at::DATE
),
new_workspaces AS (
    SELECT
        created_at::DATE AS metric_date,
        COUNT(*) AS new_workspaces
    FROM workspaces
    GROUP BY created_at::DATE
)

SELECT
    sm.metric_date,
    COALESCE(sm.dau, 0) AS dau,
    COALESCE(sm.daw, 0) AS daw,
    COALESCE(sm.total_sessions, 0) AS total_sessions,
    ROUND(COALESCE(sm.avg_session_duration_s, 0) / 60, 2) AS avg_session_duration_min,
    ROUND(COALESCE(sm.bounce_rate, 0) * 100, 2) AS bounce_rate_pct,
    COALESCE(nu.new_users, 0) AS new_users,
    COALESCE(nw.new_workspaces, 0) AS new_workspaces
FROM session_metrics sm
LEFT JOIN new_users nu ON sm.metric_date = nu.metric_date
LEFT JOIN new_workspaces nw ON sm.metric_date = nw.metric_date
ORDER BY sm.metric_date;
