-- =============================================================================
-- 0021  become_provider() — claim the provider role + ensure provider row
-- -----------------------------------------------------------------------------
-- Bug fixed by this migration:
--
--   A brand-new signup gets the 'user' role only (see handle_new_user trigger
--   in 0010). When that user later picks "مقدم خدمة" on the choice screen
--   and the client tries to INSERT into `public.providers`, the existing
--   `providers_insert_self` policy requires `public.is_provider()` to be
--   TRUE — which it can't be because the user doesn't have the role yet.
--
--   That's a chicken-and-egg: you can't insert a provider row without the
--   role, and the role isn't granted automatically when picking provider
--   on the client.
--
-- Resolution:
--
--   Expose a SECURITY DEFINER function that the client can call to express
--   "I want to be a provider". The function:
--     1. Grants the 'provider' role to the calling user (idempotent).
--     2. Inserts a minimal `providers` row if one doesn't exist yet.
--     3. Returns the resolved providers.id so the client can use it
--        immediately for entitlement lookups and place creation.
--
--   This keeps RLS strict (the insert path still requires the role) while
--   giving the client a single atomic entry point — no extra round-trips,
--   no ordering bugs.
-- =============================================================================

begin;

create or replace function public.become_provider(
  _business_name text default null,
  _contact_email text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _provider_id uuid;
  _email text;
  _name text;
begin
  if _uid is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- 1. Grant the provider role (idempotent).
  insert into public.user_roles (user_id, role)
  values (_uid, 'provider')
  on conflict (user_id, role) do nothing;

  -- 2. Find or create the providers row.
  select id into _provider_id
    from public.providers
   where owner_id = _uid;

  if _provider_id is not null then
    return _provider_id;
  end if;

  -- Resolve a sensible default business name + contact email so the NOT NULL
  -- constraints don't reject the insert. We pull from the profile first
  -- (canonical), then any client-provided args.
  select email, full_name
    into _email, _name
    from public.profiles
   where id = _uid;

  _email := coalesce(nullif(trim(_contact_email), ''), _email);
  _name  := coalesce(nullif(trim(_business_name), ''), _name);

  if _email is null or _email = '' then
    -- Last-ditch placeholder so the insert doesn't fail. The user can edit
    -- contact_email from the dashboard later.
    _email := concat('user_', _uid, '@placeholder.local');
  end if;
  if _name is null or _name = '' then
    _name := split_part(_email, '@', 1);
  end if;

  -- 3. Insert the canonical provider row. The handle_new_user trigger has
  --    already given us 'provider' above, so RLS would pass — but we run
  --    as definer here so the policy check is bypassed entirely. That keeps
  --    the function deterministic regardless of jwt timing.
  insert into public.providers (owner_id, business_name, contact_email, status)
  values (_uid, _name, _email, 'pending')
  returning id into _provider_id;

  return _provider_id;
end;
$$;

revoke all on function public.become_provider(text, text) from public;
grant execute on function public.become_provider(text, text)
  to authenticated;

comment on function public.become_provider(text, text) is
  'Atomically grants the provider role + ensures a providers row exists for '
  'the calling user. Idempotent. Call this from the choice screen the moment '
  'a user picks "مقدم خدمة" — the returned uuid is the providers.id.';

commit;
