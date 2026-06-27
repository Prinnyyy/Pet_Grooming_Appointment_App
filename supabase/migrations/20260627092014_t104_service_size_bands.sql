alter table public.groomer_services
  drop constraint if exists groomer_services_sizes_check;

with expanded as (
  select
    services.id,
    mapped.size_value,
    min(mapped.sort_order) as sort_order
  from public.groomer_services as services
  cross join lateral unnest(services.accepted_pet_sizes) as existing(size_value)
  cross join lateral (
    values
      (
        case existing.size_value
          when 'small' then 'XS'
          when 'medium' then 'M'
          when 'large' then 'L'
          when 'giant' then 'XXL'
          when 'XS' then 'XS'
          when 'S' then 'S'
          when 'M' then 'M'
          when 'L' then 'L'
          when 'XL' then 'XL'
          when 'XXL' then 'XXL'
          when 'Giant' then 'Giant'
          else null
        end,
        case existing.size_value
          when 'small' then 0
          when 'XS' then 0
          when 'S' then 1
          when 'medium' then 2
          when 'M' then 2
          when 'large' then 3
          when 'L' then 3
          when 'XL' then 4
          when 'giant' then 5
          when 'XXL' then 5
          when 'Giant' then 6
          else null
        end
      ),
      (
        case existing.size_value
          when 'small' then 'S'
          when 'large' then 'XL'
          when 'giant' then 'Giant'
          else null
        end,
        case existing.size_value
          when 'small' then 1
          when 'large' then 4
          when 'giant' then 6
          else null
        end
      )
  ) as mapped(size_value, sort_order)
  where mapped.size_value is not null
  group by services.id, mapped.size_value
),
rebuilt as (
  select
    expanded.id,
    array_agg(expanded.size_value order by expanded.sort_order) as accepted_pet_sizes
  from expanded
  group by expanded.id
)
update public.groomer_services as services
set accepted_pet_sizes = rebuilt.accepted_pet_sizes
from rebuilt
where services.id = rebuilt.id;

alter table public.groomer_services
  add constraint groomer_services_sizes_check check (
    accepted_pet_sizes <@ array[
      'XS',
      'S',
      'M',
      'L',
      'XL',
      'XXL',
      'Giant'
    ]::text[]
    and cardinality(accepted_pet_sizes) <= 7
  );

comment on column public.groomer_services.accepted_pet_sizes is
  'Optional service-level accepted pet size bands using the same XS/S/M/L/XL/XXL/Giant vocabulary as Fit Signals. Empty array means inherit the groomer Fit Signals size experience in the owner UI.';
