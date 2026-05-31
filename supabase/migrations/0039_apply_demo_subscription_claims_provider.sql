-- =============================================================================
-- 0039  apply_demo_subscription: claim provider role at confirmation time
-- -----------------------------------------------------------------------------
-- Why
--   The app now keeps a brand-new user in "regular user" mode while they are
--   only browsing provider plans. The role should flip to provider only after
--   the user explicitly confirms a plan.
--
--   The previous `apply_demo_subscription()` implementation required an
--   existing row in `public.providers`, which forced the client to call
--   `become_provider()` *before* plan confirmation. That created two bad UX
--   states:
--     1. The user could become a provider even if plan persistence failed.
--     2. The frontend had to fake an "open choice" state while the backend
--        had already committed to the provider track.
--
-- Resolution
--   `apply_demo_subscription()` now self-heals:
--     * If the caller has no provider row yet, it calls `become_provider()`
--       inside the same confirmed-plan flow.
--     * The provider role + provider row + provider_subscriptions row are now
--       all created from the user's explicit plan confirmation step.
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
    select public.become_provider(null, null) into _provider_id;
  end if;

  if _provider_id is null then
    raise exception 'failed to ensure provider row';
  end if;

  update public.provider_subscriptions
     set status      = 'canceled',
         canceled_at = now()
   where provider_id = _provider_id
     and status in ('active', 'trialing', 'past_due');

  if _yearly then
    select price_yearly_egp into _amount
      from public.subscription_plans where tier = _tier;
    _period := interval '365 days';
  else
    select price_monthly_egp into _amount
      from public.subscription_plans where tier = _tier;
    _period := interval '30 days';
  end if;

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

comment on function public.apply_demo_subscription(public.plan_tier, boolean) is
  'Persists the confirmed demo plan for the caller. If the caller has not yet '
  'claimed the provider role, the function first ensures the provider row via '
  'become_provider(), then inserts the confirmed subscription row.';

commit;
