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

SELECT *
FROM (
	SELECT 
		base.user_id
		, base.plan
		, st.mapped_status AS status
		, base.start_date
		, COALESCE(base.end_date, '9999-12-31') AS end_date
		, base.last_updated
        , gen_random_uuid() AS dw_id
        , CURRENT_USER AS dw_modified_by
        , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_modified_timestamp_myt
        , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_write_timestamp_myt
        , dw_source_write_timestamp_myt AS dw_source_write_timestamp_myt
        , user_id AS dw_source_id
        , FALSE AS dw_is_deleted
		, ROW_NUMBER() OVER (PARTITION BY base.user_id ORDER BY base.last_updated DESC) AS rn
	FROM bronze_rapsodo.internal_subscriptions base
	LEFT JOIN common_mapping.status_mapping st ON base.status = st.original_status
) AS sub
WHERE rn = 1
