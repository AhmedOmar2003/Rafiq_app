-- =============================================================================
-- 0011  Storage buckets + RLS
-- -----------------------------------------------------------------------------
-- BUCKETS
--   avatars             public  | one folder per user (auth.uid())
--   place-images        public  | folder = provider_id; only owner uploads
--   provider-documents  PRIVATE | folder = provider_id; signed URLs only
--   banners             public  | admin only
--
-- File-naming convention enforced in storage RLS:
--   <bucket>/<owner_uuid>/<unique-filename>
-- the first path segment must match auth.uid() (avatars) or the provider's id.
-- =============================================================================

begin;

-- Create buckets idempotently (allowed_mime_types restricts uploads at the
-- bucket level; file_size_limit is in bytes).
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars',
   true,
   2 * 1024 * 1024,                                          -- 2 MB
   array['image/png','image/jpeg','image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('place-images', 'place-images',
   true,
   5 * 1024 * 1024,                                          -- 5 MB per image
   array['image/png','image/jpeg','image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('provider-documents', 'provider-documents',
   false,                                                    -- PRIVATE
   10 * 1024 * 1024,                                         -- 10 MB
   array['application/pdf','image/png','image/jpeg','image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('banners', 'banners',
   true,
   5 * 1024 * 1024,
   array['image/png','image/jpeg','image/webp'])
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- =============================================================================
-- RLS  on storage.objects
-- =============================================================================
-- avatars: anyone reads; owner writes/deletes their own folder only.
drop policy if exists avatars_read on storage.objects;
create policy avatars_read
  on storage.objects for select
  using (bucket_id = 'avatars');

drop policy if exists avatars_write_own on storage.objects;
create policy avatars_write_own
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- place-images: anyone reads; provider owner of the folder writes; mods can delete.
drop policy if exists place_images_read on storage.objects;
create policy place_images_read
  on storage.objects for select
  using (bucket_id = 'place-images');

drop policy if exists place_images_write_provider on storage.objects;
create policy place_images_write_provider
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'place-images'
    and exists (
      select 1 from public.providers p
      where p.id::text = (storage.foldername(name))[1]
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists place_images_delete_provider_or_mod on storage.objects;
create policy place_images_delete_provider_or_mod
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'place-images'
    and (
      exists (
        select 1 from public.providers p
        where p.id::text = (storage.foldername(name))[1]
          and p.owner_id = auth.uid()
      )
      or public.is_moderator_or_above()
    )
  );

-- provider-documents: PRIVATE. Owner reads/writes their own. Moderators read.
drop policy if exists provider_documents_read on storage.objects;
create policy provider_documents_read
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'provider-documents'
    and (
      exists (
        select 1 from public.providers p
        where p.id::text = (storage.foldername(name))[1]
          and p.owner_id = auth.uid()
      )
      or public.is_moderator_or_above()
    )
  );

drop policy if exists provider_documents_write_owner on storage.objects;
create policy provider_documents_write_owner
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'provider-documents'
    and exists (
      select 1 from public.providers p
      where p.id::text = (storage.foldername(name))[1]
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists provider_documents_delete_owner on storage.objects;
create policy provider_documents_delete_owner
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'provider-documents'
    and (
      exists (
        select 1 from public.providers p
        where p.id::text = (storage.foldername(name))[1]
          and p.owner_id = auth.uid()
      )
      or public.is_admin()
    )
  );

-- banners: anyone reads; admin writes.
drop policy if exists banners_read on storage.objects;
create policy banners_read
  on storage.objects for select
  using (bucket_id = 'banners');

drop policy if exists banners_admin_write on storage.objects;
create policy banners_admin_write
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'banners' and public.is_admin());

drop policy if exists banners_admin_update on storage.objects;
create policy banners_admin_update
  on storage.objects for update
  to authenticated
  using (bucket_id = 'banners' and public.is_admin());

drop policy if exists banners_admin_delete on storage.objects;
create policy banners_admin_delete
  on storage.objects for delete
  to authenticated
  using (bucket_id = 'banners' and public.is_admin());

commit;
