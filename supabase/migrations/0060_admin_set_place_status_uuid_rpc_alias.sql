-- 0060  PostgREST-safe UUID RPC alias for place moderation
--
-- Why:
-- PostgREST resolves RPCs by name and JSON argument keys, and it can choose the
-- bigint overload of admin_set_place_status() before the UUID overload when the
-- caller passes a string UUID. SQL callers can disambiguate, but REST callers
-- like k6 and future dashboard UUID flows cannot. This alias exposes a stable,
-- explicit UUID entrypoint for REST clients while preserving the existing
-- bigint RPC used by legacy dashboard flows.

create or replace function public.admin_set_place_status_uuid(
  _place_uuid uuid,
  _status public.moderation_status,
  _rejection_reason text default null,
  _allow_edit boolean default false
)
returns jsonb
language sql
security definer
set search_path = public
as $$
  select public.admin_set_place_status(
    _place_uuid,
    _status,
    _rejection_reason,
    _allow_edit
  );
$$;

revoke all on function public.admin_set_place_status_uuid(
  uuid,
  public.moderation_status,
  text,
  boolean
) from public;

grant execute on function public.admin_set_place_status_uuid(
  uuid,
  public.moderation_status,
  text,
  boolean
) to service_role;

comment on function public.admin_set_place_status_uuid(
  uuid,
  public.moderation_status,
  text,
  boolean
) is
  'REST-safe UUID moderation RPC for places. Calls the canonical UUID overload of admin_set_place_status().';
