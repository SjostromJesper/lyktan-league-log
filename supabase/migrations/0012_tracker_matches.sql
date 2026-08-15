create table tracker_matches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  name text check (char_length(name) <= 50),
  my_disposition text,
  opponent_disposition text,
  my_primary_options jsonb not null default '[]'::jsonb,
  opponent_primary_options jsonb not null default '[]'::jsonb,
  my_secondaries jsonb not null default '[]'::jsonb,
  opponent_secondaries jsonb not null default '[]'::jsonb,
  apply_to_match boolean not null default false,
  saved_to_history boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index tracker_matches_user_id_idx on tracker_matches (user_id);

alter table tracker_matches enable row level security;

create policy "tracker_matches_select_own" on tracker_matches
  for select to authenticated
  using (user_id = auth.uid());

create policy "tracker_matches_insert_own" on tracker_matches
  for insert to authenticated
  with check (user_id = auth.uid());

create policy "tracker_matches_update_own" on tracker_matches
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "tracker_matches_delete_own" on tracker_matches
  for delete to authenticated
  using (user_id = auth.uid());
