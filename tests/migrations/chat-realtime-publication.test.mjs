import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import { test } from "node:test";

test("participant messages are explicitly published without widening table access", () => {
  const file = readdirSync("supabase/migrations").find(name => name.endsWith("_t385_chat_realtime_publication.sql"));
  assert.ok(file, "missing deployed chat publication contract");
  const sql = readFileSync(`supabase/migrations/${file}`, "utf8");
  assert.match(sql, /alter publication supabase_realtime add table public\.messages/i);
  assert.match(sql, /pg_publication_tables[\s\S]*tablename\s*=\s*'messages'/i);
  assert.match(sql, /relrowsecurity/i);
  assert.doesNotMatch(sql, /for all tables|disable row level security|grant\s|create policy|replica identity full/i);
  assert.doesNotMatch(sql, /drop publication|set\s*\(\s*publish/i);
});
