-- ---------------------------------------------------------------------------
-- Revert 0005: drop phases/missions/painting entirely
-- ---------------------------------------------------------------------------

drop trigger if exists check_mission_pick_allowed_trigger on mission_attempts;
drop trigger if exists check_painting_submission_allowed_trigger on painting_submissions;

drop function if exists report_mission(uuid);
drop function if exists resolve_mission(uuid, text);
drop function if exists resolve_painting(uuid, text);
drop function if exists check_mission_pick_allowed();
drop function if exists check_painting_submission_allowed();

drop table if exists mission_attempts;
drop table if exists painting_submissions;
drop table if exists missions;

alter table matches drop column if exists phase_id;
alter table signups drop column if exists phase_id;

drop table if exists phases;

-- Restore signup validation to the pre-phase version
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

-- Restore pairing RPCs to the pre-phase versions

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
    select id, user_id, army_list, row_number() over (order by random()) as rn
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
      insert into matches (league_id, player1_id, player1_list, player2_id, player2_list)
      values (p_league_id, rec.user_id, rec.army_list, opp.user_id, opp.army_list);

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

  insert into matches (league_id, player1_id, player1_list, player2_id, player2_list)
  values (p_league_id, s1.user_id, s1.army_list, s2.user_id, s2.army_list)
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

  insert into matches (league_id, player1_id, player1_list, player2_id, player2_list)
  values (p_league_id, s1.user_id, s1.army_list, s2.user_id, s2.army_list)
  returning * into new_match;

  delete from signups where id in (s1.id, s2.id);

  return new_match;
end;
$$;
