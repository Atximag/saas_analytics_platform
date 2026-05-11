-- ============================================================
-- Notivo Analytics Platform — Core Data Model
-- ============================================================
-- This schema reflects a realistic B2B SaaS product with:
--   - Multi-tenant workspace architecture
--   - Product-led growth motion (freemium → paid)
--   - Seat-based subscription billing
--   - Event tracking for product analytics
-- ============================================================

-- ─────────────────────────────────────────────────────────────
-- DIMENSION: Subscription Plans
-- ─────────────────────────────────────────────────────────────
CREATE TABLE subscription_plans (
    plan_id         VARCHAR(20)     PRIMARY KEY,
    plan_name       VARCHAR(50)     NOT NULL,           -- Free, Pro, Business, Enterprise
    billing_cycle   VARCHAR(10)     NOT NULL,           -- monthly, annual
    price_per_seat  NUMERIC(10,2)   NOT NULL,
    max_seats       INTEGER,                            -- NULL = unlimited
    features        JSONB,                              -- feature flags per plan
    is_active       BOOLEAN         DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ─────────────────────────────────────────────────────────────
-- DIMENSION: Marketing Channels
-- ─────────────────────────────────────────────────────────────
CREATE TABLE marketing_channels (
    channel_id      SERIAL          PRIMARY KEY,
    channel_name    VARCHAR(50)     NOT NULL,           -- organic_search, paid_social, referral, etc.
    channel_type    VARCHAR(30)     NOT NULL,           -- paid, organic, viral, direct
    cac_estimate    NUMERIC(10,2),                      -- blended CAC estimate per channel
    is_active       BOOLEAN         DEFAULT TRUE
);

-- ─────────────────────────────────────────────────────────────
-- CORE: Workspaces (Tenant-level entity)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE workspaces (
    workspace_id        UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_name      VARCHAR(255)    NOT NULL,
    company_size        VARCHAR(20),                    -- solo, startup (2-10), smb (11-100), mid (101-500), enterprise (500+)
    industry            VARCHAR(50),
    country_code        CHAR(2),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    trial_ends_at       TIMESTAMPTZ,
    plan_id             VARCHAR(20)     REFERENCES subscription_plans(plan_id),
    channel_id          INTEGER         REFERENCES marketing_channels(channel_id),
    is_deleted          BOOLEAN         DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ
);

CREATE INDEX idx_workspaces_plan ON workspaces(plan_id);
CREATE INDEX idx_workspaces_created ON workspaces(created_at);
CREATE INDEX idx_workspaces_channel ON workspaces(channel_id);

-- ─────────────────────────────────────────────────────────────
-- CORE: Users
-- ─────────────────────────────────────────────────────────────
CREATE TABLE users (
    user_id             UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    email               VARCHAR(320)    NOT NULL,
    user_role           VARCHAR(20)     NOT NULL DEFAULT 'member',  -- owner, admin, member, viewer
    signup_source       VARCHAR(50),    -- direct, invite, sso, oauth_google, oauth_github
    country_code        CHAR(2),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    last_active_at      TIMESTAMPTZ,
    is_deleted          BOOLEAN         DEFAULT FALSE,
    deleted_at          TIMESTAMPTZ,
    UNIQUE(workspace_id, email)
);

CREATE INDEX idx_users_workspace ON users(workspace_id);
CREATE INDEX idx_users_created ON users(created_at);
CREATE INDEX idx_users_last_active ON users(last_active_at);

-- ─────────────────────────────────────────────────────────────
-- CORE: Subscriptions
-- ─────────────────────────────────────────────────────────────
CREATE TABLE subscriptions (
    subscription_id     UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    plan_id             VARCHAR(20)     NOT NULL REFERENCES subscription_plans(plan_id),
    status              VARCHAR(20)     NOT NULL,       -- active, trialing, past_due, canceled, paused
    seat_count          INTEGER         NOT NULL DEFAULT 1,
    mrr                 NUMERIC(12,2)   NOT NULL DEFAULT 0,  -- monthly recurring revenue for this sub
    started_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    trial_started_at    TIMESTAMPTZ,
    trial_ended_at      TIMESTAMPTZ,
    canceled_at         TIMESTAMPTZ,
    cancel_reason       VARCHAR(100),                   -- price, missing_feature, competitor, no_need, etc.
    current_period_start TIMESTAMPTZ,
    current_period_end   TIMESTAMPTZ,
    is_annual           BOOLEAN         DEFAULT FALSE,
    discount_pct        NUMERIC(5,2)    DEFAULT 0
);

CREATE INDEX idx_subscriptions_workspace ON subscriptions(workspace_id);
CREATE INDEX idx_subscriptions_status ON subscriptions(status);
CREATE INDEX idx_subscriptions_plan ON subscriptions(plan_id);
CREATE INDEX idx_subscriptions_started ON subscriptions(started_at);

-- ─────────────────────────────────────────────────────────────
-- CORE: Payments & Invoices
-- ─────────────────────────────────────────────────────────────
CREATE TABLE invoices (
    invoice_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id     UUID            NOT NULL REFERENCES subscriptions(subscription_id),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    amount              NUMERIC(12,2)   NOT NULL,
    currency            CHAR(3)         DEFAULT 'USD',
    status              VARCHAR(20)     NOT NULL,       -- paid, failed, pending, refunded, voided
    billing_period_start TIMESTAMPTZ,
    billing_period_end   TIMESTAMPTZ,
    issued_at           TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    paid_at             TIMESTAMPTZ,
    failed_at           TIMESTAMPTZ,
    failure_reason      VARCHAR(100),                   -- card_declined, insufficient_funds, expired_card, etc.
    attempt_count       SMALLINT        DEFAULT 1
);

CREATE INDEX idx_invoices_workspace ON invoices(workspace_id);
CREATE INDEX idx_invoices_subscription ON invoices(subscription_id);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_issued ON invoices(issued_at);

-- ─────────────────────────────────────────────────────────────
-- PRODUCT: Sessions
-- ─────────────────────────────────────────────────────────────
CREATE TABLE sessions (
    session_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES users(user_id),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    started_at          TIMESTAMPTZ     NOT NULL,
    ended_at            TIMESTAMPTZ,
    duration_seconds    INTEGER,
    device_type         VARCHAR(20),    -- desktop, mobile, tablet
    browser             VARCHAR(30),
    os                  VARCHAR(30),
    entry_page          VARCHAR(255),
    page_view_count     INTEGER         DEFAULT 0,
    is_bounce           BOOLEAN         DEFAULT FALSE
);

CREATE INDEX idx_sessions_user ON sessions(user_id);
CREATE INDEX idx_sessions_workspace ON sessions(workspace_id);
CREATE INDEX idx_sessions_started ON sessions(started_at);

-- ─────────────────────────────────────────────────────────────
-- PRODUCT: Events (granular user actions)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE events (
    event_id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID            REFERENCES sessions(session_id),
    user_id             UUID            NOT NULL REFERENCES users(user_id),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    event_name          VARCHAR(100)    NOT NULL,       -- page_viewed, feature_used, doc_created, comment_added, etc.
    event_category      VARCHAR(50),                   -- navigation, engagement, creation, collaboration, settings
    properties          JSONB,                          -- event-specific properties
    occurred_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_events_user ON events(user_id);
CREATE INDEX idx_events_workspace ON events(workspace_id);
CREATE INDEX idx_events_name ON events(event_name);
CREATE INDEX idx_events_occurred ON events(occurred_at);
CREATE INDEX idx_events_occurred_name ON events(occurred_at, event_name);

-- ─────────────────────────────────────────────────────────────
-- PRODUCT: Feature Usage
-- ─────────────────────────────────────────────────────────────
CREATE TABLE feature_usage (
    usage_id            UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID            NOT NULL REFERENCES users(user_id),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    feature_name        VARCHAR(100)    NOT NULL,       -- docs, tasks, kanban, calendar, integrations, api, automations
    first_used_at       TIMESTAMPTZ     NOT NULL,
    last_used_at        TIMESTAMPTZ     NOT NULL,
    usage_count_7d      INTEGER         DEFAULT 0,
    usage_count_30d     INTEGER         DEFAULT 0,
    usage_count_total   INTEGER         DEFAULT 0,
    depth_score         NUMERIC(5,2),                   -- 0-100, how deeply the feature is used
    UNIQUE(user_id, feature_name)
);

CREATE INDEX idx_feature_usage_user ON feature_usage(user_id);
CREATE INDEX idx_feature_usage_workspace ON feature_usage(workspace_id);
CREATE INDEX idx_feature_usage_feature ON feature_usage(feature_name);

-- ─────────────────────────────────────────────────────────────
-- PRODUCT: Onboarding Steps
-- ─────────────────────────────────────────────────────────────
CREATE TABLE onboarding_steps (
    step_id             SERIAL          PRIMARY KEY,
    user_id             UUID            NOT NULL REFERENCES users(user_id),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    step_name           VARCHAR(100)    NOT NULL,       -- profile_setup, invite_teammate, create_doc, connect_integration, set_notifications
    step_order          SMALLINT        NOT NULL,
    completed_at        TIMESTAMPTZ,
    skipped_at          TIMESTAMPTZ,
    is_completed        BOOLEAN         DEFAULT FALSE,
    time_to_complete_s  INTEGER,                        -- seconds from signup to step completion
    UNIQUE(user_id, step_name)
);

CREATE INDEX idx_onboarding_user ON onboarding_steps(user_id);
CREATE INDEX idx_onboarding_workspace ON onboarding_steps(workspace_id);

-- ─────────────────────────────────────────────────────────────
-- SUPPORT: Tickets
-- ─────────────────────────────────────────────────────────────
CREATE TABLE support_tickets (
    ticket_id           UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    user_id             UUID            REFERENCES users(user_id),
    category            VARCHAR(50),                   -- billing, bug, feature_request, how_to, account
    priority            VARCHAR(10),                   -- low, medium, high, urgent
    status              VARCHAR(20)     NOT NULL,       -- open, pending, resolved, closed
    sentiment           VARCHAR(10),                   -- positive, neutral, negative
    csat_score          SMALLINT,                       -- 1-5
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    resolved_at         TIMESTAMPTZ,
    resolution_time_h   NUMERIC(8,2)
);

CREATE INDEX idx_tickets_workspace ON support_tickets(workspace_id);
CREATE INDEX idx_tickets_created ON support_tickets(created_at);

-- ─────────────────────────────────────────────────────────────
-- GROWTH: Experiments (A/B Tests)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE experiments (
    experiment_id       SERIAL          PRIMARY KEY,
    experiment_name     VARCHAR(100)    NOT NULL,
    hypothesis          TEXT,
    status              VARCHAR(20)     NOT NULL,       -- draft, running, paused, concluded
    variant_control     VARCHAR(50)     DEFAULT 'control',
    variant_treatment   VARCHAR(50),
    primary_metric      VARCHAR(100),                   -- e.g., activation_rate, trial_conversion_rate
    started_at          TIMESTAMPTZ,
    ended_at            TIMESTAMPTZ,
    winner              VARCHAR(50),
    lift_observed       NUMERIC(8,4),                   -- % lift on primary metric
    p_value             NUMERIC(8,6),
    confidence_level    NUMERIC(5,2)    DEFAULT 95.0,
    notes               TEXT
);

-- ─────────────────────────────────────────────────────────────
-- GROWTH: Experiment Assignments
-- ─────────────────────────────────────────────────────────────
CREATE TABLE experiment_assignments (
    assignment_id       SERIAL          PRIMARY KEY,
    experiment_id       INTEGER         NOT NULL REFERENCES experiments(experiment_id),
    user_id             UUID            NOT NULL REFERENCES users(user_id),
    variant             VARCHAR(50)     NOT NULL,
    assigned_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    converted           BOOLEAN         DEFAULT FALSE,
    converted_at        TIMESTAMPTZ,
    UNIQUE(experiment_id, user_id)
);

CREATE INDEX idx_exp_assign_experiment ON experiment_assignments(experiment_id);
CREATE INDEX idx_exp_assign_user ON experiment_assignments(user_id);

-- ─────────────────────────────────────────────────────────────
-- ANALYTICS: Cancellations (enriched churn data)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE cancellations (
    cancellation_id     UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id     UUID            NOT NULL REFERENCES subscriptions(subscription_id),
    workspace_id        UUID            NOT NULL REFERENCES workspaces(workspace_id),
    canceled_at         TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    reason_category     VARCHAR(50),                   -- price, missing_features, low_usage, competitor, budget_cut, technical_issues
    reason_detail       TEXT,
    exit_survey_score   SMALLINT,                       -- 1-10, likelihood to return
    mrr_lost            NUMERIC(12,2),
    seat_count_lost     INTEGER,
    tenure_months       NUMERIC(8,2),                   -- months as paying customer before churn
    was_at_risk         BOOLEAN         DEFAULT FALSE,  -- flagged by churn model before cancellation
    intervention_attempted BOOLEAN      DEFAULT FALSE
);

CREATE INDEX idx_cancellations_workspace ON cancellations(workspace_id);
CREATE INDEX idx_cancellations_canceled ON cancellations(canceled_at);
