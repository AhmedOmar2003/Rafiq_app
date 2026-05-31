-- =============================================================================
-- 0040  profiles.account_mode — backend source of truth for app surface
-- -----------------------------------------------------------------------------
-- Why
--   The app previously remembered "regular user vs provider mode" only in
--   SharedPreferences. That breaks cross-device sign-in and reinstall flows:
--   the backend still knows the provider row + subscription, but the device
--   forgets which surface to open.
--
-- Resolution
--   Persist the current app mode on `public.profiles`:
--     * null        → user has not chosen a mode yet (show ChoiceScreen)
--     * 'user'      → regular browsing mode
--     * 'provider'  → provider hub mode
--
--   Provider history remains derivable from `public.providers`, so we do not
--   duplicate it here.
-- =============================================================================

begin;

alter table public.profiles
  add column if not exists account_mode text
  check (account_mode in ('user', 'provider'));

comment on column public.profiles.account_mode is
  'Current app surface chosen by the user. null = not chosen yet; user = regular mode; provider = provider hub mode.';

create index if not exists profiles_account_mode_idx
  on public.profiles (account_mode)
  where account_mode is not null;

commit;
