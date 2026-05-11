-- ============================================================
-- Notivo Analytics Platform — Staging Models
-- ============================================================
-- Standardize, clean, and type-cast raw source tables.
-- Staging models are views (not tables) — no storage cost,
-- always reflect latest source data.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- stg_workspaces
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW stg_workspaces AS
SELECT
    workspace_id::UUID                                  AS workspace_id,
    TRIM(workspace_name)                                AS workspace_name,
    LOWER(COALESCE(company_size, 'unknown'))             AS company_size,
    LOWER(COALESCE(industry, 'unknown'))                 AS industry,
    UPPER(COALESCE(country_code, 'XX'))                  AS country_code,
    created_at::TIMESTAMPTZ                             AS created_at,
    trial_ends_at::TIMESTAMPTZ                          AS trial_ends_at,
    plan_id                                             AS plan_id,
    channel_id::INTEGER                                 AS channel_id,
    COALESCE(is_deleted, FALSE)                         AS is_deleted,
    deleted_at::TIMESTAMPTZ                             AS deleted_at,
    -- Derived
    DATE_TRUNC('month', created_at)::DATE               AS signup_month,
    DATE_TRUNC('week', created_at)::DATE                AS signup_week,
    DATE_PART('year', created_at)::INTEGER              AS signup_year
FROM workspaces
WHERE workspace_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- stg_subscriptions
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW stg_subscriptions AS
SELECT
    subscription_id::UUID                               AS subscription_id,
    workspace_id::UUID                                  AS workspace_id,
    plan_id                                             AS plan_id,
    LOWER(status)                                       AS status,
    seat_count::INTEGER                                 AS seat_count,
    mrr::NUMERIC                                        AS mrr,
    started_at::TIMESTAMPTZ                             AS started_at,
    trial_started_at::TIMESTAMPTZ                       AS trial_started_at,
    trial_ended_at::TIMESTAMPTZ                         AS trial_ended_at,
    canceled_at::TIMESTAMPTZ                            AS canceled_at,
    LOWER(cancel_reason)                                AS cancel_reason,
    current_period_start::TIMESTAMPTZ                   AS current_period_start,
    current_period_end::TIMESTAMPTZ                     AS current_period_end,
    COALESCE(is_annual, FALSE)                          AS is_annual,
    COALESCE(discount_pct, 0)                           AS discount_pct,
    -- Derived fields
    CASE WHEN canceled_at IS NOT NULL THEN TRUE ELSE FALSE END AS is_churned,
    CASE
        WHEN canceled_at IS NOT NULL
        THEN DATE_PART('month', AGE(canceled_at, started_at))
        ELSE DATE_PART('month', AGE(NOW(), started_at))
    END                                                 AS tenure_months,
    -- MRR with discount applied for analysis
    mrr * (1 - COALESCE(discount_pct, 0) / 100)        AS effective_mrr
FROM subscriptions
WHERE subscription_id IS NOT NULL
  AND workspace_id IS NOT NULL;


-- ─────────────────────────────────────────────────────────────
-- stg_sessions
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW stg_sessions AS
SELECT
    session_id::UUID                                    AS session_id,
    user_id::UUID                                       AS user_id,
    workspace_id::UUID                                  AS workspace_id,
    started_at::TIMESTAMPTZ                             AS started_at,
    ended_at::TIMESTAMPTZ                               AS ended_at,
    GREATEST(duration_seconds::INTEGER, 0)              AS duration_seconds,
    LOWER(COALESCE(device_type, 'unknown'))              AS device_type,
    LOWER(COALESCE(browser, 'unknown'))                  AS browser,
    COALESCE(page_view_count::INTEGER, 1)               AS page_view_count,
    COALESCE(is_bounce, FALSE)                          AS is_bounce,
    -- Derived
    started_at::DATE                                    AS session_date,
    DATE_TRUNC('week', started_at)::DATE                AS session_week,
    DATE_TRUNC('month', started_at)::DATE               AS session_month,
    EXTRACT(HOUR FROM started_at)::INTEGER              AS session_hour,
    EXTRACT(DOW FROM started_at)::INTEGER               AS day_of_week,  -- 0=Sun, 6=Sat
    CASE
        WHEN duration_seconds < 30   THEN 'micro'       -- likely bot or error
        WHEN duration_seconds < 120  THEN 'brief'       -- <2 min
        WHEN duration_seconds < 600  THEN 'short'       -- 2-10 min
        WHEN duration_seconds < 1800 THEN 'medium'      -- 10-30 min
        ELSE 'long'                                     -- >30 min
    END                                                 AS session_duration_bucket
FROM sessions
WHERE session_id IS NOT NULL
  AND user_id IS NOT NULL
  AND started_at IS NOT NULL
  -- Exclude bot/test traffic
  AND duration_seconds > 5
  AND started_at <= NOW();  -- no future timestamps
