alter table public.customer_notifications
  add column related_conversation_id uuid references public.conversations(id) on delete set null;
alter table public.groomer_notifications
  add column related_conversation_id uuid references public.conversations(id) on delete set null;

create index customer_notifications_related_conversation_idx
  on public.customer_notifications(related_conversation_id) where related_conversation_id is not null;
create index groomer_notifications_related_conversation_idx
  on public.groomer_notifications(related_conversation_id) where related_conversation_id is not null;

create or replace function app_private.customer_notifications_after_groomer_message_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_customer_id uuid; v_groomer_id uuid;
begin
  if new.kind <> 'text' then return new; end if;
  select conversation.customer_id, conversation.groomer_id
    into v_customer_id, v_groomer_id from public.conversations as conversation
    where conversation.id = new.conversation_id;
  if found and new.sender_id = v_groomer_id then
    insert into public.customer_notifications(customer_id, kind, title, body, related_conversation_id)
      values(v_customer_id, 'new_message', 'New message', 'Your groomer sent you a message.', new.conversation_id);
  end if;
  return new;
end $$;

create or replace function app_private.groomer_notifications_after_customer_message_insert()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_customer_id uuid; v_groomer_id uuid;
begin
  if new.kind <> 'text' then return new; end if;
  select conversation.customer_id, conversation.groomer_id
    into v_customer_id, v_groomer_id from public.conversations as conversation
    where conversation.id = new.conversation_id;
  if found and new.sender_id = v_customer_id then
    insert into public.groomer_notifications(groomer_id, kind, title, body, related_conversation_id)
      values(v_groomer_id, 'new_message', 'New message', 'Your customer sent you a message.', new.conversation_id);
  end if;
  return new;
end $$;

revoke all on function app_private.customer_notifications_after_groomer_message_insert()
  from public, anon, authenticated, service_role;
revoke all on function app_private.groomer_notifications_after_customer_message_insert()
  from public, anon, authenticated, service_role;

notify pgrst, 'reload schema';
