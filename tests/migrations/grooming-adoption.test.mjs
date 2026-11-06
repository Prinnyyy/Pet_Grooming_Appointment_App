import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import test from 'node:test';
const migration = name => readFileSync('supabase/migrations/' + readdirSync('supabase/migrations').find(x => x.endsWith(name + '.sql')), 'utf8');
// Static security/lock boundaries. Transactional SQL and concurrent acceptance
// verification are separate: these checks deliberately do not claim runtime proof.
test('clock-start completion retains participant identity, intent replay and revision locks', () => {
 const s = migration('t466_grooming_lifecycle');
 assert.match(s,/completed_by IN \(customer_id, groomer_id\)/);
 assert.match(s,/actor=b.customer_id and role='customer'/);
 assert.match(s,/fulfillment_operation_intent_changed/);
 assert.match(s,/booking_revision_changed/);
 assert.match(s,/at_time:=clock_timestamp\(\)/);
 assert.match(s,/if at_time<b.scheduled_start/);
 assert.doesNotMatch(s,/when '(start|report_interruption|report_no_show|close_elapsed)' then/);
 assert.match(s,/WHERE|where o.booking_id=b.id/);
 assert.doesNotMatch(s,/insert into public.messages[\s\S]*?'text'/);
});
test('overlap closure is durable, excludes touching intervals and never locks another offer under admission lock', () => {
 const s = migration('t466_offer_conflict_closure');
 const trigger = s.slice(s.indexOf('create function app_private.record_offer_booking_conflicts'),s.indexOf('create function app_private.close_conflicting_offers'));
 assert.match(trigger,/tstzrange\(o.proposed_start,o.proposed_end,'\[\)'\)/);
 assert.doesNotMatch(trigger,/for update|update public.groomer_offers|update public.grooming_requests/i);
 assert.doesNotMatch(s,/offer_id uuid primary key references/);
 assert.match(s,/delete from app_private.offer_booking_conflicts where offer_id=old.id/);
 assert.match(s,/on conflict\(offer_id\) do nothing/);
 assert.match(s,/if exists\(select 1 from app_private.offer_booking_conflicts conflict where conflict.offer_id=p_offer_id\)/);
 assert.match(s,/reason:='time_slot_booked'/);
 assert.doesNotMatch(s,/grant .*offer_booking_conflicts/i);
});
test('first contact checks live counterpart consent and message insert rechecks it', () => {
 const s = migration('t466_request_chat');
 for (const token of ['i.withdrawn_at IS NULL','i.declined_at IS NULL','i.terms_revision=r.terms_revision',"o.status='pending'",'new.sender_id IS DISTINCT FROM auth.uid()','messages_guard_first_contact','cardinality(p_conversation_ids)>100']) assert.ok(s.includes(token),token);
 assert.match(s,/actor.role='customer'/); assert.match(s,/actor.role='groomer'/);
 assert.doesNotMatch(s,/alter .* disable row level security|grant select.*profiles|create policy/i);
});
test('subtabs filter before paging and bind ranking cursor to location', () => {
 const s = migration('t466_grooming_filtered_reads');
 assert.match(s,/r.location_mode=p_location/);
 assert.match(s,/'matches'\|\|coalesce\(':'\|\|p_location,''\)/);
 assert.match(s,/cursor_data->>'scope' is distinct from scope/);
 assert.match(s,/o.status<>'withdrawn_by_groomer'/);
 assert.match(s,/p_group=case when o.status='accepted_by_customer'/);
 assert.match(s,/limit p_limit offset p_offset/);
});
test('offers retain admission checks while removing preferred-window and forced-assessment consent', () => {
 const s = migration('t466_offer_proposal_rules');
 assert.match(s,/p_price_estimate > 9999.99/); assert.match(s,/char_length\(v_message\) > 200/);
 assert.match(s,/occupied_outside_weekly_hours/); assert.match(s,/groomer_can_admit_service/);
 assert.doesNotMatch(s,/service_crosses_local_day|offer_outside_requested_window/);
});
test('partial address projection fails closed and only own booking unlocks full address', () => {
 const s = migration('t466_request_address_projection');
 assert.match(s,/street=btrim\(p_street\) then return null/);
 assert.match(s,/b.request_id=p_request.id and b.groomer_id=auth.uid\(\)/);
 assert.match(s,/else app_private.request_street_name\(p_request.street_address\)/);
 assert.match(s,/'address_line_2',case when p_detail and exists/);
});
