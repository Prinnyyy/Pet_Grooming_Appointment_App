-- T-020 reviewed SQL draft.
-- Authorized target: lqmasbuqzvcvtawonjlb only.
-- Do not apply without explicit user approval.

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null
    references public.conversations (id) on delete cascade,
  sender_id uuid not null
    references public.profiles (id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint messages_body_check check (
    body = regexp_replace(body, '^[[:space:]]+|[[:space:]]+$', '', 'g')
    and char_length(body) >= 1
    and char_length(body) <= 4000
  )
);

comment on table public.messages is
  'Text-only participant messages under a booking conversation.';
comment on column public.messages.conversation_id is
  'Conversation boundary created by T-018 booking acceptance.';
comment on column public.messages.sender_id is
  'Authenticated participant who sent the message.';
comment on column public.messages.body is
  'Trimmed text-only message body. Attachments are deferred beyond T-020.';

comment on table public.conversations is
  'Participant boundary created atomically with an accepted booking. Text messages are stored in public.messages.';

create index messages_conversation_created_idx
on public.messages (conversation_id, created_at asc, id asc);

create index messages_sender_created_idx
on public.messages (sender_id, created_at desc);

alter table public.messages enable row level security;

revoke all on table public.messages from public, anon, authenticated;

grant select on table public.messages to authenticated;
grant insert (conversation_id, sender_id, body)
on table public.messages
to authenticated;

grant select, insert, update, delete
on table public.messages
to service_role;

create policy messages_select_conversation_participants
on public.messages
for select
to authenticated
using (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and exists (
    select 1
    from public.conversations as conversation
    where conversation.id = messages.conversation_id
      and (
        (
          conversation.customer_id = (select auth.uid())
          and exists (
            select 1
            from public.customer_profiles
            where user_id = (select auth.uid())
          )
        )
        or (
          conversation.groomer_id = (select auth.uid())
          and exists (
            select 1
            from public.groomer_profiles
            where user_id = (select auth.uid())
          )
        )
      )
  )
);

create policy messages_insert_conversation_participants
on public.messages
for insert
to authenticated
with check (
  (select auth.uid()) is not null
  and not coalesce(((select auth.jwt()) ->> 'is_anonymous')::boolean, false)
  and sender_id = (select auth.uid())
  and exists (
    select 1
    from public.conversations as conversation
    where conversation.id = messages.conversation_id
      and (
        (
          conversation.customer_id = (select auth.uid())
          and exists (
            select 1
            from public.customer_profiles
            where user_id = (select auth.uid())
          )
        )
        or (
          conversation.groomer_id = (select auth.uid())
          and exists (
            select 1
            from public.groomer_profiles
            where user_id = (select auth.uid())
          )
        )
      )
  )
);
