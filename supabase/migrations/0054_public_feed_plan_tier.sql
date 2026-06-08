begin;

drop function if exists public.browse_ranked_places(text, text, text, int);

create function public.browse_ranked_places(
  _city_name text default null,
  _budget text default null,
  _activity_name text default null,
  _limit int default 100
)
returns setof jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select
    to_jsonb(pl)
    || jsonb_build_object(
      'plan_tier',
      case
        when pl.provider_id is null then null
        else coalesce(plan.tier::text, 'free')
      end
    )
  from public.places pl
  left join public.provider_current_plan plan
    on plan.provider_id = pl.provider_id
  where pl.status = 'approved'
    and pl.deleted_at is null
    and (_city_name is null or pl.city_name = _city_name)
    and (_budget is null or pl.budget = _budget)
    and (_activity_name is null or pl.activity_name = _activity_name)
  order by
    (
      (
        0.65 * least(1.0, greatest(0.0, coalesce(pl.rating_avg, pl.rating, 0) / 5.0))
        + 0.20 * least(
          1.0,
          ln(1 + greatest(coalesce(pl.rating_count, 0), 0)) / ln(1001.0)
        )
        + 0.15 * exp(
          -greatest(
            0.0,
            extract(epoch from (now() - coalesce(pl.created_at, now()))) / 86400.0
          ) / 60.0
        )
      )
      * (
        1.0
        + least(0.25, greatest(0.0, coalesce(plan.ranking_boost, 1.0) - 1.0) * 0.25)
      )
    ) desc,
    coalesce(pl.rating_avg, pl.rating, 0) desc,
    pl.created_at desc
  limit greatest(1, least(coalesce(_limit, 100), 250));
$$;

comment on function public.browse_ranked_places(text, text, text, int) is
  'Approved public feed with quality ranking and the provider plan tier required for honest Pro/Max presentation. Admin-created places return no tier.';

revoke all on function public.browse_ranked_places(text, text, text, int)
  from public;
grant execute on function public.browse_ranked_places(text, text, text, int)
  to anon, authenticated;

commit;
