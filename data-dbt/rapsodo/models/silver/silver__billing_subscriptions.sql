{{ config(
    schema='silver_rapsodo',
    materialized='table',
    incremental_strategy='delete+insert',
    sort='user_id',
    diststyle='even',
    alias='billing_subscriptions',
    on_schema_change='append_new_columns',
    tags = ['silver_rapsodo']
) 
}}

SELECT
    customer_id AS customer_id
    , plan_name AS plan_name
    , status AS status
    , current_period_start AS current_period_start
    , current_period_end AS current_period_end
    , canceled_at as canceled_at
    , gen_random_uuid() AS dw_id
    , CURRENT_USER AS dw_modified_by
    , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_modified_timestamp_myt
    , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_write_timestamp_myt
    , dw_source_write_timestamp_myt AS dw_source_write_timestamp_myt
    , customer_id AS dw_source_id
    , FALSE AS dw_is_deleted
FROM bronze_rapsodo.billing_subscriptions
