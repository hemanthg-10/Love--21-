-- Derive discovery preferences from the immutable registration gender.
-- Discovery RPCs already apply mutual dating_preferences filters server-side.

create or replace function public.enforce_opposite_gender_preference()
returns trigger
language plpgsql
set search_path = public, auth, pg_temp
as $$
begin
  if new.gender not in ('Man', 'Woman') then
    raise exception 'A valid registered gender is required for discovery';
  end if;

  if tg_op = 'UPDATE' and new.gender is distinct from old.gender then
    raise exception 'Registered gender cannot be changed here';
  end if;

  new.dating_preferences := array[
    case new.gender when 'Man' then 'Woman' when 'Woman' then 'Man' end
  ];
  return new;
end;
$$;

drop trigger if exists love21_opposite_gender_preference on public.profiles;
create trigger love21_opposite_gender_preference
before insert or update of gender, dating_preferences on public.profiles
for each row execute function public.enforce_opposite_gender_preference();

update public.profiles
set dating_preferences = array[
  case gender when 'Man' then 'Woman' when 'Woman' then 'Man' end
]
where gender in ('Man', 'Woman');
