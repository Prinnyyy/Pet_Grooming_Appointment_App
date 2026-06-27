-- T-095: allow authenticated client writes to run approved app_private helpers
-- through table triggers and check constraints without exposing anon access.

grant usage on schema app_private to authenticated, service_role;
