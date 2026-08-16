{{ config(
    schema='silver_rapsodo',
    materialized='table',
    incremental_strategy='delete+insert',
    sort='user_id',
    diststyle='even',
    alias='internal_subscriptions',
    on_schema_change='append_new_columns',
    tags = ['silver_rapsodo']
) 
}}

WITH duplicated_internal_user_id AS (
    SELECT 
        DISTINCT user_id
        , CASE WHEN COUNT(*) OVER(PARTITION BY user_id) > 1 THEN 'Duplicate' ELSE 'Unique' END AS duplicate_internal_record
    FROM bronze_rapsodo.internal_subscriptions
    -- detect_duplicates
)
SELECT 
    user_id
    , plan
    , status
    , start_date
    , end_date
    , last_updated
    , is_duplicated
    , dw_id
    , dw_modified_by
    , dw_modified_timestamp_myt
    , dw_write_timestamp_myt
    , dw_source_write_timestamp_myt
    , dw_source_id
    , dw_is_deleted
FROM (
	SELECT 
		base.user_id
		, base.plan
		, st.mapped_status AS status -- standardize_status
		, base.start_date
		, COALESCE(base.end_date, '9999-12-31') AS end_date -- fill_null_values
		, base.last_updated
        , CASE
            WHEN di.duplicate_internal_record = 'Duplicate' THEN true
            ELSE false
        END AS is_duplicated
        , gen_random_uuid() AS dw_id
        , CURRENT_USER AS dw_modified_by
        , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_modified_timestamp_myt
        , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_write_timestamp_myt
        , dw_source_write_timestamp_myt AS dw_source_write_timestamp_myt
        , base.user_id AS dw_source_id
        , FALSE AS dw_is_deleted
		, ROW_NUMBER() OVER (PARTITION BY base.user_id ORDER BY base.last_updated DESC) AS rn
	FROM bronze_rapsodo.internal_subscriptions base
	LEFT JOIN common_mapping.status_mapping st ON base.status = st.original_status -- standardize_status
    LEFT JOIN duplicated_internal_user_id di ON base.user_id = di.user_id -- detect_duplicates
) AS sub
WHERE rn = 1
