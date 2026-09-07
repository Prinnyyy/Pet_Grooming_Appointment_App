import assert from "node:assert/strict";
import { makeBackendPlans, runMarketplaceLifecycle } from "./testops-core.mjs";

export async function verifySaveAcceptance({ api, query, groomerID, token, closedWeek, original, order, onSaved }) {
  const runID = `TESTOPS-T371-${Date.now()}`;
  const [plan] = makeBackendPlans({ runID });
  const customer = await api.signIn(plan.customer.email, plan.customer.password);
  const customerID = customer.user.id;
  assert.match(customerID, /^[0-9a-f-]{36}$/i);
  const pair = `customer_id='${customerID}' and groomer_id='${groomerID}'`;
  assert.equal(query(`select count(*)::int as count from public.conversations where ${pair}`)[0].count, 0,
    "Dedicated fixture pair must have no pre-existing conversation");
  const finished = new Error("T371_VERIFIED_STOP_BEFORE_COMPLETION");
  let verified = false;
  let receipt;
  const tagged = `service_notes like 'TESTOPS:${runID} %' and customer_id='${customerID}'`;
  try {
    const proxy = {
      signIn: api.signIn.bind(api),
      restSelect: api.restSelect.bind(api),
      rpc: async (name, params, accessToken) => {
        if (name !== "accept_groomer_offer") return api.rpc(name, params, accessToken);
        const save = async () => {
          const snapshot = await api.rpc("save_groomer_availability", {
            p_expected_revision: original.revision, p_windows: closedWeek,
            p_preferences: original.preferences, p_time_off: original.time_off,
          }, token);
          onSaved(snapshot);
          return snapshot;
        };
        const accept = () => api.rpc(name, params, accessToken);
        let acceptance;
        if (order === "save-first") {
          await save();
          acceptance = await Promise.allSettled([accept()]);
        } else if (order === "accept-first") {
          acceptance = await Promise.allSettled([accept()]);
          await save();
        } else {
          const results = await Promise.allSettled([save(), accept()]);
          assert.equal(results[0].status, "fulfilled", "Concurrent Save must finish successfully");
          acceptance = [results[1]];
        }
        const result = acceptance[0];
        if (order === "accept-first") assert.equal(result.status, "fulfilled");
        if (order === "save-first") assert.equal(result.status, "rejected");
        const rows = query(`select status from public.bookings where request_id in (select id from public.grooming_requests where ${tagged})`);
        if (result.status === "fulfilled") {
          receipt = result.value[0];
          assert.ok(receipt?.booking_id);
          assert.equal(rows.length, 1);
          assert.equal(rows[0].status, "confirmed", "Save must preserve the accepted booking");
        } else {
          assert.match(String(result.reason), /booking_conflict/);
          assert.equal(rows.length, 0, "Rejected acceptance must not create a booking");
        }
        verified = true;
        console.log(`PASS: ${order}; acceptance ${result.status}; booking invariant holds`);
        throw finished;
      },
    };
    try { await runMarketplaceLifecycle(proxy, plan); }
    catch (error) { if (error !== finished) throw error; }
    assert.ok(verified, "Fixture did not reach actual acceptance");
  } finally {
    // This pair was empty before the run. Refuse to remove unexpected messages
    // or bookings that do not belong to the precisely tagged request.
    query(`begin; set local statement_timeout='30s';
      do $cleanup$ declare r record; c uuid; begin
        for r in select id from public.grooming_requests where ${tagged} loop
          select id into c from public.conversations where ${pair};
          if c is not null then
            if exists(select 1 from public.bookings where ${pair} and request_id<>r.id)
              or (select count(*) from public.messages where conversation_id=c)>2 then
              raise exception 'Unexpected conversation activity; cleanup refused';
            end if;
            delete from public.conversations where id=c;
          end if;
          delete from public.customer_notifications where related_request_id=r.id
            or related_booking_id in(select id from public.bookings where request_id=r.id);
          delete from public.groomer_notifications where related_request_id=r.id
            or related_booking_id in(select id from public.bookings where request_id=r.id);
          perform public.cleanup_testops_request_address_location(r.id,'${runID}');
          delete from public.grooming_requests where id=r.id;
        end loop;
      end; $cleanup$; commit;`);
    assert.equal(query(`select count(*)::int as count from public.grooming_requests where ${tagged}`)[0].count, 0);
    assert.equal(query(`select count(*)::int as count from public.conversations where ${pair}`)[0].count, 0);
    console.log("PASS: tagged acceptance fixture and isolated conversation removed");
  }
}
