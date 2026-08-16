with internal as (
select user_id, status
from staging_rapsodo.internal_subscriptions a
order by user_id asc
)
, billing as (
select user_id, status
from staging_rapsodo.billing_subscriptions a
)
, final as (
select 	
	a.user_id as internal_user_id
	, a.status as internal_status
	, b.user_id as billing_user_id
	, b.status as billing_status
	, (a.status || '_' || b.status) as mismatched_status
from internal a
full join billing b on a.user_id = b.user_id
where (a.user_id || a.status) != (b.user_id || b.status)
)
select * from final