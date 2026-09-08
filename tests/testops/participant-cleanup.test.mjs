import assert from "node:assert/strict";
import test from "node:test";
import { cleanupRun } from "../../scripts/testops-core.mjs";

test("cleanup follows booking cards and never deletes participant conversations or untagged chat", async () => {
  let reads = 0;
  const deletes = [];
  const api = {
    requireServiceRole: () => "fixture",
    async restSelect(table, query) {
      if (table === "grooming_requests") return reads++ === 0
        ? [{ id: "request", service_notes: "TESTOPS:TESTOPS-T374-CLEANUP" }] : [];
      if (table === "bookings") return [{ id: "booking" }];
      assert.equal(table, "messages", "Never query removed conversation request columns");
      assert.equal(query, "select=conversation_id&booking_id=in.(booking)");
      return [{ conversation_id: "shared" }];
    },
    async rpc() { return false; },
    async restDelete(table, query) {
      assert.notEqual(table, "conversations");
      if (table === "messages") assert.equal(query,
        "conversation_id=in.(shared)&or=(body.eq.TESTOPS%3ATESTOPS-T374-CLEANUP,body.like.TESTOPS%3ATESTOPS-T374-CLEANUP%20*)");
      deletes.push(table);
      return 1;
    },
  };
  const result = await cleanupRun(api, "TESTOPS-T374-CLEANUP");
  assert.equal(result.preservedParticipantConversationCount, 1);
  assert.equal(result.remainingTaggedRequests, 0);
  assert.ok(deletes.includes("bookings"));
  assert.ok(deletes.includes("messages"));
});
