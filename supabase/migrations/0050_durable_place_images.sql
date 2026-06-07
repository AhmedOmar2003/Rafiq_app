-- =============================================================================
-- 0050  Durable place image registration
-- -----------------------------------------------------------------------------
-- Phone-local file paths must never become catalogue image references. Images
-- are uploaded first, then registered atomically after ownership and Storage
-- object existence are verified.
-- =============================================================================

begin;

create unique index if not exists place_images_storage_path_uidx
  on public.place_images (storage_path);

create or replace function public.register_provider_place_images(
  _place_id uuid,
  _storage_paths text[],
  _alt_text text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _provider_id uuid;
  _path text;
  _index int := 0;
  _cover_reference text;
begin
  if _uid is null then
    raise exception 'authentication required';
  end if;

  if coalesce(cardinality(_storage_paths), 0) < 1
     or cardinality(_storage_paths) > 10 then
    raise exception 'between 1 and 10 images are required';
  end if;

  select p.id
    into _provider_id
  from public.providers p
  join public.places pl on pl.provider_id = p.id
  where p.owner_id = _uid
    and p.deleted_at is null
    and pl.id = _place_id
    and pl.deleted_at is null
    and (
      pl.status in ('pending', 'under_review')
      or (pl.status = 'rejected' and coalesce(pl.edit_allowed, false))
      or (
        pl.status = 'approved'
        and coalesce(pl.edit_allowed, false)
        and coalesce(pl.edit_request_status, 'none') = 'approved'
      )
    )
  limit 1;

  if _provider_id is null then
    raise exception 'place is not available for image updates';
  end if;

  foreach _path in array _storage_paths loop
    if _path is null
       or _path !~ ('^' || _provider_id::text || '/' || _place_id::text || '/')
       or not exists (
         select 1
         from storage.objects obj
         where obj.bucket_id = 'place-images'
           and obj.name = _path
       ) then
      raise exception 'invalid place image';
    end if;
  end loop;

  update public.place_images
     set is_cover = false
   where place_id = _place_id
     and is_cover;

  foreach _path in array _storage_paths loop
    insert into public.place_images (
      place_id,
      storage_path,
      is_cover,
      alt_text,
      sort_order
    )
    values (
      _place_id,
      _path,
      _index = 0,
      nullif(trim(_alt_text), ''),
      _index
    )
    on conflict (storage_path) do update
      set place_id = excluded.place_id,
          is_cover = excluded.is_cover,
          alt_text = excluded.alt_text,
          sort_order = excluded.sort_order;

    if _index = 0 then
      _cover_reference := 'place-images://' || _path;
    end if;
    _index := _index + 1;
  end loop;

  update public.places
     set image_path = _cover_reference,
         updated_at = now()
   where id = _place_id;

  return _cover_reference;
end;
$$;

revoke all on function public.register_provider_place_images(uuid, text[], text)
  from public;
grant execute on function public.register_provider_place_images(uuid, text[], text)
  to authenticated;

-- Owners may maintain gallery metadata for places they own. Public visibility
-- is still controlled by the parent place moderation state.
drop policy if exists place_images_update_owner on public.place_images;
create policy place_images_update_owner
  on public.place_images for update
  to authenticated
  using (
    exists (
      select 1
      from public.places pl
      join public.providers p on p.id = pl.provider_id
      where pl.id = place_images.place_id
        and p.owner_id = auth.uid()
        and p.deleted_at is null
    )
  )
  with check (
    exists (
      select 1
      from public.places pl
      join public.providers p on p.id = pl.provider_id
      where pl.id = place_images.place_id
        and p.owner_id = auth.uid()
        and p.deleted_at is null
    )
  );

-- Repair legacy rows where a temporary phone path was saved even though a
-- durable cover already exists in place_images.
with durable_covers as (
  select distinct on (pi.place_id)
    pi.place_id,
    pi.storage_path
  from public.place_images pi
  order by
    pi.place_id,
    pi.is_cover desc,
    pi.sort_order asc,
    pi.created_at asc
)
update public.places pl
   set image_path = 'place-images://' || dc.storage_path,
       updated_at = now()
  from durable_covers dc
 where dc.place_id = pl.id
   and (
     pl.image_path is null
     or (
       pl.image_path not like 'https://%'
       and pl.image_path not like 'http://%'
       and pl.image_path not like 'place-images://%'
     )
   );

commit;
