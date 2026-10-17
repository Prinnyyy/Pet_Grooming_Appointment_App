-- A preview cannot outlive its private address. Publication receipts deliberately
-- have no session FK and remain replayable after preview/address cleanup.
alter table app_private.request_discovery_sessions
  drop constraint request_discovery_sessions_address_location_id_fkey,
  add constraint request_discovery_sessions_address_location_id_fkey
    foreign key (address_location_id) references app_private.address_locations(id)
    on delete cascade;
