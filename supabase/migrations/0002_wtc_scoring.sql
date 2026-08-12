-- ---------------------------------------------------------------------------
-- WTC / League Points scoring
-- ---------------------------------------------------------------------------

alter table matches
  add column player1_vp integer,
  add column player2_vp integer,
  add column player1_wtc integer,
  add column player2_wtc integer,
  add column player1_league_points integer,
  add column player2_league_points integer;

alter table matches drop column reporter_result;

-- Converts raw VP for both players into WTC/Battle Points (always sums to 20)
-- and League Points (3-0 / 2-1 / 1-1). An exact VP tie is the only case that
-- awards 1-1 League Points; any real VP winner gets at least 2-1, even when
-- their VP margin falls in the WTC 10-10 bracket.
create or replace function compute_league_result(p1_vp integer, p2_vp integer)
returns table (p1_wtc integer, p2_wtc integer, p1_lp integer, p2_lp integer)
language plpgsql
immutable
as $$
declare
  diff integer;
  winner_wtc integer;
  loser_wtc integer;
begin
  diff := abs(p1_vp - p2_vp);

  if diff <= 5 then winner_wtc := 10; loser_wtc := 10;
  elsif diff <= 10 then winner_wtc := 11; loser_wtc := 9;
  elsif diff <= 15 then winner_wtc := 12; loser_wtc := 8;
  elsif diff <= 20 then winner_wtc := 13; loser_wtc := 7;
  elsif diff <= 25 then winner_wtc := 14; loser_wtc := 6;
  elsif diff <= 30 then winner_wtc := 15; loser_wtc := 5;
  elsif diff <= 35 then winner_wtc := 16; loser_wtc := 4;
  elsif diff <= 40 then winner_wtc := 17; loser_wtc := 3;
  elsif diff <= 45 then winner_wtc := 18; loser_wtc := 2;
  elsif diff <= 50 then winner_wtc := 19; loser_wtc := 1;
  else winner_wtc := 20; loser_wtc := 0;
  end if;

  if p1_vp = p2_vp then
    p1_wtc := winner_wtc; p2_wtc := winner_wtc;
    p1_lp := 1; p2_lp := 1;
  elsif p1_vp > p2_vp then
    p1_wtc := winner_wtc; p2_wtc := loser_wtc;
    if winner_wtc >= 15 then p1_lp := 3; p2_lp := 0;
    else p1_lp := 2; p2_lp := 1;
    end if;
  else
    p2_wtc := winner_wtc; p1_wtc := loser_wtc;
    if winner_wtc >= 15 then p2_lp := 3; p1_lp := 0;
    else p2_lp := 2; p1_lp := 1;
    end if;
  end if;

  return next;
end;
$$;

drop function if exists report_match(uuid, text);

create or replace function report_match(p_match_id uuid, p_my_vp integer, p_opponent_vp integer)
returns matches
language plpgsql
security definer
set search_path = public
as $$
declare
  m matches%rowtype;
  result record;
begin
  if p_my_vp < 0 or p_opponent_vp < 0 then
    raise exception 'VP kan inte vara negativt.';
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

  if auth.uid() = m.player1_id then
    m.player1_vp := p_my_vp;
    m.player2_vp := p_opponent_vp;
  else
    m.player2_vp := p_my_vp;
    m.player1_vp := p_opponent_vp;
  end if;

  select * into result from compute_league_result(m.player1_vp, m.player2_vp);

  update matches
    set status = 'reported',
        reporter_id = auth.uid(),
        player1_vp = m.player1_vp,
        player2_vp = m.player2_vp,
        player1_wtc = result.p1_wtc,
        player2_wtc = result.p2_wtc,
        player1_league_points = result.p1_lp,
        player2_league_points = result.p2_lp,
        reported_at = now()
    where id = p_match_id
    returning * into m;

  return m;
end;
$$;

grant execute on function report_match(uuid, integer, integer) to authenticated;
