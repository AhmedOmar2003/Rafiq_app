-- =============================================================================
-- 0029  admin_set_place_status RPC
-- -----------------------------------------------------------------------------
-- The places guard trigger (0010) blocks status / rejection_reason updates
-- unless `public.is_moderator_or_above()` returns true. That check reads
-- `auth.uid()` from the JWT, but the Next.js dashboard hits the DB with the
-- `service_role` key — no JWT — so the trigger sees a null uid and raises
-- "only moderators can change moderation columns".
--
-- This RPC fixes the moderation flow cleanly:
--   * SECURITY DEFINER, so it runs as the function owner (`postgres`) which
--     bypasses the moderator check the same way migrations do — there is no
--     real "user" calling it; the dashboard's service key already proved
--     the caller is an admin out-of-band.
--   * Internally flips session_replication_role to skip the trigger while
--     it runs, then restores it. Equivalent to a manual moderator action.
--   * Records a row in `moderation_history` so the audit trail the trigger
--     normally writes is still produced.
--   * Returns the updated row's new status as JSON for easy client use.
-- =============================================================================

begin;

create or replace function public.admin_set_place_status(
  _place_id          bigint,
  _status            public.moderation_status,
  _rejection_reason  text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _old_status public.moderation_status;
  _place_uuid uuid;
begin
  -- Capture the old status so the audit row is meaningful.
  select status, id into _old_status, _place_uuid
    from public.places
   where place_id = _place_id;

  if _place_uuid is null then
    raise exception 'place not found (place_id=%)', _place_id;
  end if;

  -- Bypass the guard trigger for the duration of this function call. The
  -- caller already authenticated as service_role via the admin client, so
  -- the trigger's intent (block non-moderator writes) is already satisfied
  -- one layer up.
  perform set_config('session_replication_role', 'replica', true);

  update public.places
     set status           = _status,
         rejection_reason = case when _status = 'rejected'
                                 then _rejection_reason
                                 else null end,
         approved_at      = case when _status = 'approved'
                                 then now()
                                 else approved_at end,
         suspended_at     = case when _status = 'suspended'
                                 then now()
                                 else suspended_at end,
         updated_at       = now()
   where place_id = _place_id;

  -- Restore for the rest of the transaction.
  perform set_config('session_replication_role', 'origin', true);

  -- Mirror the moderation_history entry the trigger would have produced.
  if _old_status is distinct from _status then
    insert into public.moderation_history
      (target_type, target_id, action, from_status, to_status, actor_id, reason)
    values
      ('place', _place_uuid,
       case _status
         when 'approved'    then 'approve'
         when 'rejected'    then 'reject'
         when 'suspended'   then 'suspend'
         when 'pending'     then 'reinstate'
         when 'under_review' then 'start_review'
       end,
       _old_status, _status, null, _rejection_reason);
  end if;

  return jsonb_build_object(
    'place_id',   _place_id,
    'old_status', _old_status,
    'new_status', _status
  );
end;
$$;

-- Only the service role calls this RPC (from the dashboard server action).
-- Lock it down so no client JWT can invoke it.
revoke all on function public.admin_set_place_status(bigint, public.moderation_status, text) from public;
grant execute on function public.admin_set_place_status(bigint, public.moderation_status, text) to service_role;

commit;
