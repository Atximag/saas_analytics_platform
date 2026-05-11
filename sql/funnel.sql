-- ============================================================
-- Notivo Analytics Platform — Funnel Analysis SQL
-- ============================================================
-- Conversion funnel analysis from signup to paid conversion.
-- Identifies drop-off points and quantifies revenue impact.
-- ============================================================


-- ─────────────────────────────────────────────────────────────
-- 1. ONBOARDING FUNNEL (step-by-step conversion)
--
-- The 5-step Notivo onboarding flow:
--   Step 1: profile_setup
--   Step 2: invite_teammate
--   Step 3: create_doc
--   Step 4: connect_integration
--   Step 5: set_notifications
--
-- Completion of all 5 steps is the "activation" event.
-- ─────────────────────────────────────────────────────────────
WITH signup_cohort AS (
    SELECT
        user_id,
        workspace_id,
        created_at
    FROM users
    WHERE is_deleted = FALSE
      AND created_at >= CURRENT_DATE - INTERVAL '90 days'
),

step_completions AS (
    SELECT
        sc.user_id,
        MAX(CASE WHEN os.step_name = 'profile_setup'        AND os.is_completed THEN 1 ELSE 0 END) AS step1,
        MAX(CASE WHEN os.step_name = 'invite_teammate'      AND os.is_completed THEN 1 ELSE 0 END) AS step2,
        MAX(CASE WHEN os.step_name = 'create_doc'           AND os.is_completed THEN 1 ELSE 0 END) AS step3,
        MAX(CASE WHEN os.step_name = 'connect_integration'  AND os.is_completed THEN 1 ELSE 0 END) AS step4,
        MAX(CASE WHEN os.step_name = 'set_notifications'    AND os.is_completed THEN 1 ELSE 0 END) AS step5
    FROM signup_cohort sc
    LEFT JOIN onboarding_steps os ON sc.user_id = os.user_id
    GROUP BY sc.user_id
),

funnel_counts AS (
    SELECT
        COUNT(*)                                          AS step0_signed_up,
        SUM(step1)                                        AS step1_profile,
        SUM(CASE WHEN step1=1 AND step2=1 THEN 1 ELSE 0 END) AS step2_invited,
        SUM(CASE WHEN step1=1 AND step2=1 AND step3=1 THEN 1 ELSE 0 END) AS step3_created_doc,
        SUM(CASE WHEN step1=1 AND step2=1 AND step3=1 AND step4=1 THEN 1 ELSE 0 END) AS step4_integrated,
        SUM(CASE WHEN step1=1 AND step2=1 AND step3=1 AND step4=1 AND step5=1 THEN 1 ELSE 0 END) AS step5_activated
    FROM step_completions
)

SELECT
    'signed_up'         AS funnel_step,
    1                   AS step_order,
    step0_signed_up     AS users,
    100.0               AS pct_of_top,
    NULL::NUMERIC       AS step_conversion_pct
FROM funnel_counts

UNION ALL SELECT
    'profile_setup', 2, step1_profile,
    ROUND(step1_profile::NUMERIC / NULLIF(step0_signed_up, 0) * 100, 1),
    ROUND(step1_profile::NUMERIC / NULLIF(step0_signed_up, 0) * 100, 1)
FROM funnel_counts

UNION ALL SELECT
    'invite_teammate', 3, step2_invited,
    ROUND(step2_invited::NUMERIC / NULLIF(step0_signed_up, 0) * 100, 1),
    ROUND(step2_invited::NUMERIC / NULLIF(step1_profile, 0) * 100, 1)
FROM funnel_counts

UNION ALL SELECT
    'create_doc', 4, step3_created_doc,
    ROUND(step3_created_doc::NUMERIC / NULLIF(step0_signed_up, 0) * 100, 1),
    ROUND(step3_created_doc::NUMERIC / NULLIF(step2_invited, 0) * 100, 1)
FROM funnel_counts

UNION ALL SELECT
    'connect_integration', 5, step4_integrated,
    ROUND(step4_integrated::NUMERIC / NULLIF(step0_signed_up, 0) * 100, 1),
    ROUND(step4_integrated::NUMERIC / NULLIF(step3_created_doc, 0) * 100, 1)
FROM funnel_counts

UNION ALL SELECT
    'fully_activated', 6, step5_activated,
    ROUND(step5_activated::NUMERIC / NULLIF(step0_signed_up, 0) * 100, 1),
    ROUND(step5_activated::NUMERIC / NULLIF(step4_integrated, 0) * 100, 1)
FROM funnel_counts

ORDER BY step_order;


-- ─────────────────────────────────────────────────────────────
-- 2. FREE-TO-PAID CONVERSION FUNNEL
--
-- Tracks the journey from free signup to paid subscriber.
-- Segments by acquisition channel to show which sources
-- produce highest-quality (highest-converting) signups.
-- ─────────────────────────────────────────────────────────────
WITH free_users AS (
    SELECT
        u.user_id,
        w.workspace_id,
        mc.channel_name,
        u.created_at                                      AS signup_date,
        -- Did they complete onboarding?
        (SELECT COUNT(*) FROM onboarding_steps os
         WHERE os.user_id = u.user_id AND os.is_completed = TRUE) AS steps_completed,
        -- Did they become a paid subscriber?
        MIN(s.started_at)                                 AS first_paid_date,
        MIN(s.plan_id)                                    AS first_paid_plan
    FROM users u
    JOIN workspaces w ON u.workspace_id = w.workspace_id
    LEFT JOIN marketing_channels mc ON w.channel_id = mc.channel_id
    LEFT JOIN subscriptions s
        ON w.workspace_id = s.workspace_id
        AND s.plan_id != 'free'
        AND s.status IN ('active', 'canceled', 'past_due')
    WHERE u.is_deleted = FALSE
    GROUP BY u.user_id, w.workspace_id, mc.channel_name, u.created_at
)

SELECT
    channel_name,
    COUNT(*)                                              AS total_signups,
    SUM(CASE WHEN steps_completed >= 1 THEN 1 ELSE 0 END) AS completed_step1,
    SUM(CASE WHEN steps_completed >= 3 THEN 1 ELSE 0 END) AS completed_onboarding,
    SUM(CASE WHEN first_paid_date IS NOT NULL THEN 1 ELSE 0 END)
                                                          AS converted_to_paid,
    -- Conversion rates
    ROUND(SUM(CASE WHEN steps_completed >= 3 THEN 1 ELSE 0 END)::NUMERIC
          / NULLIF(COUNT(*), 0) * 100, 1)                 AS onboarding_completion_pct,
    ROUND(SUM(CASE WHEN first_paid_date IS NOT NULL THEN 1 ELSE 0 END)::NUMERIC
          / NULLIF(COUNT(*), 0) * 100, 1)                 AS signup_to_paid_pct,
    -- Median days to convert
    PERCENTILE_CONT(0.5) WITHIN GROUP (
        ORDER BY DATE_PART('day', first_paid_date - signup_date)
    )                                                     AS median_days_to_convert
FROM free_users
GROUP BY channel_name
ORDER BY signup_to_paid_pct DESC NULLS LAST;


-- ─────────────────────────────────────────────────────────────
-- 3. UPGRADE FUNNEL (Pro → Business → Enterprise)
--
-- Tracks expansion within existing paid customers.
-- ─────────────────────────────────────────────────────────────
WITH plan_transitions AS (
    SELECT
        s1.workspace_id,
        s1.plan_id                                        AS from_plan,
        s2.plan_id                                        AS to_plan,
        s2.started_at                                     AS upgrade_date,
        DATE_PART('month', AGE(s2.started_at, s1.started_at))
                                                          AS months_before_upgrade,
        s2.mrr - s1.mrr                                   AS mrr_expansion
    FROM subscriptions s1
    JOIN subscriptions s2
        ON s1.workspace_id = s2.workspace_id
        AND s2.started_at > s1.started_at
        -- Only consider upgrades (higher plan tier)
        AND s2.plan_id IN ('pro', 'business', 'enterprise')
    -- Avoid counting intermediate plans (get only direct pairs)
    WHERE NOT EXISTS (
        SELECT 1 FROM subscriptions s3
        WHERE s3.workspace_id = s1.workspace_id
          AND s3.started_at > s1.started_at
          AND s3.started_at < s2.started_at
    )
)

SELECT
    CONCAT(from_plan, ' → ', to_plan)                    AS upgrade_path,
    COUNT(*)                                              AS upgrade_count,
    ROUND(AVG(months_before_upgrade), 1)                  AS avg_months_to_upgrade,
    ROUND(AVG(mrr_expansion), 0)                          AS avg_mrr_expansion,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY months_before_upgrade)::NUMERIC, 1)
                                                          AS median_months_to_upgrade
FROM plan_transitions
GROUP BY CONCAT(from_plan, ' → ', to_plan)
ORDER BY upgrade_count DESC;


-- ─────────────────────────────────────────────────────────────
-- 4. TIME-TO-VALUE ANALYSIS
--
-- Measures how quickly users reach their "aha moment" —
-- defined as completing their first meaningful action
-- (creating a doc, inviting a team member, etc.)
-- ─────────────────────────────────────────────────────────────
WITH user_ttv AS (
    SELECT
        u.user_id,
        u.created_at                                      AS signup_at,
        -- First meaningful action (any of these events)
        MIN(e.occurred_at)                                AS first_value_moment,
        MIN(e.event_name)                                 AS first_value_event,
        DATE_PART('hour', MIN(e.occurred_at) - u.created_at)
                                                          AS hours_to_first_value
    FROM users u
    LEFT JOIN events e
        ON u.user_id = e.user_id
        AND e.event_name IN ('doc_created', 'task_created', 'teammate_invited',
                             'integration_connected', 'comment_added')
    WHERE u.is_deleted = FALSE
    GROUP BY u.user_id, u.created_at
),

ttv_with_conversion AS (
    SELECT
        ttv.*,
        CASE WHEN s.subscription_id IS NOT NULL THEN TRUE ELSE FALSE END AS converted_to_paid
    FROM user_ttv ttv
    LEFT JOIN subscriptions s
        ON ttv.user_id IN (
            SELECT user_id FROM users u2
            WHERE u2.workspace_id = s.workspace_id
        )
        AND s.plan_id != 'free'
)

SELECT
    -- Bucket users by time to first value
    CASE
        WHEN hours_to_first_value < 1   THEN '< 1 hour'
        WHEN hours_to_first_value < 24  THEN '1-24 hours'
        WHEN hours_to_first_value < 72  THEN '1-3 days'
        WHEN hours_to_first_value < 168 THEN '3-7 days'
        WHEN hours_to_first_value IS NULL THEN 'never_activated'
        ELSE '> 7 days'
    END                                                   AS ttv_bucket,
    COUNT(*)                                              AS users,
    SUM(CASE WHEN converted_to_paid THEN 1 ELSE 0 END)   AS converted_to_paid,
    ROUND(
        SUM(CASE WHEN converted_to_paid THEN 1 ELSE 0 END)::NUMERIC
        / NULLIF(COUNT(*), 0) * 100,
        1
    )                                                     AS paid_conversion_pct
FROM ttv_with_conversion
GROUP BY
    CASE
        WHEN hours_to_first_value < 1   THEN '< 1 hour'
        WHEN hours_to_first_value < 24  THEN '1-24 hours'
        WHEN hours_to_first_value < 72  THEN '1-3 days'
        WHEN hours_to_first_value < 168 THEN '3-7 days'
        WHEN hours_to_first_value IS NULL THEN 'never_activated'
        ELSE '> 7 days'
    END
ORDER BY paid_conversion_pct DESC;
