-- =============================================================================
-- 0042  campaign-assets storage bucket
-- -----------------------------------------------------------------------------
-- Lets providers upload promotional banner images under:
--   campaign-assets/<provider_id>/<place_id>/<file>
-- Public read is allowed only because approved campaigns need to render
-- images inside place details for every user.
-- =============================================================================

begin;

insert into storage.buckets (id, name, public)
values ('campaign-assets', 'campaign-assets', true)
on conflict (id) do nothing;

drop policy if exists campaign_assets_public_read on storage.objects;
create policy campaign_assets_public_read
  on storage.objects for select
  using (bucket_id = 'campaign-assets');

drop policy if exists campaign_assets_owner_insert on storage.objects;
create policy campaign_assets_owner_insert
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'campaign-assets'
    and exists (
      select 1 from public.providers p
      where p.id::text = (storage.foldername(name))[1]
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists campaign_assets_owner_update on storage.objects;
create policy campaign_assets_owner_update
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'campaign-assets'
    and exists (
      select 1 from public.providers p
      where p.id::text = (storage.foldername(name))[1]
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists campaign_assets_owner_delete on storage.objects;
create policy campaign_assets_owner_delete
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'campaign-assets'
    and (
      exists (
        select 1 from public.providers p
        where p.id::text = (storage.foldername(name))[1]
          and p.owner_id = auth.uid()
      )
      or public.is_admin()
    )
  );

commit;
