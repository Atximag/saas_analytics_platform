-- ============================================================
-- dbt staging model: stg_users
-- Cleans and standardizes the raw users table.
-- Applies business rules for what constitutes a "real" user.
-- ============================================================

{{ config(
    materialized='view',
    tags=['staging', 'daily']
) }}

WITH source AS (
    SELECT * FROM {{ source('notivo_raw', 'users') }}
),

renamed AS (
    SELECT
        user_id                                         AS user_id,
        workspace_id                                    AS workspace_id,
        LOWER(TRIM(email))                              AS email,
        LOWER(user_role)                                AS user_role,
        LOWER(signup_source)                            AS signup_source,
        UPPER(country_code)                             AS country_code,
        created_at                                      AS created_at,
        last_active_at                                  AS last_active_at,
        is_deleted                                      AS is_deleted,
        deleted_at                                      AS deleted_at,
        -- Derived fields
        DATE_TRUNC('month', created_at)::DATE           AS signup_month,
        DATE_TRUNC('week', created_at)::DATE            AS signup_week,
        -- Internal/bot account filter
        email NOT LIKE '%@notivo.io%'
        AND email NOT LIKE '%@test.com%'
        AND user_id NOT IN (
            SELECT user_id FROM {{ ref('dim_internal_users') }}
        )                                               AS is_external_user
    FROM source
    WHERE user_id IS NOT NULL
      AND workspace_id IS NOT NULL
)

SELECT * FROM renamed
