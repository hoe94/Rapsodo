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

WITH duplicated_billing_user_id AS (
    SELECT 
        DISTINCT customer_id as user_id
        , CASE WHEN COUNT(*) OVER(PARTITION BY customer_id) > 1 THEN 'Duplicate' ELSE 'Unique' END AS duplicate_billing_record
	FROM bronze_rapsodo.billing_subscriptions
)
SELECT
    base.customer_id AS user_id -- rename_column
	, plan.internal_plan AS plan -- standardize_plan
	, st.mapped_status AS status -- standardize_status
	, base.current_period_start AS billing_start_date -- rename_column
	, base.current_period_end AS billing_end_date -- rename_column
	, COALESCE(base.canceled_at, '9999-12-31 00:00:00') AS canceled_at -- fill_null_values
    , CASE
        WHEN db.duplicate_billing_record = 'Duplicate' THEN true
        ELSE false
    END AS is_duplicated
    , gen_random_uuid() AS dw_id
    , CURRENT_USER AS dw_modified_by
    , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_modified_timestamp_myt
    , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_write_timestamp_myt
    , dw_source_write_timestamp_myt AS dw_source_write_timestamp_myt
    , customer_id AS dw_source_id
    , FALSE AS dw_is_deleted
FROM bronze_rapsodo.billing_subscriptions base
LEFT JOIN duplicated_billing_user_id db ON base.customer_id = db.user_id
LEFT JOIN common_mapping.plan_mapping plan ON base.plan_name = plan.billing_plan -- standardize_plan
LEFT JOIN common_mapping.status_mapping st ON base.status = st.original_status -- standardize_status

