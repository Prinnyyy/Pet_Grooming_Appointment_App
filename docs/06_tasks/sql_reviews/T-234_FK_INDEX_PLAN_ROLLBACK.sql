-- T-234 forced-plan validation. Run only after the migration is applied.
-- The transaction rolls back the local planner setting and performs no writes.

begin;

set local enable_seqscan = off;

do $$
begin
  if to_regclass(
    'public.customer_booking_handoff_acknowledgements_booking_id_idx'
  ) is null then
    raise exception 'missing customer_booking_handoff_acknowledgements_booking_id_idx';
  end if;

  if to_regclass('public.request_photos_customer_id_idx') is null then
    raise exception 'missing request_photos_customer_id_idx';
  end if;
end;
$$;

explain (costs on, format text)
select acknowledgement.id
from public.customer_booking_handoff_acknowledgements as acknowledgement
where acknowledgement.booking_id = '00000000-0000-0000-0000-000000000000';

explain (costs on, format text)
select request_photo.id
from public.request_photos as request_photo
where request_photo.customer_id = '00000000-0000-0000-0000-000000000000';

rollback;
