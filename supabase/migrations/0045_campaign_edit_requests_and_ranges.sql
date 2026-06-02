-- =============================================================================
-- 0045  Campaign edit requests + provider resubmission workflow
-- -----------------------------------------------------------------------------
-- Goals:
--   • Let providers request edits for already-approved campaigns.
--   • Allow admins to approve/decline the edit request separately from the
--     campaign's current live status.
--   • Once editing is opened, the provider can edit and re-submit the
--     campaign, which moves it back to pending_review for up to 6 hours.
-- =============================================================================

begin;

alter table public.promotional_campaigns
  add column if not exists edit_request_status text not null default 'none'
    check (edit_request_status in ('none', 'pending', 'approved', 'rejected')),
  add column if not exists edit_request_note text,
  add column if not exists edit_request_response text,
  add column if not exists edit_request_requested_at timestamptz,
  add column if not exists edit_request_reviewed_at timestamptz,
  add column if not exists edit_allowed boolean not null default false;

create index if not exists promotional_campaigns_edit_request_idx
  on public.promotional_campaigns (edit_request_status, created_at desc);

comment on column public.promotional_campaigns.edit_request_status is
  'Provider edit request state: none, pending, approved, rejected.';
comment on column public.promotional_campaigns.edit_allowed is
  'When true, the provider may edit the campaign and re-submit it for moderation.';

create or replace function public.request_campaign_edit(
  _campaign_id uuid,
  _note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _provider_id uuid;
begin
  if _uid is null then
    raise exception 'authentication required';
  end if;

  select p.id
    into _provider_id
  from public.providers p
  where p.owner_id = _uid
    and p.deleted_at is null
  limit 1;

  if _provider_id is null then
    raise exception 'provider account not found';
  end if;

  update public.promotional_campaigns c
     set edit_request_status = 'pending',
         edit_request_note = nullif(trim(_note), ''),
         edit_request_response = null,
         edit_request_requested_at = now(),
         edit_request_reviewed_at = null,
         edit_allowed = false,
         updated_at = now()
   where c.id = _campaign_id
     and c.provider_id = _provider_id
     and c.status in ('active', 'paused')
     and coalesce(c.edit_request_status, 'none') <> 'pending'
  returning c.id into _campaign_id;

  if _campaign_id is null then
    raise exception 'campaign edit request is not available';
  end if;

  return _campaign_id;
end;
$$;

revoke all on function public.request_campaign_edit(uuid, text) from public;
grant execute on function public.request_campaign_edit(uuid, text) to authenticated;

create or replace function public.update_provider_campaign(
  _campaign_id uuid,
  _place_id uuid,
  _kind public.campaign_kind,
  _title text,
  _body text default null,
  _image_path text default null,
  _cta_label text default null,
  _starts_at timestamptz default null,
  _ends_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _provider_id uuid;
  _campaign public.promotional_campaigns%rowtype;
  _ent public.provider_current_plan%rowtype;
  _starts timestamptz := coalesce(_starts_at, now());
begin
  if _uid is null then
    raise exception 'authentication required';
  end if;

  if _campaign_id is null or _place_id is null then
    raise exception 'campaign and place are required';
  end if;

  if _ends_at is null or _ends_at <= _starts then
    raise exception 'campaign end must be after start';
  end if;

  select p.id
    into _provider_id
  from public.providers p
  where p.owner_id = _uid
    and p.deleted_at is null
  limit 1;

  if _provider_id is null then
    raise exception 'provider account not found';
  end if;

  select *
    into _campaign
  from public.promotional_campaigns c
  where c.id = _campaign_id
    and c.provider_id = _provider_id
  limit 1;

  if _campaign.id is null then
    raise exception 'campaign not found';
  end if;

  if not (
    coalesce(_campaign.edit_allowed, false)
    or coalesce(_campaign.edit_request_status, 'none') = 'approved'
    or _campaign.status in ('draft', 'rejected')
  ) then
    raise exception 'campaign editing is not open yet';
  end if;

  perform 1
  from public.places pl
  where pl.id = _place_id
    and pl.provider_id = _provider_id
    and pl.deleted_at is null
    and pl.status = 'approved';

  if not found then
    raise exception 'place not eligible for campaigns';
  end if;

  select *
    into _ent
  from public.provider_current_plan
  where provider_id = _provider_id;

  if not coalesce(_ent.has_promotions, false) then
    raise exception 'current plan does not allow promotions';
  end if;

  if _kind = 'featured' and not coalesce(_ent.has_featured_slot, false) then
    raise exception 'featured campaigns require a higher plan';
  end if;

  if _kind = 'push_notification' and not coalesce(_ent.has_push_campaigns, false) then
    raise exception 'push campaigns require a higher plan';
  end if;

  if _kind = 'spotlight' and not coalesce(_ent.has_homepage_spotlight, false) then
    raise exception 'spotlight campaigns require a higher plan';
  end if;

  update public.promotional_campaigns c
     set place_id = _place_id,
         kind = _kind,
         status = 'pending_review',
         title = _title,
         body = nullif(trim(_body), ''),
         image_path = nullif(trim(_image_path), ''),
         cta_label = nullif(trim(_cta_label), ''),
         starts_at = _starts,
         ends_at = _ends_at,
         rejection_reason = null,
         approved_at = null,
         edit_request_status = 'none',
         edit_request_note = null,
         edit_request_response = null,
         edit_request_requested_at = null,
         edit_request_reviewed_at = null,
         edit_allowed = false,
         updated_at = now()
   where c.id = _campaign_id;

  return _campaign_id;
end;
$$;

revoke all on function public.update_provider_campaign(
  uuid,
  uuid,
  public.campaign_kind,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) from public;
grant execute on function public.update_provider_campaign(
  uuid,
  uuid,
  public.campaign_kind,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) to authenticated;

commit;
