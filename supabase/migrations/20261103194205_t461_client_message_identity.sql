-- Allow an authenticated sender to reuse a stable UUID when retrying a text message.
-- Existing participant, sender, kind, booking and read-only RLS checks remain authoritative.
-- No UPDATE/DELETE grant, timestamp control, new table or privileged RPC is introduced.
begin;
grant insert (id) on table public.messages to authenticated;
commit;
