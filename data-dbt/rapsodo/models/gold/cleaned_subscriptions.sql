{{ config(
    schema='gold_rapsodo',
    materialized='table',
    incremental_strategy='delete+insert',
    sort='user_id',
    diststyle='even',
    alias='cleaned_subscriptions',
    on_schema_change='append_new_columns',
    tags = ['gold_rapsodo']
) 
}}

WITH late_billing AS (
SELECT 
	internal.user_id AS internal_user_id
	, (internal.start_date::timestamp) AT TIME ZONE 'Asia/Kuala_Lumpur' AS interal_start_date
	, billing.user_id AS billing_user_id
	, (billing.billing_start_date::timestamp) AT TIME ZONE 'Asia/Kuala_Lumpur'AS billing_start_date
	, COALESCE(((billing.billing_start_date::timestamp) AT TIME ZONE 'Asia/Kuala_Lumpur') - ((internal.start_date::timestamp) AT TIME ZONE 'Asia/Kuala_Lumpur'), INTERVAL '0' ) AS start_date_diff
FROM silver_rapsodo.internal_subscriptions internal
INNER JOIN silver_rapsodo.billing_subscriptions billing ON internal.user_id = billing.user_id
)
SELECT 
	internal.user_id
	, internal.plan
	, internal.status AS internal_status
	, COALESCE(billing.status, '-') AS billing_status
	, CASE
		WHEN internal.status != billing.status THEN (internal.status || '_' || billing.status) 
		ELSE '-'
	END AS mismatched_status
	, CASE
		WHEN (internal.status = 'CANCELED' OR billing.status = 'CANCELED') THEN true
		ELSE false
	END AS is_canceled_subscription
	, internal.start_date AS interal_start_date
	, internal.end_date AS internal_end_date
	, COALESCE(billing.billing_start_date, '-') AS billing_start_date
	, COALESCE(billing.billing_end_date, '-') AS billing_end_date
	, internal.last_updated AS internal_last_updated
	, COALESCE(billing.canceled_at, '-') AS billing_canceled_at
	, COALESCE(lb.start_date_diff, INTERVAL '360000 seconds') AS start_date_diff -- 100:00:00
	, CASE
		WHEN EXTRACT(EPOCH FROM lb.start_date_diff) = 0 THEN 'PAY_ON_TIME'
		WHEN EXTRACT(EPOCH FROM lb.start_date_diff) < 0 THEN 'LATE_ACTIVE_SUBSCRIPTION'
		WHEN EXTRACT(EPOCH FROM lb.start_date_diff) > 0 THEN 'LATE_PAYMENTS'
        ELSE '-'
	END AS is_late_billing
	, CASE
		WHEN internal.end_date::date != billing.billing_end_date::date THEN true
		ELSE false
	END AS mistached_end_date
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
FROM silver_rapsodo.internal_subscriptions internal
LEFT JOIN silver_rapsodo.billing_subscriptions billing ON internal.user_id = billing.user_id
LEFT JOIN late_billing lb ON internal.user_id = lb.internal_user_id
ORDER BY internal.user_id ASC
