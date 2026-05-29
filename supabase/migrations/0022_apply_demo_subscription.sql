-- =============================================================================
-- 0022  apply_demo_subscription() — persist demo plan to provider_subscriptions
-- -----------------------------------------------------------------------------
-- Bug fixed:
--
--   The Flutter SubscriptionService writes the chosen plan to in-memory state
--   and SharedPreferences, but never to the database. As soon as anything
--   calls `loadEntitlement()` (e.g. the Hub bootstrap on app open), the DB
--   query against `provider_current_plan` returns Free — because the row in
--   `provider_subscriptions` was never created — and overwrites the local
--   state. The user sees their selected plan revert to Free.
--
-- Resolution:
--
--   Expose a SECURITY DEFINER RPC the client calls right after the user
--   confirms a plan. The RPC:
--     1. Cancels any currently-active subscription for the provider.
--     2. Inserts a new row in `provider_subscriptions` with status='active'
--        and the price taken from the plan catalog.
--     3. Returns the new subscription id.
--
--   Subsequent reads from `provider_current_plan` will resolve the correct
--   tier, so the UI stays consistent across restarts and devices.
--
--   When the real payment gateway is wired, the webhook handler does the
--   same INSERT — the difference is that the payment is actually charged.
--   The client-side flow is unchanged.
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

  -- Make sure the caller already has a providers row (created by
  -- become_provider() during the choice-screen step).
  select id into _provider_id
    from public.providers
   where owner_id = _uid;
  if _provider_id is null then
    raise exception 'no provider row — call become_provider() first';
  end if;

  -- Always cancel anything currently active before transitioning so the
  -- partial unique index on (provider_id, status in (active,...)) stays
  -- satisfied with exactly one current row.
  update public.provider_subscriptions
     set status      = 'canceled',
         canceled_at = now()
   where provider_id = _provider_id
     and status in ('active', 'trialing', 'past_due');

  -- Free is the natural fallback in `provider_current_plan`, so no row is
  -- needed. Returning null signals "you are on Free now".
  if _tier = 'free' then
    return null;
  end if;

  -- Look up the price + period from the plan catalog so a future price
  -- change in subscription_plans propagates automatically.
  if _yearly then
    select price_yearly_egp into _amount
      from public.subscription_plans
     where tier = _tier;
    _period := interval '365 days';
  else
    select price_monthly_egp into _amount
      from public.subscription_plans
     where tier = _tier;
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
  'Atomically transitions the caller to the chosen plan: cancels any active '
  'subscription and inserts a fresh ''active'' row using the catalog price. '
  'Until payments are live this is what the client calls on plan confirm — '
  'the entry point swaps to a webhook handler once the gateway lands.';

commit;
