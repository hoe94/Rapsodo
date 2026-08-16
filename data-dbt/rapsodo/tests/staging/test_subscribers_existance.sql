select 'missing_from_billing' as status, internal.user_id
from staging_rapsodo.internal_subscriptions internal
left join staging_rapsodo.billing_subscriptions billing on internal.user_id = billing.user_id
where billing.user_id is null
union
select 'missing_from_internal' as status, billing.user_id
from staging_rapsodo.billing_subscriptions billing
left join staging_rapsodo.internal_subscriptions internal on billing.user_id = internal.user_id
where internal.user_id is null