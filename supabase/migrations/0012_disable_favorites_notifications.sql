-- =============================================================================
-- 0012  Disable favorites + notifications for now
-- ---------------------------------------------------------------------------
-- This is a forward migration for databases that already applied 0009.
-- It removes every authenticated policy from favorites/notifications so they
-- become inaccessible to anon/authenticated users while remaining available
-- to service-role only.
-- =============================================================================

begin;

alter table public.favorites enable row level security;
alter table public.notifications enable row level security;

drop policy if exists favorites_select_self on public.favorites;
drop policy if exists favorites_write_self on public.favorites;

drop policy if exists notifications_select_self on public.notifications;
drop policy if exists notifications_update_self on public.notifications;

commit;
