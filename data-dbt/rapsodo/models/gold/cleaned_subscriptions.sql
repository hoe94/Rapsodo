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

WITH updated_internal_subscriptions AS (
SELECT *
FROM (
	SELECT 
		base.user_id
		, base.plan
		, st.mapped_status AS status
		, base.start_date
		, COALESCE(base.end_date, '9999-12-31') AS end_date
		, base.last_updated
		, ROW_NUMBER() OVER (PARTITION BY base.user_id ORDER BY base.last_updated DESC) AS rn
	FROM silver_rapsodo.internal_subscriptions base
	LEFT JOIN common_mapping.status_mapping st ON base.status = st.original_status
) AS sub
WHERE rn = 1
)
, updated_billing_subscriptions AS (
SELECT 
	base.customer_id AS user_id
	, plan.internal_plan AS plan
	, st.mapped_status AS status
	, base.current_period_start AS start_date
	, base.current_period_end AS end_date
	, COALESCE(base.canceled_at, '9999-12-31 00:00:00') AS canceled_at
FROM silver_rapsodo.billing_subscriptions base
INNER JOIN common_mapping.plan_mapping plan ON base.plan_name = plan.billing_plan
LEFT JOIN common_mapping.status_mapping st ON base.status = st.original_status
)
, duplicated_internal_user_id AS (
    SELECT 
        DISTINCT user_id
        , CASE WHEN COUNT(*) OVER(PARTITION BY user_id) > 1 THEN 'Duplicate' ELSE 'Unique' END AS duplicate_internal_record
    FROM silver_rapsodo.internal_subscriptions
)
, duplicated_billing_user_id AS (
    SELECT 
        DISTINCT customer_id as user_id
        , CASE WHEN COUNT(*) OVER(PARTITION BY customer_id) > 1 THEN 'Duplicate' ELSE 'Unique' END AS duplicate_billing_record
	FROM silver_rapsodo.billing_subscriptions
)
, late_billing AS (
SELECT 
	internal.user_id AS internal_user_id
	, (internal.start_date::timestamp) AT TIME ZONE 'Asia/Kuala_Lumpur' AS interal_start_date
	, billing.user_id AS billing_user_id
	, (billing.start_date::timestamp) AT TIME ZONE 'Asia/Kuala_Lumpur'AS billing_start_date
	, COALESCE(((billing.start_date::timestamp) AT TIME ZONE 'Asia/Kuala_Lumpur') - ((internal.start_date::timestamp) AT TIME ZONE 'Asia/Kuala_Lumpur'), INTERVAL '0' ) AS start_date_diff
FROM updated_internal_subscriptions internal
INNER JOIN updated_billing_subscriptions billing ON internal.user_id = billing.user_id
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
	, COALESCE(billing.start_date, '-') AS billing_start_date
	, COALESCE(billing.end_date, '-') AS billing_end_date
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
		WHEN internal.end_date::date != billing.end_date::date THEN true
		ELSE false
	END AS mistached_end_date
    , CASE
		WHEN internal.user_id IS NULL AND billing.user_id IS NOT NULL THEN true
		ELSE false
	END AS missing_in_internal
	, CASE
		WHEN internal.user_id IS NOT NULL AND billing.user_id IS NULL THEN true
		ELSE false
	END AS missing_in_billing
	, CASE
		WHEN di.duplicate_internal_record = 'Duplicate' THEN true
		WHEN di.duplicate_internal_record = 'Unique' THEN false
		ELSE false
	END AS duplicate_internal_record
	, CASE
		WHEN db.duplicate_billing_record = 'Duplicate' THEN true
		WHEN db.duplicate_billing_record = 'Unique' THEN false
		ELSE false
	END AS duplicate_billing_record
FROM updated_internal_subscriptions internal
LEFT JOIN updated_billing_subscriptions billing ON internal.user_id = billing.user_id
LEFT JOIN duplicated_internal_user_id di ON internal.user_id = di.user_id
LEFT JOIN duplicated_billing_user_id db ON internal.user_id = db.user_id
LEFT JOIN late_billing lb ON internal.user_id = lb.internal_user_id
ORDER BY internal.user_id ASC
