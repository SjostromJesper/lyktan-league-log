-- ---------------------------------------------------------------------------
-- League-level phase settings: description, phase count, matches per phase,
-- current phase pointer, and archiving. No separate phases table this time —
-- matches/signups are just tagged with a phase_number.
-- ---------------------------------------------------------------------------

alter table leagues
  add column description text not null default '',
  add column phase_count integer not null default 1 check (phase_count >= 1),
  add column matches_per_phase integer not null default 3 check (matches_per_phase >= 1),
  add column current_phase integer not null default 1 check (current_phase >= 1),
  add column is_archived boolean not null default false,
  add constraint phase_count_covers_current check (phase_count >= current_phase);

alter table signups add column phase_number integer;
alter table matches add column phase_number integer;

-- ---------------------------------------------------------------------------
-- Signup validation: stamp the league's current phase and enforce the
-- matches-per-phase cap.
-- ---------------------------------------------------------------------------

create or replace function check_signup_allowed()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lg leagues%rowtype;
  played_count integer;
begin
  select * into lg from leagues where id = new.league_id;
  if not found then
    raise exception 'Ligan hittades inte.';
  end if;

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

  new.phase_number := lg.current_phase;

  select count(*) into played_count
  from matches
  where league_id = new.league_id
    and phase_number = lg.current_phase
    and status in ('confirmed', 'disputed')
    and (player1_id = new.user_id or player2_id = new.user_id);

  if played_count >= lg.matches_per_phase then
    raise exception 'Du har redan spelat max antal matcher för den här fasen.';
  end if;

  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pairing RPCs: carry phase_number from the signup(s) onto the created match
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
    select id, user_id, army_list, phase_number, row_number() over (order by random()) as rn
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
      insert into matches (league_id, player1_id, player1_list, player2_id, player2_list, phase_number)
      values (p_league_id, rec.user_id, rec.army_list, opp.user_id, opp.army_list, rec.phase_number);

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

  insert into matches (league_id, player1_id, player1_list, player2_id, player2_list, phase_number)
  values (p_league_id, s1.user_id, s1.army_list, s2.user_id, s2.army_list, s1.phase_number)
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

  insert into matches (league_id, player1_id, player1_list, player2_id, player2_list, phase_number)
  values (p_league_id, s1.user_id, s1.army_list, s2.user_id, s2.army_list, s1.phase_number)
  returning * into new_match;

  delete from signups where id in (s1.id, s2.id);

  return new_match;
end;
$$;
