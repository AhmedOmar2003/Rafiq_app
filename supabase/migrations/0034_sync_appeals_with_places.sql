-- =============================================================================
-- 0034  Sync appeals with place status
-- -----------------------------------------------------------------------------
-- Automatically updates `places.status` when `place_appeals.status` changes.
-- Ensures strict consistency between appeal decisions and place state.
-- =============================================================================

begin;

create or replace function public.sync_appeal_with_place()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _current_place_status public.moderation_status;
begin
  -- Only act when the status actually changes
  if new.status is distinct from old.status then
    
    -- When the appeal is resolved, we approve the place and clear the rejection reason.
    if new.status = 'resolved' then
      update public.places
         set status = 'approved',
             rejection_reason = null,
             approved_at = now(),
             updated_at = now()
       where place_id = new.place_id;
       
    -- When the appeal starts reviewing, we update the place to under_review to notify the provider
    elsif new.status = 'reviewing' then
      update public.places
         set status = 'under_review',
             updated_at = now()
       where place_id = new.place_id;
       
    -- When the appeal is rejected, the place remains rejected
    elsif new.status = 'rejected' then
      update public.places
         set status = 'rejected',
             updated_at = now()
       where place_id = new.place_id;
    end if;
    
  end if;
  return new;
end;
$$;

drop trigger if exists trg_sync_appeal_with_place on public.place_appeals;
create trigger trg_sync_appeal_with_place
  after update on public.place_appeals
  for each row execute function public.sync_appeal_with_place();

commit;
