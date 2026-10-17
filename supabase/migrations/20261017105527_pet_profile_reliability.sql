-- T-406. Reuse pet fact validation; add creation receipts and edit CAS.
alter table public.pets add column revision uuid not null default gen_random_uuid();

create function app_private.advance_pet_revision()
returns trigger language plpgsql set search_path = '' as $$
begin
  if (to_jsonb(new)-array['revision','updated_at']) is distinct from
     (to_jsonb(old)-array['revision','updated_at']) then
    new.revision:=gen_random_uuid();
  else
    new.revision:=old.revision;
  end if;
  return new;
end $$;
revoke all on function app_private.advance_pet_revision() from public,anon,authenticated,service_role;
create trigger pets_zzz_revision before update on public.pets
for each row execute function app_private.advance_pet_revision();

create table app_private.pet_create_operations (
  customer_id uuid not null references public.customer_profiles(user_id) on delete cascade,
  operation_id uuid not null,
  canonical_hash text not null,
  pet_id uuid not null,
  created_revision uuid not null,
  created_at timestamptz not null default statement_timestamp(),
  primary key (customer_id, operation_id)
);
-- No pet FK: even a removed target must not make its create operation reusable.
alter table app_private.pet_create_operations enable row level security;
revoke all on table app_private.pet_create_operations from public,anon,authenticated,service_role;

create function app_private.save_my_pet_v3(p_pet_id uuid,p_facts jsonb,p_coat_confirmed boolean,
  p_operation_id uuid,p_expected_revision uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid:=app_private.require_request_customer(); pet public.pets%rowtype;
  receipt app_private.pet_create_operations%rowtype; intent text;
begin
  -- Serialize with account/profile removal before admitting a new write.
  perform 1 from public.profiles where id=actor for share;
  perform app_private.require_request_customer();
  if p_facts is null or jsonb_typeof(p_facts)<>'object' or p_coat_confirmed is null then
    raise exception using errcode='22023',message='invalid_pet_facts';
  end if;
  if p_pet_id is null then
    if p_operation_id is null or p_expected_revision is not null then
      raise exception using errcode='22023',message='invalid_pet_save_intent';
    end if;
    intent:=encode(extensions.digest(jsonb_build_object('facts',jsonb_strip_nulls(p_facts),
      'coat_confirmed',p_coat_confirmed)::text,'sha256'),'hex');
    perform pg_advisory_xact_lock(hashtextextended(actor::text||':pet:'||p_operation_id::text,0));
    select * into receipt from app_private.pet_create_operations
      where customer_id=actor and operation_id=p_operation_id;
    if found then
      if receipt.canonical_hash<>intent then
        raise exception using errcode='PT409',message='pet_operation_intent_changed';
      end if;
      select * into pet from public.pets where id=receipt.pet_id and customer_id=actor
        and is_active and deleted_at is null;
      return jsonb_build_object('pet_id',receipt.pet_id,'result_revision',receipt.created_revision,
        'replayed',true,'state',case when found then 'active' else 'unavailable' end,
        'pet',case when found then to_jsonb(pet) else null end);
    end if;
    select * into strict pet from app_private.save_my_pet_v2(null,p_facts,p_coat_confirmed);
    insert into app_private.pet_create_operations(customer_id,operation_id,canonical_hash,pet_id,created_revision)
      values(actor,p_operation_id,intent,pet.id,pet.revision);
  else
    if p_operation_id is not null or p_expected_revision is null then
      raise exception using errcode='22023',message='invalid_pet_save_intent';
    end if;
    select * into pet from public.pets where id=p_pet_id and customer_id=actor
      and is_active and deleted_at is null for update;
    if not found then raise exception using errcode='PT404',message='pet_not_found';end if;
    if pet.revision is distinct from p_expected_revision then
      raise exception using errcode='PT409',message='pet_revision_conflict';
    end if;
    select * into strict pet from app_private.save_my_pet_v2(p_pet_id,p_facts,p_coat_confirmed);
  end if;
  return jsonb_build_object('pet_id',pet.id,'result_revision',pet.revision,
    'replayed',false,'state','active','pet',to_jsonb(pet));
end $$;
create function public.save_my_pet_v3(p_pet_id uuid,p_facts jsonb,p_coat_confirmed boolean,
  p_operation_id uuid,p_expected_revision uuid)
returns jsonb language sql security invoker set search_path = '' as $$
  select app_private.save_my_pet_v3(p_pet_id,p_facts,p_coat_confirmed,p_operation_id,p_expected_revision);
$$;
revoke all on function app_private.save_my_pet_v3(uuid,jsonb,boolean,uuid,uuid),
  public.save_my_pet_v3(uuid,jsonb,boolean,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function app_private.save_my_pet_v3(uuid,jsonb,boolean,uuid,uuid),
  public.save_my_pet_v3(uuid,jsonb,boolean,uuid,uuid) to authenticated;

revoke all on function app_private.save_my_pet_v2(uuid,jsonb,boolean) from public,anon,authenticated,service_role;
create or replace function public.save_my_pet_v2(p_pet_id uuid,p_facts jsonb,p_coat_confirmed boolean default false)
returns setof public.pets language plpgsql security invoker set search_path = '' as $$
begin
  raise exception using errcode='PT409',message='pet_client_update_required';
end $$;

revoke insert, update on table public.pets from public,anon,authenticated;
do $$
declare columns text;
begin
  select string_agg(quote_ident(attname),',' order by attnum) into columns
    from pg_attribute where attrelid='public.pets'::regclass and attnum>0 and not attisdropped;
  execute format('revoke insert (%s), update (%s) on public.pets from public,anon,authenticated',columns,columns);
end $$;
grant update (is_active, deleted_at) on public.pets to authenticated;

create function app_private.redact_pet_create_operations()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.anonymized_at is not null then
    delete from app_private.pet_create_operations where customer_id=new.user_id;
  end if;
  return new;
end $$;
revoke all on function app_private.redact_pet_create_operations() from public,anon,authenticated,service_role;
create trigger account_deletion_redact_pet_creates after insert or update of anonymized_at
on public.account_deletion_requests for each row execute function app_private.redact_pet_create_operations();
