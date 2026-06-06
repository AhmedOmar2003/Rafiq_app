-- Separate Google login from Google registration.
--
-- Supabase creates auth.users during OAuth. This flag records whether the
-- user intentionally completed RAFIQ registration, rather than treating the
-- first Google login attempt as a valid app account.

begin;

alter table public.profiles
  add column if not exists signup_completed boolean not null default false;

-- Every profile that existed before this migration is an established account.
update public.profiles
set signup_completed = true
where signup_completed = false;

comment on column public.profiles.signup_completed is
  'True only after the user intentionally completes RAFIQ registration.';

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _display_name text;
  _provider text;
begin
  _display_name := left(
    coalesce(
      nullif(new.raw_user_meta_data->>'full_name', ''),
      nullif(new.raw_user_meta_data->>'name', ''),
      split_part(new.email, '@', 1)
    ),
    80
  );
  _provider := coalesce(new.raw_app_meta_data->>'provider', 'email');

  begin
    insert into public.profiles (
      id,
      full_name,
      email,
      email_verified_at,
      signup_completed
    )
    values (
      new.id,
      _display_name,
      new.email,
      case when new.email_confirmed_at is not null then new.email_confirmed_at end,
      _provider = 'email'
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

create or replace function public.lookup_auth_email_state(p_email text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_email text := lower(trim(coalesce(p_email, '')));
  auth_email_confirmed_at timestamptz;
  profile_signup_completed boolean;
begin
  if normalized_email = '' then
    return jsonb_build_object(
      'exists', false,
      'confirmed', false,
      'profile_exists', false,
      'signup_completed', false
    );
  end if;

  select
    u.email_confirmed_at,
    coalesce(p.signup_completed, false)
  into auth_email_confirmed_at, profile_signup_completed
  from auth.users u
  left join public.profiles p on p.id = u.id
  where lower(u.email) = normalized_email
  limit 1;

  if not found then
    return jsonb_build_object(
      'exists', false,
      'confirmed', false,
      'profile_exists', false,
      'signup_completed', false
    );
  end if;

  return jsonb_build_object(
    'exists', true,
    'confirmed', auth_email_confirmed_at is not null,
    'profile_exists', exists (
      select 1
      from public.profiles p
      where lower(p.email::text) = normalized_email
    ),
    'signup_completed', profile_signup_completed
  );
end;
$$;

create or replace function public.complete_google_signup()
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'authentication required';
  end if;

  update public.profiles
  set signup_completed = true,
      updated_at = now()
  where id = auth.uid();

  if not found then
    raise exception 'profile not found';
  end if;
end;
$$;

grant execute on function public.lookup_auth_email_state(text)
  to anon, authenticated;
grant execute on function public.complete_google_signup()
  to authenticated;

commit;
