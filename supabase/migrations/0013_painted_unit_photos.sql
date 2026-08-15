-- ---------------------------------------------------------------------------
-- Painted unit photo submissions: players upload an unpainted + painted photo
-- per unit slot, mark it done, and an admin reviews + approves it before the
-- painting points in `painted_units` are actually granted.
-- ---------------------------------------------------------------------------

create table painted_unit_photos (
  league_id uuid not null references leagues (id) on delete cascade,
  user_id uuid not null references profiles (id) on delete cascade,
  unit_key text not null check (unit_key in ('unit1', 'unit2', 'unit3', 'unit4', 'unit5')),
  unpainted_path text,
  painted_path text,
  status text not null default 'draft' check (status in ('draft', 'submitted', 'approved')),
  submitted_at timestamptz,
  approved_at timestamptz,
  primary key (league_id, user_id, unit_key)
);

alter table painted_unit_photos enable row level security;

create policy "painted_unit_photos_select" on painted_unit_photos
  for select to authenticated
  using (user_id = auth.uid() or is_admin());

create policy "painted_unit_photos_insert_own" on painted_unit_photos
  for insert to authenticated
  with check (user_id = auth.uid() and status <> 'approved');

create policy "painted_unit_photos_update_own" on painted_unit_photos
  for update to authenticated
  using (user_id = auth.uid() and status <> 'approved')
  with check (user_id = auth.uid() and status <> 'approved');

create policy "painted_unit_photos_admin_all" on painted_unit_photos
  for all to authenticated
  using (is_admin())
  with check (is_admin());

-- ---------------------------------------------------------------------------
-- RPCs: admin approve/reject. Approving also flips the matching column on
-- painted_units so the existing scoring (paintingPointsFor) picks it up.
-- ---------------------------------------------------------------------------

create or replace function approve_painted_unit(p_league_id uuid, p_user_id uuid, p_unit_key text)
returns painted_unit_photos
language plpgsql
security definer
set search_path = public
as $$
declare
  sub painted_unit_photos%rowtype;
begin
  if not is_admin() then
    raise exception 'Endast admin kan godkänna målade units.';
  end if;
  if p_unit_key not in ('unit1', 'unit2', 'unit3', 'unit4', 'unit5') then
    raise exception 'Ogiltig unit.';
  end if;

  select * into sub from painted_unit_photos
    where league_id = p_league_id and user_id = p_user_id and unit_key = p_unit_key;
  if not found then
    raise exception 'Inlämningen hittades inte.';
  end if;
  if sub.status <> 'submitted' then
    raise exception 'Inlämningen väntar inte på granskning.';
  end if;

  update painted_unit_photos
    set status = 'approved', approved_at = now()
    where league_id = p_league_id and user_id = p_user_id and unit_key = p_unit_key
    returning * into sub;

  insert into painted_units (league_id, user_id)
    values (p_league_id, p_user_id)
    on conflict (league_id, user_id) do nothing;

  execute format('update painted_units set %I = true where league_id = $1 and user_id = $2', p_unit_key)
    using p_league_id, p_user_id;

  return sub;
end;
$$;

grant execute on function approve_painted_unit(uuid, uuid, text) to authenticated;

create or replace function reject_painted_unit(p_league_id uuid, p_user_id uuid, p_unit_key text)
returns painted_unit_photos
language plpgsql
security definer
set search_path = public
as $$
declare
  sub painted_unit_photos%rowtype;
begin
  if not is_admin() then
    raise exception 'Endast admin kan hantera inlämningar.';
  end if;
  if p_unit_key not in ('unit1', 'unit2', 'unit3', 'unit4', 'unit5') then
    raise exception 'Ogiltig unit.';
  end if;

  select * into sub from painted_unit_photos
    where league_id = p_league_id and user_id = p_user_id and unit_key = p_unit_key;
  if not found then
    raise exception 'Inlämningen hittades inte.';
  end if;
  if sub.status <> 'submitted' then
    raise exception 'Inlämningen väntar inte på granskning.';
  end if;

  update painted_unit_photos
    set status = 'draft', submitted_at = null
    where league_id = p_league_id and user_id = p_user_id and unit_key = p_unit_key
    returning * into sub;

  return sub;
end;
$$;

grant execute on function reject_painted_unit(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Storage: a public-read bucket, writes restricted to the uploading player's
-- own folder ({user_id}/...).
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('painted-units', 'painted-units', true)
on conflict (id) do nothing;

create policy "painted_unit_photos_storage_read" on storage.objects
  for select to public
  using (bucket_id = 'painted-units');

create policy "painted_unit_photos_storage_insert_own" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'painted-units' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "painted_unit_photos_storage_update_own" on storage.objects
  for update to authenticated
  using (bucket_id = 'painted-units' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "painted_unit_photos_storage_delete_own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'painted-units' and (storage.foldername(name))[1] = auth.uid()::text);
