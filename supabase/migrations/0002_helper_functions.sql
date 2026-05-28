-- =============================================================================
-- 0002  Helper functions
-- -----------------------------------------------------------------------------
-- Reusable PL/pgSQL helpers consumed by RLS policies and triggers.
--
-- NOTE: Role-check helpers (has_role, is_admin, etc.) are defined in
-- 0003_profiles_and_roles.sql, after the user_roles table is created.
-- language sql functions are validated at creation time, so they cannot
-- reference a table that does not exist yet.
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- updated_at maintenance — attach to every mutable table.
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ----------------------------------------------------------------------------
-- Rate-limit primitive. Burns one token from a bucket; returns false if the
-- caller has exhausted the bucket inside the window.
--
-- Bucket keys are app-defined strings, e.g.
--   ('login',           ip_address)
--   ('submit_place',    user_id)
--   ('report_abuse',    user_id)
-- ----------------------------------------------------------------------------
create or replace function public.consume_rate_limit(
  _bucket text,
  _key    text,
  _limit  int,
  _window interval
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  _count int;
begin
  -- Garbage-collect expired rows opportunistically.
  delete from public.rate_limit_buckets
  where window_start < now() - _window;

  -- Atomically increment-or-insert.
  insert into public.rate_limit_buckets (bucket, key, hits, window_start)
  values (_bucket, _key, 1, now())
  on conflict (bucket, key) do update
    set hits = case
        when public.rate_limit_buckets.window_start < now() - _window
          then 1
        else public.rate_limit_buckets.hits + 1
      end,
      window_start = case
        when public.rate_limit_buckets.window_start < now() - _window
          then now()
        else public.rate_limit_buckets.window_start
      end
  returning hits into _count;

  return _count <= _limit;
end;
$$;

commit;
