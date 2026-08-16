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
select user_id, activation_speed, activation_timeliness
from start_date_timestamp_diffs
where (activation_speed || '__' || activation_timeliness) != 'same_day_activate__reasonable_timeline'