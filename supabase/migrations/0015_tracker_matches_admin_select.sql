-- Lets admins read all tracker_matches rows (for usage statistics), in addition
-- to the existing owner-only select policy. Permissive policies are OR'd together
-- by Postgres RLS, so this doesn't change what non-admins can see.

create policy "tracker_matches_select_admin" on tracker_matches
  for select to authenticated
  using (is_admin());
