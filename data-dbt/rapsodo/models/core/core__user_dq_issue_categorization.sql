{{ config(
    schema='core_rapsodo',
    materialized='table',
    incremental_strategy='delete+insert',
    sort='user_id',
    diststyle='even',
    alias='user_dq_issues_categorization',
    on_schema_change='append_new_columns',
    tags = ['core_rapsodo']
) 
}}

with base as (
SELECT 
    user_id,
    UNNEST(
        ARRAY_REMOVE(
            ARRAY[
                CASE WHEN missing_in_billing is true THEN 'missing_in_billing' END,
                CASE WHEN missing_in_internal is true THEN 'missing_in_internal' END,
                CASE WHEN mismatched_status = '-'  THEN 'status_mismatch' end,
                case when (activation_speed || '__' || activation_timeliness) != 'same_day_activate__reasonable_timeline' then 'timestamp_difference' end,
                CASE WHEN duplicate_billing_record is true THEN 'duplicate_in_billing' end,
                CASE WHEN duplicate_internal_record is true  THEN 'duplicate_in_internal' end
            ], 
            NULL
        )
    ) AS dq_issue
FROM core_rapsodo.cleaned_subscriptions
)
, null_values as (
select 
	user_id
	, 'null_values_in_internal' as dq_issue
from raw_rapsodo.internal_subscriptions
where end_date is null
union
select 
	customer_id
	, 'null_values_in_billing' as dq_issue
from raw_rapsodo.billing_subscriptions
where canceled_at  is null
)
, base_ as (
  select * from (
  select internal.user_id, internal.status, internal.plan, ROW_NUMBER() OVER (PARTITION BY internal.user_id ORDER BY internal.last_updated DESC) AS rn
  from raw_rapsodo.internal_subscriptions internal
  ) as base
  where rn = 1
)
, plan_value_misaligned as (
select coalesce(base.user_id,  billing.customer_id), 'plan_values_misaligned' as dq_issue
from base_ base
full join (select customer_id, plan_name from raw_rapsodo.billing_subscriptions) as billing on base.user_id = billing.customer_id
where base.plan != billing.plan_name or base.user_id is null or billing.customer_id is null
order by coalesce(base.user_id, billing.customer_id) asc
)
, status_values_misaligned as (
select coalesce(base.user_id,  billing.customer_id), 'status_values_misaligned' as dq_issue
from base_ base
full join (select customer_id, status from raw_rapsodo.billing_subscriptions) as billing on base.user_id = billing.customer_id
where base.status != billing.status or base.user_id is null or billing.customer_id is null
order by coalesce(base.user_id, billing.customer_id) asc
)
, final_ as (
select * from base
union
select * from null_values
union
select * from plan_value_misaligned
union 
select * from status_values_misaligned
)
select base.user_id, dq.category, dq.dq_issue, dq.dq_issue_risk_level
from final_ base
inner join common_mapping.user_dq_issue_category dq on base.dq_issue = dq.dq_issue