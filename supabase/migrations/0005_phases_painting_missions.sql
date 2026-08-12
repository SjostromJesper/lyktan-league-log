-- ---------------------------------------------------------------------------
-- Phases: group a league into blocks of N matches, with optional painting
-- and hidden-mission scoring per phase.
-- ---------------------------------------------------------------------------

create table phases (
  id uuid primary key default gen_random_uuid(),
  league_id uuid not null references leagues (id) on delete cascade,
  name text not null,
  phase_number integer not null,
  matches_per_phase integer not null default 3,
  painting_enabled boolean not null default false,
  painting_points integer not null default 0,
  missions_enabled boolean not null default false,
  is_active boolean not null default false,
  created_at timestamptz not null default now(),
  unique (league_id, phase_number)
);

create unique index phases_one_active_per_league on phases (league_id) where (is_active);

alter table signups add column phase_id uuid references phases (id) on delete set null;
alter table matches add column phase_id uuid references phases (id) on delete set null;

create table missions (
  id uuid primary key default gen_random_uuid(),
  phase_id uuid not null references phases (id) on delete cascade,
  name text not null,
  description text not null default '',
  points integer not null check (points >= 0),
  created_at timestamptz not null default now()
);

create table mission_attempts (
  id uuid primary key default gen_random_uuid(),
  phase_id uuid not null references phases (id) on delete cascade,
  mission_id uuid not null references missions (id),
  user_id uuid not null references profiles (id) on delete cascade,
  status text not null default 'picked' check (status in ('picked', 'reported', 'approved', 'rejected')),
  points integer,
  created_at timestamptz not null default now(),
  reported_at timestamptz,
  resolved_at timestamptz,
  unique (phase_id, user_id)
);

create table painting_submissions (
  id uuid primary key default gen_random_uuid(),
  phase_id uuid not null references phases (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  note text not null default '',
  status text not null default 'reported' check (status in ('reported', 'approved', 'rejected')),
  points integer,
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  unique (phase_id, user_id)
);

-- ---------------------------------------------------------------------------
-- Signup validation: also stamp the active phase and enforce matches_per_phase
-- ---------------------------------------------------------------------------

create or replace function check_signup_allowed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_phase phases%rowtype;
  played_count integer;
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

  select * into active_phase from phases where league_id = new.league_id and is_active limit 1;
  if found then
    new.phase_id := active_phase.id;

    select count(*) into played_count
    from matches
    where phase_id = active_phase.id
      and status in ('confirmed', 'disputed')
      and (player1_id = new.user_id or player2_id = new.user_id);

    if played_count >= active_phase.matches_per_phase then
      raise exception 'Du har redan spelat alla matcher för den här fasen.';
    end if;
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pairing RPCs: carry phase_id from the signup(s) onto the created match
-- ---------------------------------------------------------------------------

create or replace function pair_all_ready(p_league_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  paired_count integer := 0;
  rec record;
  opp record;
begin
  if not is_admin() then
    raise exception 'Endast admin kan lotta matcher.';
  end if;

  create temporary table _pool on commit drop as
    select id, user_id, army_list, phase_id, row_number() over (order by random()) as rn
    from signups
    where league_id = p_league_id;

  for rec in select * from _pool order by rn loop
    if not exists (select 1 from _pool where id = rec.id) then
      continue;
    end if;

    select p2.id, p2.user_id, p2.army_list into opp
    from _pool p2
    where p2.id <> rec.id
      and not exists (
        select 1 from matches m
        where m.league_id = p_league_id
          and ((m.player1_id = rec.user_id and m.player2_id = p2.user_id)
            or (m.player1_id = p2.user_id and m.player2_id = rec.user_id))
      )
    order by random()
    limit 1;

    if found then
      insert into matches (league_id, player1_id, player1_list, player2_id, player2_list, phase_id)
      values (p_league_id, rec.user_id, rec.army_list, opp.user_id, opp.army_list, rec.phase_id);

      delete from signups where id in (rec.id, opp.id);
      delete from _pool where id in (rec.id, opp.id);
      paired_count := paired_count + 1;
    end if;
  end loop;

  return paired_count;
end;
$$;

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

  select sg.* into s2
  from signups sg
  where sg.league_id = p_league_id
    and sg.user_id <> p_user_id
    and not exists (
      select 1 from matches m
      where m.league_id = p_league_id
        and ((m.player1_id = s1.user_id and m.player2_id = sg.user_id)
          or (m.player1_id = sg.user_id and m.player2_id = s1.user_id))
    )
  order by random()
  limit 1;

  if not found then
    return null;
  end if;

  insert into matches (league_id, player1_id, player1_list, player2_id, player2_list, phase_id)
  values (p_league_id, s1.user_id, s1.army_list, s2.user_id, s2.army_list, s1.phase_id)
  returning * into new_match;

  delete from signups where id in (s1.id, s2.id);

  return new_match;
end;
$$;

create or replace function pair_manual(p_league_id uuid, p_user_id uuid, p_opponent_id uuid)
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

  if p_user_id = p_opponent_id then
    raise exception 'Kan inte matcha en spelare mot sig själv.';
  end if;

  select * into s1 from signups where league_id = p_league_id and user_id = p_user_id;
  if not found then
    raise exception 'Spelaren är inte redo.';
  end if;

  select * into s2 from signups where league_id = p_league_id and user_id = p_opponent_id;
  if not found then
    raise exception 'Motståndaren är inte redo.';
  end if;

  insert into matches (league_id, player1_id, player1_list, player2_id, player2_list, phase_id)
  values (p_league_id, s1.user_id, s1.army_list, s2.user_id, s2.army_list, s1.phase_id)
  returning * into new_match;

  delete from signups where id in (s1.id, s2.id);

  return new_match;
end;
$$;

-- ---------------------------------------------------------------------------
-- Mission pick / report validation
-- ---------------------------------------------------------------------------

create or replace function check_mission_pick_allowed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ph phases%rowtype;
  m missions%rowtype;
begin
  select * into ph from phases where id = new.phase_id;
  if not found or not ph.is_active or not ph.missions_enabled then
    raise exception 'Hemliga uppdrag är inte aktiverat för den här fasen.';
  end if;

  select * into m from missions where id = new.mission_id;
  if not found or m.phase_id <> new.phase_id then
    raise exception 'Uppdraget hör inte till den här fasen.';
  end if;

  if not exists (
    select 1 from league_members
    where league_id = ph.league_id and user_id = new.user_id
  ) then
    raise exception 'Du är inte medlem i den här ligan.';
  end if;

  return new;
end;
$$;

create trigger check_mission_pick_allowed_trigger
  before insert on mission_attempts
  for each row execute function check_mission_pick_allowed();

create or replace function report_mission(p_attempt_id uuid)
returns mission_attempts
language plpgsql
security definer
set search_path = public
as $$
declare
  att mission_attempts%rowtype;
begin
  select * into att from mission_attempts where id = p_attempt_id;
  if not found then
    raise exception 'Uppdraget hittades inte.';
  end if;
  if att.user_id <> auth.uid() then
    raise exception 'Det här är inte ditt uppdrag.';
  end if;
  if att.status <> 'picked' then
    raise exception 'Uppdraget kan inte rapporteras just nu.';
  end if;

  update mission_attempts
    set status = 'reported', reported_at = now()
    where id = p_attempt_id
    returning * into att;

  return att;
end;
$$;

grant execute on function report_mission(uuid) to authenticated;

create or replace function resolve_mission(p_attempt_id uuid, p_action text)
returns mission_attempts
language plpgsql
security definer
set search_path = public
as $$
declare
  att mission_attempts%rowtype;
  m missions%rowtype;
begin
  if not is_admin() then
    raise exception 'Endast admin kan godkänna uppdrag.';
  end if;
  if p_action not in ('approve', 'reject') then
    raise exception 'Ogiltig åtgärd.';
  end if;

  select * into att from mission_attempts where id = p_attempt_id;
  if not found then
    raise exception 'Uppdraget hittades inte.';
  end if;
  if att.status <> 'reported' then
    raise exception 'Uppdraget väntar inte på godkännande.';
  end if;

  select * into m from missions where id = att.mission_id;

  update mission_attempts
    set status = case when p_action = 'approve' then 'approved' else 'rejected' end,
        points = case when p_action = 'approve' then m.points else 0 end,
        resolved_at = now()
    where id = p_attempt_id
    returning * into att;

  return att;
end;
$$;

grant execute on function resolve_mission(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Painting validation + resolution
-- ---------------------------------------------------------------------------

create or replace function check_painting_submission_allowed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  ph phases%rowtype;
begin
  select * into ph from phases where id = new.phase_id;
  if not found or not ph.is_active or not ph.painting_enabled then
    raise exception 'Målningspoäng är inte aktiverat för den här fasen.';
  end if;

  if not exists (
    select 1 from league_members
    where league_id = ph.league_id and user_id = new.user_id
  ) then
    raise exception 'Du är inte medlem i den här ligan.';
  end if;

  return new;
end;
$$;

create trigger check_painting_submission_allowed_trigger
  before insert on painting_submissions
  for each row execute function check_painting_submission_allowed();

create or replace function resolve_painting(p_submission_id uuid, p_action text)
returns painting_submissions
language plpgsql
security definer
set search_path = public
as $$
declare
  sub painting_submissions%rowtype;
  ph phases%rowtype;
begin
  if not is_admin() then
    raise exception 'Endast admin kan godkänna målning.';
  end if;
  if p_action not in ('approve', 'reject') then
    raise exception 'Ogiltig åtgärd.';
  end if;

  select * into sub from painting_submissions where id = p_submission_id;
  if not found then
    raise exception 'Inlämningen hittades inte.';
  end if;
  if sub.status <> 'reported' then
    raise exception 'Inlämningen är redan hanterad.';
  end if;

  select * into ph from phases where id = sub.phase_id;

  update painting_submissions
    set status = case when p_action = 'approve' then 'approved' else 'rejected' end,
        points = case when p_action = 'approve' then ph.painting_points else 0 end,
        resolved_at = now()
    where id = p_submission_id
    returning * into sub;

  return sub;
end;
$$;

grant execute on function resolve_painting(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Row level security
-- ---------------------------------------------------------------------------

alter table phases enable row level security;
alter table missions enable row level security;
alter table mission_attempts enable row level security;
alter table painting_submissions enable row level security;

create policy "phases_select_authenticated" on phases
  for select to authenticated using (true);

create policy "phases_write_admin" on phases
  for all to authenticated
  using (is_admin())
  with check (is_admin());

create policy "missions_select_authenticated" on missions
  for select to authenticated using (true);

create policy "missions_write_admin" on missions
  for all to authenticated
  using (is_admin())
  with check (is_admin());

create policy "mission_attempts_select" on mission_attempts
  for select to authenticated
  using (user_id = auth.uid() or is_admin() or status = 'approved');

create policy "mission_attempts_insert_own" on mission_attempts
  for insert to authenticated
  with check (user_id = auth.uid());

create policy "painting_select" on painting_submissions
  for select to authenticated
  using (user_id = auth.uid() or is_admin() or status = 'approved');

create policy "painting_insert_own" on painting_submissions
  for insert to authenticated
  with check (user_id = auth.uid());
