-- =============================================================================
-- 0062  Public place details context RPC
-- -----------------------------------------------------------------------------
-- Goal:
--   Reduce place-details round trips by returning gallery, latest review,
--   active campaigns, and favorite state in one public-safe RPC.
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
  _review_row jsonb := null;
begin
  select *
    into _place
  from public.places pl
  where pl.deleted_at is null
    and pl.status = 'approved'
    and (
      (_place_uuid is not null and pl.id = _place_uuid)
      or (_place_uuid is null and _legacy_place_id is not null and pl.place_id = _legacy_place_id)
    )
  limit 1;

  if _place.id is null then
    return jsonb_build_object(
      'place_uuid', null,
      'place_id', null,
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

  select to_jsonb(r)
    into _review_row
  from public.reviews r
  where r.place_id = coalesce(_legacy_place_id, _place.place_id)
  order by r.created_at desc
  limit 1;

  if _review_row is not null then
    _latest_review := jsonb_build_object(
      'review_id', coalesce(_review_row->'review_id', _review_row->'id'),
      'place_id', _review_row->'place_id',
      'user_id', _review_row->'user_id',
      'name', coalesce(_review_row->'name', to_jsonb(''::text)),
      'review_text', coalesce(_review_row->'review_text', _review_row->'body', to_jsonb(''::text)),
      'rating', coalesce(_review_row->'rating', to_jsonb(5)),
      'image', coalesce(_review_row->'image', to_jsonb(''::text)),
      'created_at', _review_row->'created_at'
    );
  end if;

  return jsonb_build_object(
    'place_uuid', _place.id,
    'place_id', _place.place_id,
    'gallery', _gallery,
    'campaigns', _campaigns,
    'latest_review', _latest_review,
    'is_favorited', _is_favorited
  );
end;
$$;

revoke all on function public.get_place_details_context(uuid, bigint) from public;
grant execute on function public.get_place_details_context(uuid, bigint) to anon, authenticated;

commit;
