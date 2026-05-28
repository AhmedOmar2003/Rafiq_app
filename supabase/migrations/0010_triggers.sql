-- =============================================================================
-- 0010  Triggers
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- updated_at maintenance on every mutable table
-- ----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'profiles', 'cities', 'categories', 'providers',
    'places', 'reviews'
  ]
  loop
    execute format('drop trigger if exists trg_%s_set_updated_at on public.%I', t, t);
    execute format(
      'create trigger trg_%s_set_updated_at
       before update on public.%I
       for each row execute function public.set_updated_at()',
      t, t
    );
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- handle_new_user — fires on auth.users INSERT
--
-- 1. Creates the profile row.
-- 2. Grants the default `user` role.
-- 3. Honors `app_metadata.intended_role = 'provider'` (set by sign-up flow)
--    by also granting the `provider` role. NOTE: this is a *trusted* metadata
--    bag — only the service role can set it via Edge Function. Sign-up clients
--    never pass it directly.
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _intended_role text;
begin
  insert into public.profiles (id, full_name, email, email_verified_at)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data->>'full_name', ''),
      nullif(new.raw_user_meta_data->>'name', ''),
      split_part(new.email, '@', 1)
    ),
    new.email,
    case when new.email_confirmed_at is not null then new.email_confirmed_at end
  )
  on conflict (id) do update
  set email      = excluded.email,
      updated_at = now();

  -- Every new user gets the base role.
  insert into public.user_roles (user_id, role)
  values (new.id, 'user')
  on conflict (user_id, role) do nothing;

  -- Service-role-only provider intent (set during provider sign-up flow).
  _intended_role := new.raw_app_meta_data->>'intended_role';
  if _intended_role = 'provider' then
    insert into public.user_roles (user_id, role)
    values (new.id, 'provider')
    on conflict (user_id, role) do nothing;
  end if;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- Keep profiles.email_verified_at in sync when auth confirms email
-- ----------------------------------------------------------------------------
create or replace function public.sync_email_verified()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.email_confirmed_at is distinct from old.email_confirmed_at then
    update public.profiles
       set email_verified_at = new.email_confirmed_at,
           updated_at = now()
     where id = new.id;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after update on auth.users
  for each row execute function public.sync_email_verified();

-- ----------------------------------------------------------------------------
-- Append-only enforcement on moderation_history & admin_logs
-- ----------------------------------------------------------------------------
create or replace function public.deny_mutation()
returns trigger
language plpgsql
as $$
begin
  raise exception 'append-only table: % not permitted', tg_op;
end;
$$;

drop trigger if exists trg_moderation_history_append_only on public.moderation_history;
create trigger trg_moderation_history_append_only
  before update or delete on public.moderation_history
  for each row execute function public.deny_mutation();

drop trigger if exists trg_admin_logs_append_only on public.admin_logs;
create trigger trg_admin_logs_append_only
  before update or delete on public.admin_logs
  for each row execute function public.deny_mutation();

-- ----------------------------------------------------------------------------
-- Lock down moderation columns on `providers` and `places`
--
-- RLS already prevents arbitrary writes from non-moderators, but a moderator
-- account could otherwise accidentally pass through bogus values. This trigger
-- forces every status transition through the moderation_history log AND
-- forbids the OWNER from changing moderation columns at all.
-- ----------------------------------------------------------------------------
create or replace function public.guard_provider_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_mod boolean := public.is_moderator_or_above();
begin
  if not _is_mod then
    -- Owner update — moderation columns must NOT change.
    if new.status         is distinct from old.status
       or new.approved_at is distinct from old.approved_at
       or new.approved_by is distinct from old.approved_by
       or new.suspended_at is distinct from old.suspended_at
       or new.rejection_reason is distinct from old.rejection_reason
    then
      raise exception 'only moderators can change moderation columns';
    end if;
  else
    -- Moderator update — record transition.
    if new.status is distinct from old.status then
      insert into public.moderation_history
        (target_type, target_id, action, from_status, to_status, actor_id, reason)
      values
        ('provider', new.id,
         case new.status
           when 'approved'    then 'approve'
           when 'rejected'    then 'reject'
           when 'suspended'   then 'suspend'
           when 'pending'     then 'reinstate'
           when 'under_review' then 'start_review'
         end,
         old.status, new.status, auth.uid(), new.rejection_reason);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_providers_guard on public.providers;
create trigger trg_providers_guard
  before update on public.providers
  for each row execute function public.guard_provider_moderation();

-- Same guard for places.
create or replace function public.guard_place_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_mod boolean := public.is_moderator_or_above();
begin
  if not _is_mod then
    if new.status        is distinct from old.status
       or new.approved_at is distinct from old.approved_at
       or new.approved_by is distinct from old.approved_by
       or new.suspended_at is distinct from old.suspended_at
       or new.rejection_reason is distinct from old.rejection_reason
    then
      raise exception 'only moderators can change moderation columns';
    end if;
  else
    if new.status is distinct from old.status then
      insert into public.moderation_history
        (target_type, target_id, action, from_status, to_status, actor_id, reason)
      values
        ('place', new.id,
         case new.status
           when 'approved'    then 'approve'
           when 'rejected'    then 'reject'
           when 'suspended'   then 'suspend'
           when 'pending'     then 'reinstate'
           when 'under_review' then 'start_review'
         end,
         old.status, new.status, auth.uid(), new.rejection_reason);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_places_guard on public.places;
create trigger trg_places_guard
  before update on public.places
  for each row execute function public.guard_place_moderation();

-- ----------------------------------------------------------------------------
-- Keep places.rating_avg / rating_count in sync with reviews
-- ----------------------------------------------------------------------------
create or replace function public.recalc_place_rating(_place_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.places
     set rating_avg   = coalesce((
                          select avg(rating)::numeric(3,2)
                          from public.reviews
                          where place_id::text = _place_id
                            and is_hidden = false and deleted_at is null
                        ), 0),
         rating_count = (
                          select count(*)
                          from public.reviews
                          where place_id::text = _place_id
                            and is_hidden = false and deleted_at is null
                        )
   where id::text = _place_id;
end;
$$;

create or replace function public.trg_reviews_recalc()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    perform public.recalc_place_rating(old.place_id::text);
    return old;
  else
    perform public.recalc_place_rating(new.place_id::text);
    if tg_op = 'UPDATE' and new.place_id <> old.place_id then
      perform public.recalc_place_rating(old.place_id::text);
    end if;
    return new;
  end if;
end;
$$;

drop trigger if exists trg_reviews_recalc on public.reviews;
create trigger trg_reviews_recalc
  after insert or update or delete on public.reviews
  for each row execute function public.trg_reviews_recalc();

-- ----------------------------------------------------------------------------
-- Derive budget_bucket on places from price_min / price_max
-- ----------------------------------------------------------------------------
create or replace function public.derive_budget_bucket()
returns trigger
language plpgsql
as $$
declare
  _ref int;
begin
  _ref := coalesce(new.price_max, new.price_min);
  if _ref is null then
    new.budget_bucket := null;
  elsif _ref < 100 then
    new.budget_bucket := 'low';
  elsif _ref < 500 then
    new.budget_bucket := 'mid';
  elsif _ref < 2000 then
    new.budget_bucket := 'high';
  else
    new.budget_bucket := 'premium';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_places_budget on public.places;
create trigger trg_places_budget
  before insert or update of price_min, price_max on public.places
  for each row execute function public.derive_budget_bucket();

commit;
