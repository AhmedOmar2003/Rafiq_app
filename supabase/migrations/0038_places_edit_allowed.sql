-- =============================================================================
-- 0038  places.edit_allowed — let admins gate the "edit & resubmit" path
-- -----------------------------------------------------------------------------
-- Product rule (per launch spec)
--   When a place is rejected, the admin may decide "the reason is fixable —
--   let the provider edit and resubmit", or "this place can't be saved —
--   keep it locked". The provider's hub respects that choice and either
--   shows a "Resubmit edit" button or only the "Appeal" path.
--
--   * edit_allowed = true  → provider sees the edit affordance on the
--                            rejected card; saving the edit flips
--                            status back to 'pending' so it re-enters the
--                            review queue.
--   * edit_allowed = false → only the appeal path is offered.
--
-- Default is false on rejected rows: the admin has to consciously open
-- the gate. Pending/approved rows ignore the flag (irrelevant).
-- =============================================================================

begin;

alter table public.places
  add column if not exists edit_allowed boolean not null default false;

-- Helpful for the dashboard query that filters rejected+editable.
create index if not exists places_rejected_editable_idx
  on public.places (status, edit_allowed)
  where status = 'rejected';

-- Don't try to insert the column via legacy admin pages that aren't aware
-- of it — the default handles INSERT just fine.

commit;
