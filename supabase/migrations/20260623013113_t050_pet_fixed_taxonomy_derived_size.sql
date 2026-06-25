-- T-050 local draft. Not deployed.
-- Purpose: tighten customer pet profile taxonomy and derive size from weight.

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'pet-photos',
  'pet-photos',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']::text[]
)
on conflict (id) do update
set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function app_private.pet_size_code_for_weight_lbs(
  p_weight_lbs numeric
)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when p_weight_lbs < 10 then 'XS'
    when p_weight_lbs < 20 then 'S'
    when p_weight_lbs < 40 then 'M'
    when p_weight_lbs < 60 then 'L'
    when p_weight_lbs < 80 then 'XL'
    when p_weight_lbs <= 100 then 'XXL'
    else 'Giant'
  end
$$;

revoke all on function app_private.pet_size_code_for_weight_lbs(numeric)
from public, anon, authenticated;

grant execute on function app_private.pet_size_code_for_weight_lbs(numeric)
to service_role;

create or replace function app_private.set_pet_size_from_weight()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.weight_lbs is null then
    new.size = null;
  else
    new.size = app_private.pet_size_code_for_weight_lbs(new.weight_lbs);
  end if;
  return new;
end;
$$;

revoke all on function app_private.set_pet_size_from_weight()
from public, anon, authenticated;

alter table public.pets
  drop constraint if exists pets_species_check,
  drop constraint if exists pets_breed_check,
  drop constraint if exists pets_size_check,
  drop constraint if exists pets_weight_lbs_check,
  drop constraint if exists pets_temperament_check;

update public.pets
set
  species = case
    when lower(btrim(species)) = 'cat' then 'Cat'
    else 'Dog'
  end,
  breed = case lower(btrim(coalesce(breed, '')))
    when 'mixed breed' then 'Mixed Breed'
    when 'labrador retriever' then 'Labrador Retriever'
    when 'golden retriever' then 'Golden Retriever'
    when 'german shepherd' then 'German Shepherd'
    when 'french bulldog' then 'French Bulldog'
    when 'bulldog' then 'Bulldog'
    when 'poodle' then 'Poodle'
    when 'toy poodle' then 'Toy Poodle'
    when 'standard poodle' then 'Standard Poodle'
    when 'beagle' then 'Beagle'
    when 'rottweiler' then 'Rottweiler'
    when 'dachshund' then 'Dachshund'
    when 'corgi' then 'Corgi'
    when 'yorkshire terrier' then 'Yorkshire Terrier'
    when 'boxer' then 'Boxer'
    when 'shih tzu' then 'Shih Tzu'
    when 'shiba inu' then 'Shiba Inu'
    when 'siberian husky' then 'Siberian Husky'
    when 'australian shepherd' then 'Australian Shepherd'
    when 'border collie' then 'Border Collie'
    when 'chihuahua' then 'Chihuahua'
    when 'pomeranian' then 'Pomeranian'
    when 'maltese' then 'Maltese'
    when 'boston terrier' then 'Boston Terrier'
    when 'cavalier king charles spaniel' then 'Cavalier King Charles Spaniel'
    when 'great dane' then 'Great Dane'
    when 'doberman pinscher' then 'Doberman Pinscher'
    when 'miniature schnauzer' then 'Miniature Schnauzer'
    when 'pit bull' then 'Pit Bull'
    when 'bichon frise' then 'Bichon Frise'
    when 'cocker spaniel' then 'Cocker Spaniel'
    when 'domestic shorthair' then 'Domestic Shorthair'
    when 'domestic longhair' then 'Domestic Longhair'
    when 'siamese' then 'Siamese'
    when 'persian' then 'Persian'
    when 'maine coon' then 'Maine Coon'
    when 'ragdoll' then 'Ragdoll'
    when 'british shorthair' then 'British Shorthair'
    when 'bengal' then 'Bengal'
    when 'sphynx' then 'Sphynx'
    when 'scottish fold' then 'Scottish Fold'
    when 'russian blue' then 'Russian Blue'
    else 'Unspecified'
  end,
  weight_lbs = coalesce(weight_lbs, 10),
  temperament = case lower(btrim(coalesce(temperament, '')))
    when 'friendly' then 'Friendly'
    when 'playful' then 'Playful'
    when 'calm' then 'Calm'
    when 'gentle' then 'Gentle'
    when 'energetic' then 'Energetic'
    when 'shy' then 'Shy'
    when 'anxious' then 'Anxious'
    when 'reactive' then 'Reactive'
    when 'independent' then 'Independent'
    when 'affectionate' then 'Affectionate'
    when 'protective' then 'Protective'
    when 'social' then 'Social'
    when 'nervous' then 'Nervous'
    else 'Not Sure'
  end;

update public.pets
set size = app_private.pet_size_code_for_weight_lbs(weight_lbs);

alter table public.pets
  alter column species set default 'Dog',
  alter column breed set default 'Unspecified',
  alter column breed set not null,
  alter column size set default 'S',
  alter column size set not null,
  alter column weight_lbs set default 10,
  alter column weight_lbs set not null,
  alter column temperament set default 'Not Sure',
  alter column temperament set not null,
  add constraint pets_species_fixed_check check (
    species in ('Dog', 'Cat')
  ),
  add constraint pets_breed_fixed_check check (
    breed in (
      'Unspecified',
      'Mixed Breed',
      'Labrador Retriever',
      'Golden Retriever',
      'German Shepherd',
      'French Bulldog',
      'Bulldog',
      'Poodle',
      'Toy Poodle',
      'Standard Poodle',
      'Beagle',
      'Rottweiler',
      'Dachshund',
      'Corgi',
      'Yorkshire Terrier',
      'Boxer',
      'Shih Tzu',
      'Shiba Inu',
      'Siberian Husky',
      'Australian Shepherd',
      'Border Collie',
      'Chihuahua',
      'Pomeranian',
      'Maltese',
      'Boston Terrier',
      'Cavalier King Charles Spaniel',
      'Great Dane',
      'Doberman Pinscher',
      'Miniature Schnauzer',
      'Pit Bull',
      'Bichon Frise',
      'Cocker Spaniel',
      'Domestic Shorthair',
      'Domestic Longhair',
      'Siamese',
      'Persian',
      'Maine Coon',
      'Ragdoll',
      'British Shorthair',
      'Bengal',
      'Sphynx',
      'Scottish Fold',
      'Russian Blue'
    )
  ),
  add constraint pets_size_code_check check (
    size in ('XS', 'S', 'M', 'L', 'XL', 'XXL', 'Giant')
  ),
  add constraint pets_size_derived_from_weight_check check (
    size = case
      when weight_lbs < 10 then 'XS'
      when weight_lbs < 20 then 'S'
      when weight_lbs < 40 then 'M'
      when weight_lbs < 60 then 'L'
      when weight_lbs < 80 then 'XL'
      when weight_lbs <= 100 then 'XXL'
      else 'Giant'
    end
  ),
  add constraint pets_weight_lbs_range_check check (
    weight_lbs >= 5 and weight_lbs <= 101
  ),
  add constraint pets_temperament_fixed_check check (
    temperament in (
      'Not Sure',
      'Friendly',
      'Playful',
      'Calm',
      'Gentle',
      'Energetic',
      'Shy',
      'Anxious',
      'Reactive',
      'Independent',
      'Affectionate',
      'Protective',
      'Social',
      'Nervous'
    )
  );

drop trigger if exists pets_derive_size_from_weight on public.pets;

create trigger pets_derive_size_from_weight
before insert or update of weight_lbs, size on public.pets
for each row execute function app_private.set_pet_size_from_weight();

comment on function app_private.pet_size_code_for_weight_lbs(numeric) is
  'Maps pet weight in pounds to the customer pet size code used by request snapshots.';

comment on trigger pets_derive_size_from_weight on public.pets is
  'Keeps pets.size derived from pets.weight_lbs instead of user-entered form input.';
