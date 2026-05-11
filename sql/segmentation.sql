-- ============================================================
-- Notivo Analytics Platform — User & Workspace Segmentation SQL
-- ============================================================
-- RFM segmentation, behavioral clustering, power user
-- identification, and at-risk detection.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. RFM SEGMENTATION (Recency, Frequency, Monetary)
--
-- Classic framework applied to workspace (company) level.
-- Segments used to prioritize CSM outreach, marketing,
-- and product decisions.
-- ─────────────────────────────────────────────────────────────
WITH rfm_base AS (
    SELECT
        w.workspace_id,
        w.workspace_name,
        -- Recency: days since last session
        DATE_PART('day', NOW() - MAX(s.started_at))       AS recency_days,
        -- Frequency: sessions in last 30 days
        COUNT(CASE WHEN s.started_at >= NOW() - INTERVAL '30 days'
                   THEN s.session_id END)                 AS frequency_30d,
        -- Monetary: MRR (current)
        COALESCE(SUM(sub.mrr), 0)                         AS monetary_mrr
    FROM workspaces w
    LEFT JOIN sessions s ON w.workspace_id = s.workspace_id
    LEFT JOIN subscriptions sub
        ON w.workspace_id = sub.workspace_id
        AND sub.status = 'active'
    WHERE w.is_deleted = FALSE
    GROUP BY w.workspace_id, w.workspace_name
),

rfm_scored AS (
    SELECT
        *,
        -- Score each dimension 1-5 using NTILE
        NTILE(5) OVER (ORDER BY recency_days DESC)        AS r_score,   -- lower days = higher score
        NTILE(5) OVER (ORDER BY frequency_30d)            AS f_score,
        NTILE(5) OVER (ORDER BY monetary_mrr)             AS m_score
    FROM rfm_base
),

rfm_classified AS (
    SELECT
        *,
        -- Composite RFM score
        ROUND((r_score + f_score + m_score)::NUMERIC / 3, 2)  AS rfm_avg,
        -- Human-readable segment
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'Promising'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Cant Lose Them'
            WHEN r_score >= 3 AND f_score <= 2 AND m_score <= 2 THEN 'Need Attention'
            WHEN r_score <= 1                                   THEN 'Hibernating'
            ELSE 'Average'
        END                                               AS rfm_segment
    FROM rfm_scored
)

SELECT
    workspace_id,
    workspace_name,
    recency_days,
    frequency_30d,
    monetary_mrr,
    r_score,
    f_score,
    m_score,
    rfm_avg,
    rfm_segment
FROM rfm_classified
ORDER BY rfm_avg DESC;


-- ─────────────────────────────────────────────────────────────
-- 2. POWER USER IDENTIFICATION
--
-- Power users: top decile by engagement + feature breadth.
-- These users are product advocates and expansion candidates.
-- ─────────────────────────────────────────────────────────────
WITH user_engagement AS (
    SELECT
        u.user_id,
        u.workspace_id,
        u.user_role,
        -- Session frequency
        COUNT(DISTINCT DATE_TRUNC('day', s.started_at))   AS active_days_30d,
        -- Total events
        COUNT(e.event_id)                                 AS event_count_30d,
        -- Feature breadth
        COUNT(DISTINCT fu.feature_name)                   AS distinct_features_used,
        -- Collaboration score (invites + comments + shares)
        COUNT(CASE WHEN e.event_name IN ('teammate_invited', 'comment_added',
                                          'doc_shared', 'page_shared')
                   THEN 1 END)                            AS collaboration_actions,
        -- Creation score
        COUNT(CASE WHEN e.event_name IN ('doc_created', 'task_created',
                                          'project_created', 'template_created')
                   THEN 1 END)                            AS creation_actions
    FROM users u
    LEFT JOIN sessions s
        ON u.user_id = s.user_id
        AND s.started_at >= NOW() - INTERVAL '30 days'
    LEFT JOIN events e
        ON u.user_id = e.user_id
        AND e.occurred_at >= NOW() - INTERVAL '30 days'
    LEFT JOIN feature_usage fu ON u.user_id = fu.user_id
    WHERE u.is_deleted = FALSE
    GROUP BY u.user_id, u.workspace_id, u.user_role
),

engagement_percentiles AS (
    SELECT
        *,
        PERCENT_RANK() OVER (ORDER BY active_days_30d)    AS active_days_pct,
        PERCENT_RANK() OVER (ORDER BY event_count_30d)    AS events_pct,
        PERCENT_RANK() OVER (ORDER BY distinct_features_used) AS features_pct,
        -- Composite engagement score (weighted)
        (active_days_30d * 0.3 + event_count_30d * 0.4 +
         distinct_features_used * 10 * 0.3)               AS engagement_score
    FROM user_engagement
)

SELECT
    user_id,
    workspace_id,
    user_role,
    active_days_30d,
    event_count_30d,
    distinct_features_used,
    collaboration_actions,
    creation_actions,
    ROUND(engagement_score, 1)                            AS engagement_score,
    CASE
        WHEN active_days_pct >= 0.90 AND features_pct >= 0.75 THEN 'Power User'
        WHEN active_days_pct >= 0.70 AND features_pct >= 0.50 THEN 'Core User'
        WHEN active_days_pct >= 0.40                          THEN 'Casual User'
        WHEN active_days_pct > 0                              THEN 'Light User'
        ELSE 'Inactive'
    END                                                   AS user_segment
FROM engagement_percentiles
ORDER BY engagement_score DESC;


-- ─────────────────────────────────────────────────────────────
-- 3. AT-RISK WORKSPACE DETECTION
--
-- Workspaces showing early churn signals. Used by CSM team
-- for proactive intervention. Based on multi-factor scoring.
-- ─────────────────────────────────────────────────────────────
WITH workspace_health_signals AS (
    SELECT
        w.workspace_id,
        w.workspace_name,
        sub.plan_id,
        sub.mrr,
        sub.seat_count,
        -- Signal 1: Session frequency decline
        COUNT(CASE WHEN s.started_at >= NOW() - INTERVAL '14 days'
                   THEN s.session_id END)                 AS sessions_last_14d,
        COUNT(CASE WHEN s.started_at BETWEEN NOW() - INTERVAL '28 days'
                                         AND NOW() - INTERVAL '14 days'
                   THEN s.session_id END)                 AS sessions_prior_14d,
        -- Signal 2: Days since last session
        DATE_PART('day', NOW() - MAX(s.started_at))       AS days_since_last_session,
        -- Signal 3: Support tickets with negative sentiment
        COUNT(CASE WHEN st.sentiment = 'negative'
                        AND st.created_at >= NOW() - INTERVAL '30 days'
                   THEN st.ticket_id END)                 AS negative_tickets_30d,
        -- Signal 4: Feature usage drop (compare 30d to prior 30d)
        SUM(fu.usage_count_30d)                           AS feature_usage_30d,
        -- Signal 5: Failed payment
        COUNT(CASE WHEN i.status = 'failed'
                        AND i.issued_at >= NOW() - INTERVAL '30 days'
                   THEN i.invoice_id END)                 AS failed_payments_30d
    FROM workspaces w
    JOIN subscriptions sub ON w.workspace_id = sub.workspace_id
        AND sub.status = 'active'
    LEFT JOIN sessions s ON w.workspace_id = s.workspace_id
    LEFT JOIN support_tickets st ON w.workspace_id = st.workspace_id
    LEFT JOIN feature_usage fu ON w.workspace_id = fu.workspace_id
    LEFT JOIN invoices i ON w.workspace_id = i.workspace_id
    WHERE w.is_deleted = FALSE
    GROUP BY w.workspace_id, w.workspace_name, sub.plan_id, sub.mrr, sub.seat_count
),

risk_scoring AS (
    SELECT
        *,
        -- Session trend (negative = declining)
        CASE WHEN sessions_prior_14d > 0
             THEN (sessions_last_14d - sessions_prior_14d)::NUMERIC / sessions_prior_14d
             ELSE 0
        END                                               AS session_trend_pct,
        -- Compute risk score (0-100)
        LEAST(100,
            -- Recency risk (up to 40 pts)
            CASE
                WHEN days_since_last_session > 21  THEN 40
                WHEN days_since_last_session > 14  THEN 25
                WHEN days_since_last_session > 7   THEN 10
                ELSE 0
            END
            -- Usage decline risk (up to 30 pts)
            + CASE
                WHEN sessions_last_14d = 0                            THEN 30
                WHEN sessions_last_14d < sessions_prior_14d * 0.5     THEN 20
                WHEN sessions_last_14d < sessions_prior_14d * 0.75    THEN 10
                ELSE 0
              END
            -- Support/payment risk (up to 30 pts)
            + LEAST(15, negative_tickets_30d * 5)
            + LEAST(15, failed_payments_30d * 15)
        )                                                 AS churn_risk_score
    FROM workspace_health_signals
)

SELECT
    workspace_id,
    workspace_name,
    plan_id,
    mrr,
    seat_count,
    days_since_last_session,
    sessions_last_14d,
    ROUND(session_trend_pct * 100, 1)                     AS session_trend_pct,
    negative_tickets_30d,
    failed_payments_30d,
    churn_risk_score,
    CASE
        WHEN churn_risk_score >= 70 THEN 'High Risk'
        WHEN churn_risk_score >= 40 THEN 'Medium Risk'
        ELSE 'Healthy'
    END                                                   AS risk_tier,
    -- Expected MRR loss if they churn
    mrr                                                   AS mrr_at_risk
FROM risk_scoring
WHERE churn_risk_score >= 40
ORDER BY churn_risk_score DESC, mrr DESC;
