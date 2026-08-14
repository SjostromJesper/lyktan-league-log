create table painted_units (
  league_id uuid not null references leagues(id) on delete cascade,
  user_id uuid not null references profiles(id) on delete cascade,
  unit1 boolean not null default false,
  unit2 boolean not null default false,
  unit3 boolean not null default false,
  unit4 boolean not null default false,
  unit5 boolean not null default false,
  primary key (league_id, user_id)
);

alter table painted_units enable row level security;

create policy "painted_units_select_authenticated" on painted_units
  for select to authenticated using (true);

create policy "painted_units_write_admin" on painted_units
  for all to authenticated using (is_admin()) with check (is_admin());
