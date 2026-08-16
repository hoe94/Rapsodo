{{ config(
    schema='core_rapsodo',
    materialized='table',
    incremental_strategy='delete+insert',
    sort='user_id',
    diststyle='even',
    alias='cleaned_subscriptions',
    on_schema_change='append_new_columns',
    tags = ['core_rapsodo']
) 
}}

WITH normalized_dates AS (
    SELECT 
        COALESCE(internal.user_id, billing.user_id) AS user_id,
		CASE
			WHEN internal.end_date != '9999-12-31' then internal.start_date::timestamp AT TIME ZONE 'MYT' -- For the subscriptions are canceled, there will be updated timestamp for end_date, therefore we must get start_date::timestamp at time zone 'MYT'
			ELSE internal.last_updated_timestamp
		END AS internal_last_updated_timestamp,
        billing.current_period_start_timestamp AS billing_current_period_start_timestamp
    FROM staging_rapsodo.internal_subscriptions internal
    FULL JOIN staging_rapsodo.billing_subscriptions billing 
        ON internal.user_id = billing.user_id
)
, calculated_diffs AS (
    SELECT 
        user_id,
        COALESCE(internal_last_updated_timestamp, '0001-01-01 00:00:00'::timestamp) AS internal_last_updated_timestamp,
        COALESCE(billing_current_period_start_timestamp, '0001-01-01 00:00:00'::timestamp) AS billing_current_period_start_timestamp,
        CASE 
            WHEN internal_last_updated_timestamp IS NOT NULL AND billing_current_period_start_timestamp IS NOT NULL 
                THEN internal_last_updated_timestamp - billing_current_period_start_timestamp
            ELSE INTERVAL '0 seconds'
        END AS start_date_diff,
        CASE 
            WHEN internal_last_updated_timestamp IS NULL OR billing_current_period_start_timestamp IS NULL THEN '-'
            WHEN internal_last_updated_timestamp < billing_current_period_start_timestamp THEN 'late_payment'
            WHEN internal_last_updated_timestamp::date = billing_current_period_start_timestamp::date THEN 'same_day_activate'
            WHEN internal_last_updated_timestamp::date > billing_current_period_start_timestamp::date THEN 'cross_day_activate'
            ELSE '-'
        END AS activation_speed
    FROM normalized_dates
)
, start_date_timestamp_diffs as ( 
	SELECT 
		user_id,
		internal_last_updated_timestamp,
		billing_current_period_start_timestamp,
		start_date_diff,
		activation_speed,
		CASE 
			WHEN activation_speed = '-' THEN '-'
			WHEN ABS(EXTRACT(EPOCH FROM start_date_diff)) <= 7200 THEN 'reasonable_timeline'
			ELSE 'late_activation'
		END AS activation_timeliness
	FROM calculated_diffs
)
SELECT 
	COALESCE(internal.user_id, billing.user_id) as user_id
	, COALESCE(internal.plan, billing.plan) as plan
	, COALESCE(internal.status, '-') AS internal_status
	, COALESCE(billing.status, '-') AS billing_status
	, CASE
		WHEN internal.status != billing.status THEN (internal.status || '_' || billing.status) 
		ELSE '-'
	END AS mismatched_status
	, CASE
		WHEN (internal.status = 'CANCELED' OR billing.status = 'CANCELED') THEN true
		ELSE false
	END AS is_canceled_subscription
	, COALESCE(internal.start_date, '0001-01-01') AS interal_start_date
	, COALESCE(internal.end_date, '0001-01-01') AS internal_end_date
	, COALESCE(billing.current_period_start_timestamp, '0001-01-01') AS billing_current_period_start_timestamp
	, COALESCE(billing.current_period_end_timestamp, '0001-01-01') AS billing_current_period_end_timestamp
	, COALESCE(internal.last_updated_timestamp, '0001-01-01 00:00:00') AS internal_last_updated_timestamp
	, COALESCE(billing.canceled_at_timestamp, '0001-01-01 00:00:00') AS billing_canceled_at_timestamp
	, COALESCE(td.start_date_diff, INTERVAL '0 seconds') AS start_date_diff
	, COALESCE(td.activation_speed, '-') AS activation_speed
	, COALESCE(td.activation_timeliness, '-') AS activation_timeliness
    , CASE
		WHEN internal.user_id IS NULL AND billing.user_id IS NOT NULL THEN true
		ELSE false
	END AS missing_in_internal
	, CASE
		WHEN internal.user_id IS NOT NULL AND billing.user_id IS NULL THEN TRUE
		ELSE false
	END AS missing_in_billing
	, CASE
		WHEN internal.is_duplicated IS TRUE THEN TRUE
		WHEN internal.is_duplicated IS FALSE THEN FALSE
		ELSE false
	END AS duplicate_internal_record
	, CASE
		WHEN billing.is_duplicated IS TRUE THEN true
		WHEN billing.is_duplicated IS FALSE THEN FALSE
		ELSE false
	END AS duplicate_billing_record
	, gen_random_uuid() AS dw_id
    , CURRENT_USER AS dw_modified_by
    , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_modified_timestamp_myt
    , CURRENT_TIMESTAMP AT TIME ZONE 'MYT' AS dw_write_timestamp_myt
    , COALESCE(internal.user_id, billing.user_id) AS dw_source_id
    , FALSE AS dw_is_deleted
	, CURRENT_DATE AS dw_snapshot_date
FROM staging_rapsodo.internal_subscriptions internal
FULL JOIN staging_rapsodo.billing_subscriptions billing ON internal.user_id = billing.user_id
LEFT JOIN start_date_timestamp_diffs td ON internal.user_id = td.user_id
