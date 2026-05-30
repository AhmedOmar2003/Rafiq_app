-- =============================================================================
-- 0033  place_appeals — providers' appeals against place rejections
-- -----------------------------------------------------------------------------
-- Product flow
--   admin rejects a place (sets places.status = 'rejected', writes reason)
--      → provider sees the rejection card in the Hub
--      → provider opens "طعن في قرار الرفض" sheet
--      → fills name + phone + message
--      → SUBMIT writes one row into place_appeals
--      → row shows up in /dashboard/appeals for the admin to review
--      → admin contacts the provider via phone/email on their own
--      → admin marks the appeal as reviewed
--
-- Schema choices
--   * Soft delete via status enum so we keep history.
--   * Reviewer fields (note, reviewed_at) so we can show "تمت المراجعة بواسطة …"
--   * No FK on place_id back to a typed places.id — the legacy `places` table
--     uses bigint `place_id` not the modern uuid `id`. We keep place_id as
--     bigint to match the column the Flutter app reads.
-- =============================================================================

begin;

do $$ begin
  create type public.appeal_status as enum ('pending', 'reviewing', 'resolved', 'rejected');
exception when duplicate_object then null; end $$;

create table if not exists public.place_appeals (
  id             uuid              primary key default gen_random_uuid(),
  place_id       bigint            not null,
  provider_id    uuid              references public.providers(id) on delete set null,
  contact_name   text              not null check (char_length(contact_name) between 2 and 80),
  contact_phone  text              not null check (contact_phone ~ '^\+?[0-9]{6,15}$'),
  contact_email  text,
  message        text              not null check (char_length(message) between 5 and 2000),
  status         public.appeal_status not null default 'pending',
  reviewer_id    uuid              references auth.users(id) on delete set null,
  reviewer_note  text,
  reviewed_at    timestamptz,
  created_at     timestamptz       not null default now(),
  updated_at     timestamptz       not null default now()
);

create index if not exists place_appeals_place_idx
  on public.place_appeals (place_id, created_at desc);
create index if not exists place_appeals_status_idx
  on public.place_appeals (status, created_at desc);
create index if not exists place_appeals_provider_idx
  on public.place_appeals (provider_id);

alter table public.place_appeals enable row level security;

-- Authenticated providers can submit appeals via the RPC below. Direct INSERT
-- is blocked; this keeps reasoning auditable and rate-limit-able later.
drop policy if exists place_appeals_no_direct_insert on public.place_appeals;

-- Admins (any moderator-or-above) can read every appeal.
drop policy if exists place_appeals_admin_read on public.place_appeals;
create policy place_appeals_admin_read
  on public.place_appeals
  for select
  to authenticated
  using (public.is_moderator_or_above());

-- Admins can update (mark reviewed, write note).
drop policy if exists place_appeals_admin_update on public.place_appeals;
create policy place_appeals_admin_update
  on public.place_appeals
  for update
  to authenticated
  using (public.is_moderator_or_above())
  with check (public.is_moderator_or_above());

-- Providers can read their own appeals so the app could surface status later.
drop policy if exists place_appeals_owner_read on public.place_appeals;
create policy place_appeals_owner_read
  on public.place_appeals
  for select
  to authenticated
  using (
    provider_id in (
      select p.id from public.providers p where p.owner_id = auth.uid()
    )
  );

-- ----------------------------------------------------------------------------
-- RPC: submit_place_appeal
-- ----------------------------------------------------------------------------
-- The Flutter app calls this from the appeal sheet. It validates that:
--   1. The caller is authenticated.
--   2. The place actually belongs to the caller (otherwise providers could
--      file noise against each other).
--   3. The place is in 'rejected' status — you can only appeal a rejection.
-- ----------------------------------------------------------------------------
create or replace function public.submit_place_appeal(
  _place_id      bigint,
  _contact_name  text,
  _contact_phone text,
  _message       text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid          uuid := auth.uid();
  _email        text;
  _provider_id  uuid;
  _place_status public.moderation_status;
  _appeal_id    uuid;
begin
  if _uid is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- Look up the caller's provider row + their auth email for the contact_email
  -- audit field. If the user isn't a provider at all, the appeal is rejected
  -- here (only providers can appeal their own place).
  select id into _provider_id
    from public.providers
   where owner_id = _uid;
  if _provider_id is null then
    raise exception 'not a provider' using errcode = '42501';
  end if;

  select email into _email
    from auth.users where id = _uid;

  -- Verify the place belongs to this provider and is rejected.
  select status into _place_status
    from public.places
   where place_id = _place_id
     and provider_id = _provider_id;
  if not found then
    raise exception 'place not found or not yours' using errcode = '42501';
  end if;
  if _place_status <> 'rejected' then
    raise exception 'يمكنك تقديم طعن فقط على مكان مرفوض' using errcode = 'P0001';
  end if;

  insert into public.place_appeals
    (place_id, provider_id, contact_name, contact_phone, contact_email, message)
  values
    (_place_id, _provider_id, _contact_name, _contact_phone, _email, _message)
  returning id into _appeal_id;

  return _appeal_id;
end;
$$;

revoke all on function public.submit_place_appeal(bigint, text, text, text) from public;
grant execute on function public.submit_place_appeal(bigint, text, text, text) to authenticated;

commit;
