-- Let admin adjust VP before confirming a disputed match, recomputing WTC/league points
-- from the corrected values instead of only accepting the originally reported ones.
drop function if exists admin_resolve_match(uuid, text);

create or replace function admin_resolve_match(
  p_match_id uuid,
  p_action text,
  p_player1_vp integer default null,
  p_player2_vp integer default null
)
returns matches
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  m matches%rowtype;
  result record;
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
    if p_player1_vp is not null and p_player2_vp is not null then
      if p_player1_vp < 0 or p_player2_vp < 0 then
        raise exception 'VP kan inte vara negativt.';
      end if;

      select * into result from compute_league_result(p_player1_vp, p_player2_vp);

      update matches
        set status = 'confirmed',
            confirmed_at = now(),
            player1_vp = p_player1_vp,
            player2_vp = p_player2_vp,
            player1_wtc = result.p1_wtc,
            player2_wtc = result.p2_wtc,
            player1_league_points = result.p1_lp,
            player2_league_points = result.p2_lp
        where id = p_match_id
        returning * into m;
    else
      update matches set status = 'confirmed', confirmed_at = now() where id = p_match_id returning * into m;
    end if;
    return m;
  else
    delete from matches where id = p_match_id;
    return m;
  end if;
end;
$$;
