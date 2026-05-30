-- =============================================================================
-- 0027  Enable Supabase Realtime on public.places
-- -----------------------------------------------------------------------------
-- The Flutter provider hub opens a Postgres-changes channel filtered to its
-- own provider_id rows so that when the admin clicks "Approve" / "Reject" in
-- the web dashboard, the provider sees the new status in their app without
-- having to pull-to-refresh. The wire is:
--
--   admin clicks ─→ UPDATE places SET status = 'approved'
--          │
--          ▼
--   Postgres WAL (logical replication) ─→ supabase_realtime publication
--          │
--          ▼
--   wss://…/realtime/v1/websocket ─→ Flutter RealtimeChannel callback
--          │
--          ▼
--   _loadProviderPlaces() refetches → setState → UI flips
--
-- For this to work the table must be in the supabase_realtime publication.
-- Adding it is a no-op if it's already there.
-- =============================================================================

begin;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
     where pubname = 'supabase_realtime'
       and schemaname = 'public'
       and tablename = 'places'
  ) then
    execute 'alter publication supabase_realtime add table public.places';
  end if;
end $$;

commit;
