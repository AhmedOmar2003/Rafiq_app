-- =============================================================================
-- 0014  Fix new-user profile bootstrap
-- -----------------------------------------------------------------------------
-- This migration makes the auth.users -> profiles bootstrap more defensive:
--   - trims very long display names to the profiles.full_name limit
--   - recovers gracefully if a stale profile row already exists for the same
--     email address, which otherwise causes:
--       "Database error saving new user"
-- =============================================================================

begin;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _display_name text;
begin
  _display_name := left(
    coalesce(
      nullif(new.raw_user_meta_data->>'full_name', ''),
      nullif(new.raw_user_meta_data->>'name', ''),
      split_part(new.email, '@', 1)
    ),
    80
  );

  begin
    insert into public.profiles (id, full_name, email, email_verified_at)
    values (
      new.id,
      _display_name,
      new.email,
      case when new.email_confirmed_at is not null then new.email_confirmed_at end
    )
    on conflict (id) do update
    set full_name = excluded.full_name,
        email = excluded.email,
        email_verified_at = excluded.email_verified_at,
        updated_at = now();
  exception when unique_violation then
    update public.profiles
       set id = new.id,
           full_name = _display_name,
           email = new.email,
           email_verified_at = case when new.email_confirmed_at is not null then new.email_confirmed_at end,
           updated_at = now()
     where email = new.email;

    if not found then
      raise;
    end if;
  end;

  insert into public.user_roles (user_id, role)
  values (new.id, 'user')
  on conflict (user_id, role) do nothing;

  if new.raw_app_meta_data->>'intended_role' = 'provider' then
    insert into public.user_roles (user_id, role)
    values (new.id, 'provider')
    on conflict (user_id, role) do nothing;
  end if;

  return new;
end;
$$;

commit;
