-- The existing authenticated participant policy also governs Realtime INSERTs.
-- Subscription acknowledgement alone does not prove a table is replicated.
do $$
begin
  if not exists (select 1 from pg_class where oid = 'public.messages'::regclass and relrowsecurity) then
    raise exception 'Participant message RLS must be enabled before replication';
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
end;
$$;
