-- =============================================================================
-- 0026  apply_demo_subscription: insert a row for Free tier too
-- -----------------------------------------------------------------------------
-- Why
--   The previous version returned early when `_tier = 'free'` and never wrote
--   a row. That meant `provider_subscriptions` could only confirm Pro/Max
--   subscribers, and the admin dashboard could not tell:
--     (a) a user who tapped "Become provider" but bailed at the plan screen
--     (b) from a user who explicitly chose Free and confirmed.
--
--   Per product spec, (b) IS a "مقدّم خدمة" (still listing a business under
--   the Free plan). The single source of truth for "this user is a confirmed
--   provider" should be the existence of a `provider_subscriptions` row.
--
-- Resolution
--   * Insert a row for every tier — including Free. Free rows carry
--     amount_paid_egp = 0 and the same 30/365-day window so all downstream
--     reads (period_end, cancel_at_period_end) are uniform.
--   * Backfill: every existing `providers` row that has no active sub gets a
--     Free row inserted now, so the admin's "16 providers" reconciles.
-- =============================================================================

begin;

create or replace function public.apply_demo_subscription(
  _tier   public.plan_tier,
  _yearly boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid         uuid := auth.uid();
  _provider_id uuid;
  _sub_id      uuid;
  _amount      int;
  _period      interval;
begin
  if _uid is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  select id into _provider_id
    from public.providers
   where owner_id = _uid;
  if _provider_id is null then
    raise exception 'no provider row — call become_provider() first';
  end if;

  -- Cancel any current active row so the partial unique constraint on
  -- (provider_id, status in active/...) stays satisfied with one row.
  update public.provider_subscriptions
     set status      = 'canceled',
         canceled_at = now()
   where provider_id = _provider_id
     and status in ('active', 'trialing', 'past_due');

  -- Look up the catalog price + period length.
  if _yearly then
    select price_yearly_egp into _amount
      from public.subscription_plans where tier = _tier;
    _period := interval '365 days';
  else
    select price_monthly_egp into _amount
      from public.subscription_plans where tier = _tier;
    _period := interval '30 days';
  end if;

  -- Insert for ALL tiers including Free. The presence of a row in
  -- provider_subscriptions is what marks "confirmed subscriber". Free
  -- providers get amount=0 and the same cycle so the UI/admin treat them
  -- uniformly.
  insert into public.provider_subscriptions (
    provider_id, tier, status, gateway,
    period_start, period_end,
    amount_paid_egp, currency, metadata
  ) values (
    _provider_id, _tier, 'active', 'manual',
    now(), now() + _period,
    coalesce(_amount, 0), 'EGP',
    jsonb_build_object('source', 'demo', 'yearly', _yearly)
  )
  returning id into _sub_id;

  return _sub_id;
end;
$$;

revoke all on function public.apply_demo_subscription(public.plan_tier, boolean)
  from public;
grant execute on function public.apply_demo_subscription(public.plan_tier, boolean)
  to authenticated;

-- ----------------------------------------------------------------------------
-- Backfill: existing providers without any active sub get a Free row so the
-- admin dashboard reconciles immediately.
-- ----------------------------------------------------------------------------
insert into public.provider_subscriptions
  (provider_id, tier, status, gateway, period_start, period_end,
   amount_paid_egp, currency, metadata)
select
  p.id,
  'free'::public.plan_tier,
  'active'::public.subscription_status,
  'manual'::public.billing_gateway,
  now(),
  now() + interval '365 days',
  0,
  'EGP'::public.currency,
  jsonb_build_object('source', 'backfill', 'yearly', false)
from public.providers p
where not exists (
  select 1 from public.provider_subscriptions ps
   where ps.provider_id = p.id
     and ps.status in ('active', 'trialing', 'past_due')
);

commit;
