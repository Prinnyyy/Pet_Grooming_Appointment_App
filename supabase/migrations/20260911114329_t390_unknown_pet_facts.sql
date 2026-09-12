-- T-390: unknown weight must remain unknown, not a default 10-pound small pet.
alter table public.pets alter column weight_lbs drop not null;
alter table public.pets alter column weight_lbs drop default;
alter table public.pets alter column size drop not null;
alter table public.pets alter column size drop default;
