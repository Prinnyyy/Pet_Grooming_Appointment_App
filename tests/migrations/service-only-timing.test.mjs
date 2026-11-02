import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
const sql = readFileSync('supabase/migrations/20261102071341_groomer_service_only_timing.sql','utf8');
const body = name => sql.split(`FUNCTION app_private.${name}(`)[1]?.split('$function$;')[0] ?? '';

test('service-only allocation ignores removed settings and preserves duration/location guards', () => {
  const allocation = body('service_timing_allocation');
  assert.match(allocation,/not between 15 and 720/);
  assert.match(allocation,/invalid_location_mode/);
  assert.match(allocation,/return query select p_start, v_end, p_start, v_end/);
  assert.doesNotMatch(allocation,/invalid_timing_buffers|p_start -|v_end \+/);
  assert.match(body('snapshot_offer_timing'),/"preparation_minutes":0,"cleanup_minutes":0,"inbound_travel_minutes":0,"outbound_travel_minutes":0/);
  assert.doesNotMatch(sql,/timing_buffers_confirmation_required|buffers_known|tail_minutes/);
});
test('frozen commercial facts remain immutable and padded old quotes need the existing replacement path', () => {
  for (const [name, guard] of [['snapshot_offer_timing','offer_timing_snapshot_immutable'],['snapshot_booking_timing','booking_timing_snapshot_immutable']]) {
    assert.match(body(name),new RegExp(guard));
  }
  assert.match(body('evaluate_quote'),/reason:='legacy_unverified'/);
  assert.match(body('snapshot_booking_timing'),/updated_timing_offer_required/);
  assert.doesNotMatch(sql,/^update public\.(?:bookings|groomer_offers) set/im);
  assert.match(body('validate_reschedule_candidate'),/authorized_reschedule_change|reschedule_agreement_verification_required/);
  assert.match(body('validate_reschedule_candidate'),/v_occupied_start:=p_start;\s*v_occupied_end:=ending/);
});
test('all admission paths keep coverage, quota, locks and service-only overlap with a rebuilt expression constraint', () => {
  for (const text of ['pg_advisory_xact_lock','occupied_time_off_conflict','occupied_weekly_hours_covered','weekly_hours_cover_interval','reschedule_daily_limit','service_timing_earliest_start','availability_revision_conflict']) assert.ok(sql.includes(text),text);
  assert.match(sql,/drop constraint bookings_no_groomer_occupied_overlap/);
  assert.match(sql,/tstzrange\(scheduled_start,app_private\.booking_resource_end/);
  assert.match(body('booking_resource_end'),/greatest\(p_service_start,least\(p_service_end,p_release\)\)/);
  assert.doesNotMatch(sql,/coalesce\(\w+\.occupied_start,\w+\.scheduled_start\)/);
  assert.match(sql,/enqueue_match_refresh\(g.user_id\)/);
  assert.doesNotMatch(sql,/disable (?:row level security|trigger)|grant .* to (?:public|anon|authenticated)/i);
});
