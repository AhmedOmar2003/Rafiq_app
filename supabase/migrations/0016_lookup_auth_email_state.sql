-- =============================================================================
-- 0016  Lookup auth email state for login UX
-- -----------------------------------------------------------------------------
-- Exposes a small, security-definer RPC that lets the client distinguish:
--   - account does not exist
--   - account exists but email is not confirmed yet
--   - account exists and is confirmed
--
-- This is used only to improve login error messages in the app UI.
-- =============================================================================

begin;

create or replace function public.lookup_auth_email_state(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  auth_email_confirmed_at timestamptz;
begin
  if normalized_email = '' then
    return jsonb_build_object(
      'exists', false,
      'confirmed', false,
      'profile_exists', false
    );
  end if;

  select u.email_confirmed_at
    into auth_email_confirmed_at
    from auth.users u
   where lower(u.email) = normalized_email
   limit 1;

  if not found then
    return jsonb_build_object(
      'exists', false,
      'confirmed', false,
      'profile_exists', false
    );
  end if;

  return jsonb_build_object(
    'exists', true,
    'confirmed', auth_email_confirmed_at is not null,
    'profile_exists', exists (
      select 1
      from public.profiles p
      where lower(p.email::text) = normalized_email
    )
  );
end;
$$;

grant execute on function public.lookup_auth_email_state(text) to anon, authenticated;

commit;
