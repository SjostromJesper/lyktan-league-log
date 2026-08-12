alter table profiles
  add column password_change_required boolean not null default true;

-- Existing accounts already know their real password; only future accounts
-- (created by an admin with a temporary password) should be nagged.
update profiles set password_change_required = false;
