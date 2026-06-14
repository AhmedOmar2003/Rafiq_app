-- =============================================================================
-- 0063  Fix place details context for the canonical UUID schema
-- -----------------------------------------------------------------------------
-- Fresh environments do not have the legacy bigint places.place_id column.
-- Keep the legacy argument in the public function signature for client
-- compatibility, but resolve all canonical relations through places.id.
-- =============================================================================

begin;

create or replace function public.get_place_details_context(
  _place_uuid uuid default null,
  _legacy_place_id bigint default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  _place public.places%rowtype;
  _gallery jsonb := '[]'::jsonb;
  _campaigns jsonb := '[]'::jsonb;
  _latest_review jsonb := null;
  _is_favorited boolean := false;
begin
  if _place_uuid is null then
    return jsonb_build_object(
      'place_uuid', null,
      'place_id', _legacy_place_id,
      'gallery', '[]'::jsonb,
      'campaigns', '[]'::jsonb,
      'latest_review', null,
      'is_favorited', false
    );
  end if;

  select *
    into _place
  from public.places pl
  where pl.id = _place_uuid
    and pl.deleted_at is null
    and pl.status = 'approved'
  limit 1;

  if _place.id is null then
    return jsonb_build_object(
      'place_uuid', null,
      'place_id', _legacy_place_id,
      'gallery', '[]'::jsonb,
      'campaigns', '[]'::jsonb,
      'latest_review', null,
      'is_favorited', false
    );
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'storage_path', img.storage_path,
        'is_cover', img.is_cover,
        'sort_order', img.sort_order,
        'created_at', img.created_at
      )
      order by img.is_cover desc, img.sort_order asc, img.created_at asc
    ),
    '[]'::jsonb
  )
    into _gallery
  from public.place_images img
  where img.place_id = _place.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', c.id,
        'title', c.title,
        'body', c.body,
        'kind', c.kind,
        'status', c.status,
        'image_path', c.image_path,
        'cta_label', c.cta_label,
        'starts_at', c.starts_at,
        'ends_at', c.ends_at
      )
      order by c.created_at desc
    ),
    '[]'::jsonb
  )
    into _campaigns
  from public.promotional_campaigns c
  where c.place_id = _place.id
    and c.status = 'active'
    and now() between c.starts_at and c.ends_at;

  if auth.uid() is not null then
    select exists (
      select 1
      from public.favorites f
      where f.user_id = auth.uid()
        and f.place_id = _place.id
    )
      into _is_favorited;
  end if;

  select jsonb_build_object(
    'review_id', r.id,
    'place_id', coalesce(_legacy_place_id, 0),
    'user_id', r.user_id,
    'name', coalesce(pr.full_name, ''),
    'review_text', r.body,
    'rating', r.rating,
    'image', '',
    'created_at', r.created_at
  )
    into _latest_review
  from public.reviews r
  left join public.profiles pr on pr.id = r.user_id
  where r.place_id = _place.id
    and r.is_hidden = false
    and r.deleted_at is null
  order by r.created_at desc
  limit 1;

  return jsonb_build_object(
    'place_uuid', _place.id,
    'place_id', _legacy_place_id,
    'gallery', _gallery,
    'campaigns', _campaigns,
    'latest_review', _latest_review,
    'is_favorited', _is_favorited
  );
end;
$$;

revoke all on function public.get_place_details_context(uuid, bigint) from public;
grant execute on function public.get_place_details_context(uuid, bigint)
  to anon, authenticated;

commit;
