import assert from "node:assert/strict";
import { readFileSync, readdirSync } from "node:fs";
import test from "node:test";

const directory = "supabase/migrations";
const file = readdirSync(directory).find(name => name.endsWith("_t373_pet_capacity_acceptance.sql"));
const sql = file ? readFileSync(`${directory}/${file}`, "utf8") : "";

test("pet capacity is a non-null database exclusion tied to the owned request", () => {
  assert.match(sql, /bookings_no_pet_time_overlap/);
  assert.match(sql, /exclude using gist[\s\S]*pet_id with =[\s\S]*tstzrange/);
  assert.match(sql, /foreign key \(request_id, customer_id, pet_id\)/);
  assert.match(sql, /alter column pet_id set not null/);
  assert.match(sql, /legacy_pet_identity_unresolved/);
});

test("every booking admission is guarded while terminal transitions do not re-admit", () => {
  assert.match(sql, /before insert or update on public.bookings/);
  assert.match(sql, /pg_advisory_xact_lock/);
  assert.match(sql, /groomer_is_available_for_range/);
  assert.match(sql, /booking_allocation_immutable/);
});

test("owned accepted offer replay precedes pending checks and reads current booking state", () => {
  assert.match(sql, /offer_status = 'accepted_by_customer'/);
  assert.match(sql, /existing_booking.status/);
  assert.match(sql, /groomer_offer.customer_id = v_user_id/);
  assert.ok(sql.indexOf("offer_status = 'accepted_by_customer'") < sql.indexOf("message = 'offer_not_pending'"));
  assert.match(sql, /for update of grooming_request/);
});

test("offer creation withdrawal and dismissal take the request lock before child rows", () => {
  for (const name of ["create_groomer_offer", "withdraw_groomer_offer", "dismiss_request_match"]) {
    const body = sql.split(`FUNCTION app_private.${name}(`)[1]?.split("$function$;")[0] ?? "";
    assert.ok(body.includes("for update of parent_request"), `${name} needs an owned request-first lock`);
    assert.ok(body.indexOf("for update of parent_request") < body.indexOf("for update of request_match") ||
      body.indexOf("for update of parent_request") < body.indexOf("for update of groomer_offer"));
  }
});
