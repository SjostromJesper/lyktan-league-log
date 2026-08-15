-- Admin can undo an approval: sends the submission back to "pending review"
-- (reusing the existing review UI/flow) and removes the awarded points.

create or replace function revoke_painted_unit(p_league_id uuid, p_user_id uuid, p_unit_key text)
returns painted_unit_photos
language plpgsql
security definer
set search_path = public
as $$
declare
  sub painted_unit_photos%rowtype;
begin
  if not is_admin() then
    raise exception 'Endast admin kan återkalla godkännanden.';
  end if;
  if p_unit_key not in ('unit1', 'unit2', 'unit3', 'unit4', 'unit5') then
    raise exception 'Ogiltig unit.';
  end if;

  select * into sub from painted_unit_photos
    where league_id = p_league_id and user_id = p_user_id and unit_key = p_unit_key;
  if not found then
    raise exception 'Inlämningen hittades inte.';
  end if;
  if sub.status <> 'approved' then
    raise exception 'Inlämningen är inte godkänd.';
  end if;

  update painted_unit_photos
    set status = 'submitted', approved_at = null
    where league_id = p_league_id and user_id = p_user_id and unit_key = p_unit_key
    returning * into sub;

  execute format('update painted_units set %I = false where league_id = $1 and user_id = $2', p_unit_key)
    using p_league_id, p_user_id;

  return sub;
end;
$$;

grant execute on function revoke_painted_unit(uuid, uuid, text) to authenticated;
