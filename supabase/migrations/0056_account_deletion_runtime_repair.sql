-- Production drift repair: delete_my_account() references this audit ledger,
-- but older environments can be missing the table while retaining the RPC.
create table if not exists public.account_deletions (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null,
  email         extensions.citext,
  had_provider  boolean not null,
  had_paid_plan boolean not null,
  tier_at_delete public.plan_tier,
  deleted_at    timestamptz not null default now(),
  reason        text
);

create index if not exists account_deletions_user_idx
  on public.account_deletions (user_id);

create index if not exists account_deletions_when_idx
  on public.account_deletions (deleted_at desc);

alter table public.account_deletions enable row level security;

drop policy if exists account_deletions_admin_read
  on public.account_deletions;

create policy account_deletions_admin_read
  on public.account_deletions
  for select
  to authenticated
  using (public.is_admin());
