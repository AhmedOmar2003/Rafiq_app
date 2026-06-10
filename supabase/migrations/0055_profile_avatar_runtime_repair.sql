-- Production drift repair: some environments were created without the
-- profiles.avatar_url column even though the original schema declared it.
alter table public.profiles
  add column if not exists avatar_url text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.profiles'::regclass
      and conname = 'profiles_avatar_url_http_check'
  ) then
    alter table public.profiles
      add constraint profiles_avatar_url_http_check
      check (avatar_url is null or avatar_url ~* '^https?://');
  end if;
end
$$;

comment on column public.profiles.avatar_url is
  'Public avatar URL stored in the avatars bucket for the profile owner.';
