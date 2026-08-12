create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

create table profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  name text not null default '',
  army text not null default '',
  role text not null default 'player' check (role in ('player', 'admin')),
  created_at timestamptz not null default now()
);

create table leagues (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);

create unique index leagues_only_one_active on leagues (is_active) where (is_active);

create table league_members (
  league_id uuid not null references leagues (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (league_id, user_id)
);

create table signups (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references leagues (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  army_list text not null,
  created_at timestamptz not null default now(),
  unique (league_id, user_id)
);

create table matches (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references leagues (id) on delete cascade,
  player1_id uuid not null references profiles (id),
  player1_list text not null,
  player2_id uuid not null references profiles (id),
  player2_list text not null,
  status text not null default 'pending' check (status in ('pending', 'reported', 'confirmed', 'disputed')),
  reporter_id uuid references profiles (id),
  reporter_result text check (reporter_result in ('win', 'loss', 'draw')),
  created_at timestamptz not null default now(),
  reported_at timestamptz,
  confirmed_at timestamptz
);

-- ---------------------------------------------------------------------------
-- Helper functions
-- ---------------------------------------------------------------------------

create or replace function is_admin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from profiles where id = auth.uid() and role = 'admin'
  );
$$;

grant execute on function is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Auth trigger: create a profile row whenever an auth user is created
-- ---------------------------------------------------------------------------

create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, email, name, army, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)),
    coalesce(new.raw_user_meta_data ->> 'army', ''),
    coalesce(new.raw_user_meta_data ->> 'role', 'player')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- Prevent non-admins from changing role or id on their own profile row
create or replace function protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.role <> old.role and not is_admin() then
    new.role := old.role;
  end if;
  new.id := old.id;
  return new;
end;
$$;

create trigger protect_profile_role_trigger
  before update on profiles
  for each row execute function protect_profile_role();

-- Enforce league membership + "one match at a time" before accepting a signup
create or replace function check_signup_allowed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from league_members
    where league_id = new.league_id and user_id = new.user_id
  ) then
    raise exception 'Du är inte medlem i den här ligan.';
  end if;

  if exists (
    select 1 from matches
    where league_id = new.league_id
      and status in ('pending', 'reported')
      and (player1_id = new.user_id or player2_id = new.user_id)
  ) then
    raise exception 'Du har redan en pågående match. Rapportera den innan du anmäler dig igen.';
  end if;

  return new;
end;
$$;

create trigger check_signup_allowed_trigger
  before insert on signups
  for each row execute function check_signup_allowed();

-- ---------------------------------------------------------------------------
-- RPCs: pairing
-- ---------------------------------------------------------------------------

create or replace function pair_all_ready(p_league_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  paired_count integer := 0;
  r record;
begin
  if not is_admin() then
    raise exception 'Endast admin kan lotta matcher.';
  end if;

  create temporary table _shuffled on commit drop as
    select id, user_id, army_list, row_number() over (order by random()) as rn
    from signups
    where league_id = p_league_id;

  for r in
    select a.id as id1, a.user_id as u1, a.army_list as l1,
           b.id as id2, b.user_id as u2, b.army_list as l2
    from _shuffled a
    join _shuffled b on b.rn = a.rn + 1
    where a.rn % 2 = 1
  loop
    insert into matches (league_id, player1_id, player1_list, player2_id, player2_list)
    values (p_league_id, r.u1, r.l1, r.u2, r.l2);

    delete from signups where id in (r.id1, r.id2);
    paired_count := paired_count + 1;
  end loop;

  return paired_count;
end;
$$;

grant execute on function pair_all_ready(uuid) to authenticated;

create or replace function pair_individual(p_league_id uuid, p_user_id uuid)
returns matches
language plpgsql
security definer
set search_path = public
as $$
declare
  s1 signups%rowtype;
  s2 signups%rowtype;
  new_match matches%rowtype;
begin
  if not is_admin() then
    raise exception 'Endast admin kan lotta matcher.';
  end if;

  select * into s1 from signups where league_id = p_league_id and user_id = p_user_id;
  if not found then
    raise exception 'Spelaren är inte redo.';
  end if;

  select * into s2 from signups
    where league_id = p_league_id and user_id <> p_user_id
    order by random()
    limit 1;
  if not found then
    raise exception 'Ingen annan redo spelare att lotta mot.';
  end if;

  insert into matches (league_id, player1_id, player1_list, player2_id, player2_list)
  values (p_league_id, s1.user_id, s1.army_list, s2.user_id, s2.army_list)
  returning * into new_match;

  delete from signups where id in (s1.id, s2.id);

  return new_match;
end;
$$;

grant execute on function pair_individual(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- RPCs: match reporting
-- ---------------------------------------------------------------------------

create or replace function report_match(p_match_id uuid, p_result text)
returns matches
language plpgsql
security definer
set search_path = public
as $$
declare
  m matches%rowtype;
begin
  if p_result not in ('win', 'loss', 'draw') then
    raise exception 'Ogiltigt resultat.';
  end if;

  select * into m from matches where id = p_match_id;
  if not found then
    raise exception 'Matchen hittades inte.';
  end if;
  if m.status <> 'pending' then
    raise exception 'Matchen kan inte rapporteras just nu.';
  end if;
  if auth.uid() not in (m.player1_id, m.player2_id) then
    raise exception 'Du är inte med i den här matchen.';
  end if;

  update matches
    set status = 'reported', reporter_id = auth.uid(), reporter_result = p_result, reported_at = now()
    where id = p_match_id
    returning * into m;

  return m;
end;
$$;

grant execute on function report_match(uuid, text) to authenticated;

create or replace function confirm_match(p_match_id uuid, p_action text)
returns matches
language plpgsql
security definer
set search_path = public
as $$
declare
  m matches%rowtype;
begin
  if p_action not in ('confirm', 'dispute') then
    raise exception 'Ogiltig åtgärd.';
  end if;

  select * into m from matches where id = p_match_id;
  if not found then
    raise exception 'Matchen hittades inte.';
  end if;
  if m.status <> 'reported' then
    raise exception 'Matchen väntar inte på bekräftelse.';
  end if;
  if auth.uid() = m.reporter_id or auth.uid() not in (m.player1_id, m.player2_id) then
    raise exception 'Du kan inte bekräfta den här matchen.';
  end if;

  update matches
    set status = case when p_action = 'confirm' then 'confirmed' else 'disputed' end,
        confirmed_at = case when p_action = 'confirm' then now() else confirmed_at end
    where id = p_match_id
    returning * into m;

  return m;
end;
$$;

grant execute on function confirm_match(uuid, text) to authenticated;

create or replace function admin_resolve_match(p_match_id uuid, p_action text)
returns matches
language plpgsql
security definer
set search_path = public
as $$
declare
  m matches%rowtype;
begin
  if not is_admin() then
    raise exception 'Endast admin kan lösa tvister.';
  end if;
  if p_action not in ('confirm', 'void') then
    raise exception 'Ogiltig åtgärd.';
  end if;

  select * into m from matches where id = p_match_id;
  if not found then
    raise exception 'Matchen hittades inte.';
  end if;

  if p_action = 'confirm' then
    update matches set status = 'confirmed', confirmed_at = now() where id = p_match_id returning * into m;
    return m;
  else
    delete from matches where id = p_match_id;
    return m;
  end if;
end;
$$;

grant execute on function admin_resolve_match(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table profiles enable row level security;
alter table leagues enable row level security;
alter table league_members enable row level security;
alter table signups enable row level security;
alter table matches enable row level security;

create policy "profiles_select_authenticated" on profiles
  for select to authenticated using (true);

create policy "profiles_update_own" on profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "profiles_update_admin" on profiles
  for update to authenticated
  using (is_admin())
  with check (true);

create policy "leagues_select_authenticated" on leagues
  for select to authenticated using (true);

create policy "leagues_write_admin" on leagues
  for all to authenticated
  using (is_admin())
  with check (is_admin());

create policy "league_members_select_authenticated" on league_members
  for select to authenticated using (true);

create policy "league_members_write_admin" on league_members
  for all to authenticated
  using (is_admin())
  with check (is_admin());

create policy "signups_select_own_or_admin" on signups
  for select to authenticated
  using (user_id = auth.uid() or is_admin());

create policy "signups_insert_own" on signups
  for insert to authenticated
  with check (user_id = auth.uid());

create policy "signups_delete_admin" on signups
  for delete to authenticated
  using (is_admin());

create policy "matches_select_participant_or_confirmed_or_admin" on matches
  for select to authenticated
  using (
    player1_id = auth.uid()
    or player2_id = auth.uid()
    or status = 'confirmed'
    or is_admin()
  );
