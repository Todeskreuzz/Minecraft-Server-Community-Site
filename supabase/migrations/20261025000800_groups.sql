-- Player groups and the Minecraft sync queue. Safe to reapply.
begin;
create extension if not exists pgcrypto with schema extensions;

alter table public.forum_profiles add column if not exists minecraft_name text;
alter table public.forum_profiles add column if not exists minecraft_verified boolean not null default false;
alter table public.forum_profiles drop constraint if exists forum_profiles_minecraft_name_ok;
alter table public.forum_profiles add constraint forum_profiles_minecraft_name_ok check (minecraft_name is null or minecraft_name ~ '^[A-Za-z0-9_]{3,16}$');
create unique index if not exists forum_profiles_minecraft_name_key on public.forum_profiles (lower(minecraft_name));

create table if not exists public.player_groups (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null references public.forum_profiles(id) on delete cascade,
 name text not null check (char_length(trim(name)) between 2 and 32),
 tag text not null check (tag ~ '^[A-Z0-9]{2,6}$'),
 color text not null check (color in ('black','dark_blue','dark_green','dark_aqua','dark_red','dark_purple','gold','gray','dark_gray','blue','green','aqua','red','light_purple','yellow','white')),
 description text not null default '' check (char_length(description) <= 200),
 created_at timestamptz not null default now(),
 unique (tag)
);
create table if not exists public.player_group_members (
 group_id uuid not null references public.player_groups(id) on delete cascade,
 user_id uuid not null references public.forum_profiles(id) on delete cascade,
 status text not null check (status in ('pending','invited','member')),
 primary key (group_id, user_id)
);
create table if not exists public.mc_sync_queue (
 id uuid primary key default gen_random_uuid(),
 kind text not null check (kind in ('create_group','add_member','remove_member','delete_group')),
 payload jsonb not null,
 created_at timestamptz not null default now(),
 done_at timestamptz
);
create index if not exists mc_sync_queue_open on public.mc_sync_queue (created_at) where done_at is null;

create table if not exists private.mc_link_codes (
 user_id uuid primary key references public.forum_profiles(id) on delete cascade,
 code_hash text not null,
 expires_at timestamptz not null
);
create table if not exists private.bridge_auth (
 id int primary key default 1 check (id = 1),
 secret_hash text not null
);
revoke all on private.mc_link_codes, private.bridge_auth from public, anon, authenticated;

alter table public.player_groups enable row level security;
alter table public.player_group_members enable row level security;
alter table public.mc_sync_queue enable row level security;
revoke all on public.player_groups, public.player_group_members, public.mc_sync_queue from anon, authenticated;
grant select on public.player_groups to anon, authenticated;
grant select on public.player_group_members to anon, authenticated;
drop policy if exists player_groups_read on public.player_groups;
create policy player_groups_read on public.player_groups for select using (true);
drop policy if exists player_group_members_read on public.player_group_members;
create policy player_group_members_read on public.player_group_members for select using (
 status = 'member'
 or user_id = (select auth.uid())
 or exists(select 1 from public.player_groups g where g.id = group_id and g.owner_id = (select auth.uid()))
);

create or replace function private.enqueue_sync(p_kind text, p_payload jsonb) returns void language sql security definer set search_path='' as $$
 insert into public.mc_sync_queue(kind, payload) values(p_kind, p_payload);
$$;
revoke all on function private.enqueue_sync(text, jsonb) from public, anon, authenticated;

create or replace function private.sync_membership(p_group uuid, p_user uuid, p_add boolean) returns void language plpgsql security definer set search_path='' as $$
declare tag text; player text;
begin
 select g.tag, p.minecraft_name into tag, player
 from public.player_groups g, public.forum_profiles p
 where g.id = p_group and p.id = p_user and p.minecraft_verified;
 if tag is null or player is null then return; end if;
 perform private.enqueue_sync(case when p_add then 'add_member' else 'remove_member' end, jsonb_build_object('tag', tag, 'player', player));
end; $$;
revoke all on function private.sync_membership(uuid, uuid, boolean) from public, anon, authenticated;

create or replace function public.forum_create_group(p_name text, p_tag text, p_color text, p_description text) returns uuid language plpgsql security definer set search_path='' as $$
declare gid uuid; cleaned text;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false') = 'true' then raise exception 'Not authorized'; end if;
 cleaned := upper(trim(p_tag));
 if cleaned !~ '^[A-Z0-9]{2,6}$' then raise exception 'Invalid tag'; end if;
 if p_color not in ('black','dark_blue','dark_green','dark_aqua','dark_red','dark_purple','gold','gray','dark_gray','blue','green','aqua','red','light_purple','yellow','white') then raise exception 'Invalid color'; end if;
 if char_length(trim(p_name)) not between 2 and 32 then raise exception 'Invalid name'; end if;
 if p_description is null then p_description := ''; end if;
 if char_length(p_description) > 200 then raise exception 'Invalid description'; end if;
 begin
  insert into public.player_groups(owner_id, name, tag, color, description)
  values(auth.uid(), trim(p_name), cleaned, p_color, p_description) returning id into gid;
 exception when unique_violation then raise exception 'Tag already used';
 end;
 insert into public.player_group_members(group_id, user_id, status) values(gid, auth.uid(), 'member');
 perform private.enqueue_sync('create_group', jsonb_build_object('tag', cleaned, 'color', p_color, 'name', trim(p_name)));
 perform private.sync_membership(gid, auth.uid(), true);
 return gid;
end; $$;

create or replace function public.forum_group_request(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false') = 'true' then raise exception 'Not authorized'; end if;
 if not exists(select 1 from public.player_groups where id = p_id) then raise exception 'Group missing'; end if;
 if exists(select 1 from public.player_groups where id = p_id and owner_id = auth.uid()) then raise exception 'Already a member'; end if;
 insert into public.player_group_members(group_id, user_id, status) values(p_id, auth.uid(), 'pending')
 on conflict (group_id, user_id) do nothing;
end; $$;

create or replace function public.forum_group_invite(p_id uuid, p_uid bigint) returns void language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
 if auth.uid() is null or not exists(select 1 from public.player_groups where id = p_id and owner_id = auth.uid()) then raise exception 'Not authorized'; end if;
 select id into target from public.forum_profiles where uid = p_uid;
 if target is null or target = auth.uid() then raise exception 'Invalid member'; end if;
 insert into public.player_group_members(group_id, user_id, status) values(p_id, target, 'invited')
 on conflict (group_id, user_id) do nothing;
end; $$;

create or replace function public.forum_group_act(p_id uuid, p_user uuid, p_action text) returns void language plpgsql security definer set search_path='' as $$
declare owner uuid; row_status text;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false') = 'true' then raise exception 'Not authorized'; end if;
 select owner_id into owner from public.player_groups where id = p_id;
 if owner is null then raise exception 'Group missing'; end if;
 select status into row_status from public.player_group_members where group_id = p_id and user_id = p_user;
 if p_action = 'leave' then
  if auth.uid() = owner then raise exception 'Owner stays until the group is deleted'; end if;
  if auth.uid() is distinct from p_user or row_status is distinct from 'member' then raise exception 'Not authorized'; end if;
  perform private.sync_membership(p_id, p_user, false);
  delete from public.player_group_members where group_id = p_id and user_id = p_user;
  return;
 end if;
 if p_action = 'kick' then
  if auth.uid() is distinct from owner or p_user = owner or row_status is distinct from 'member' then raise exception 'Not authorized'; end if;
  perform private.sync_membership(p_id, p_user, false);
  delete from public.player_group_members where group_id = p_id and user_id = p_user;
  return;
 end if;
 if p_action = 'accept' then
  if row_status = 'pending' and auth.uid() = owner then
   update public.player_group_members set status = 'member' where group_id = p_id and user_id = p_user;
   perform private.sync_membership(p_id, p_user, true);
   return;
  end if;
  if row_status = 'invited' and auth.uid() = p_user then
   update public.player_group_members set status = 'member' where group_id = p_id and user_id = p_user;
   perform private.sync_membership(p_id, p_user, true);
   return;
  end if;
  raise exception 'Not authorized';
 end if;
 if p_action in ('decline','cancel') then
  if not (auth.uid() = owner or auth.uid() = p_user) or row_status is null or row_status = 'member' then raise exception 'Not authorized'; end if;
  delete from public.player_group_members where group_id = p_id and user_id = p_user;
  return;
 end if;
 raise exception 'Invalid action';
end; $$;

create or replace function public.forum_delete_group(p_id uuid) returns void language plpgsql security definer set search_path='' as $$
declare tag text;
begin
 if auth.uid() is null or not exists(select 1 from public.player_groups where id = p_id and owner_id = auth.uid()) then raise exception 'Not authorized'; end if;
 select g.tag into tag from public.player_groups g where g.id = p_id;
 delete from public.player_groups where id = p_id;
 perform private.enqueue_sync('delete_group', jsonb_build_object('tag', tag));
end; $$;

create or replace function public.forum_set_minecraft(p_name text) returns void language plpgsql security definer set search_path='' as $$
declare cleaned text; old_name text; verified boolean;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false') = 'true' then raise exception 'Not authorized'; end if;
 cleaned := nullif(trim(p_name), '');
 if cleaned is not null and cleaned !~ '^[A-Za-z0-9_]{3,16}$' then raise exception 'Invalid Minecraft name'; end if;
 select minecraft_name, minecraft_verified into old_name, verified from public.forum_profiles where id = auth.uid();
 if verified and old_name is not null and cleaned is distinct from old_name then
  insert into public.mc_sync_queue(kind, payload)
  select 'remove_member', jsonb_build_object('tag', g.tag, 'player', old_name)
  from public.player_groups g
  join public.player_group_members m on m.group_id = g.id and m.user_id = auth.uid() and m.status = 'member';
 end if;
 update public.forum_profiles set minecraft_name = cleaned, minecraft_verified = false where id = auth.uid();
end; $$;

create or replace function public.forum_link_code() returns text language plpgsql security definer set search_path='' as $$
declare code text;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false') = 'true' then raise exception 'Not authorized'; end if;
 code := upper(substr(encode(extensions.gen_random_bytes(6), 'hex'), 1, 8));
 insert into private.mc_link_codes(user_id, code_hash, expires_at)
 values(auth.uid(), encode(extensions.digest(code, 'sha256'), 'hex'), now() + interval '15 minutes')
 on conflict (user_id) do update set code_hash = excluded.code_hash, expires_at = excluded.expires_at;
 return code;
end; $$;

create or replace function private.set_bridge_secret(p_secret text) returns void language plpgsql security definer set search_path='' as $$
begin
 if char_length(p_secret) < 24 then raise exception 'Secret is too short'; end if;
 insert into private.bridge_auth(id, secret_hash) values(1, encode(extensions.digest(p_secret, 'sha256'), 'hex'))
 on conflict (id) do update set secret_hash = excluded.secret_hash;
end; $$;
revoke all on function private.set_bridge_secret(text) from public, anon, authenticated;

create or replace function private.assert_bridge(p_secret text) returns void language plpgsql security definer set search_path='' as $$
declare expected text;
begin
 select secret_hash into expected from private.bridge_auth where id = 1;
 if expected is null then raise exception 'Bridge is not configured'; end if;
 if p_secret is null or encode(extensions.digest(p_secret, 'sha256'), 'hex') is distinct from expected then raise exception 'Not authorized'; end if;
end; $$;
revoke all on function private.assert_bridge(text) from public, anon, authenticated;

create or replace function public.bridge_claim(p_secret text) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.assert_bridge(p_secret);
 select coalesce(jsonb_agg(jsonb_build_object('id', id, 'kind', kind, 'payload', payload) order by created_at), '[]'::jsonb)
 into result from (select id, kind, payload, created_at from public.mc_sync_queue where done_at is null order by created_at limit 20) q;
 return result;
end; $$;

create or replace function public.bridge_done(p_secret text, p_ids uuid[]) returns void language plpgsql security definer set search_path='' as $$
begin
 perform private.assert_bridge(p_secret);
 update public.mc_sync_queue set done_at = now() where done_at is null and id = any(p_ids);
end; $$;

create or replace function public.bridge_link(p_secret text, p_code text, p_player text) returns void language plpgsql security definer set search_path='' as $$
declare uid uuid;
begin
 perform private.assert_bridge(p_secret);
 if p_player !~ '^[A-Za-z0-9_]{3,16}$' then raise exception 'Invalid Minecraft name'; end if;
 select user_id into uid from private.mc_link_codes
 where code_hash = encode(extensions.digest(upper(trim(p_code)), 'sha256'), 'hex') and expires_at > now();
 if uid is null then raise exception 'Code expired'; end if;
 if exists(select 1 from public.forum_profiles where lower(minecraft_name) = lower(p_player) and id <> uid) then raise exception 'Name already linked'; end if;
 update public.forum_profiles set minecraft_name = p_player, minecraft_verified = true where id = uid;
 delete from private.mc_link_codes where user_id = uid;
 insert into public.mc_sync_queue(kind, payload)
 select 'add_member', jsonb_build_object('tag', g.tag, 'player', p_player)
 from public.player_groups g
 join public.player_group_members m on m.group_id = g.id and m.user_id = uid and m.status = 'member';
end; $$;

revoke all on function public.forum_create_group(text, text, text, text), public.forum_group_request(uuid), public.forum_group_invite(uuid, bigint), public.forum_group_act(uuid, uuid, text), public.forum_delete_group(uuid), public.forum_set_minecraft(text), public.forum_link_code(), public.bridge_claim(text), public.bridge_done(text, uuid[]), public.bridge_link(text, text, text) from public, anon, authenticated;
grant execute on function public.forum_create_group(text, text, text, text), public.forum_group_request(uuid), public.forum_group_invite(uuid, bigint), public.forum_group_act(uuid, uuid, text), public.forum_delete_group(uuid), public.forum_set_minecraft(text), public.forum_link_code() to authenticated;
grant execute on function public.bridge_claim(text), public.bridge_done(text, uuid[]), public.bridge_link(text, text, text) to anon, authenticated;

drop view if exists public.forum_profile_cards;
create view public.forum_profile_cards with (security_invoker = true) as
 select p.id, p.uid, p.display_name, p.bio, p.created_at, p.last_seen,
  p.avatar_path, p.banner_path, p.background_path,
  p.avatar_preset, p.banner_preset, p.background_preset,
  p.minecraft_name, p.minecraft_verified,
  (select count(*) from public.forum_topics t where t.author_id = p.id) as thread_count,
  (select count(*) from public.forum_replies r where r.author_id = p.id) as reply_count,
  (select count(*) from public.friendships s where s.status='accepted' and (s.user_id=p.id or s.friend_id=p.id)) as friend_count
 from public.forum_profiles p;
revoke all on public.forum_profile_cards from anon, authenticated;
grant select on public.forum_profile_cards to anon, authenticated;

drop view if exists public.player_group_cards;
create view public.player_group_cards with (security_invoker = true) as
 select g.id, g.name, g.tag, g.color, g.description, g.created_at, g.owner_id,
  p.uid as owner_uid,
  (select count(*) from public.player_group_members m where m.group_id = g.id and m.status = 'member') as member_count
 from public.player_groups g
 join public.forum_profiles p on p.id = g.owner_id;
revoke all on public.player_group_cards from anon, authenticated;
grant select on public.player_group_cards to anon, authenticated;
commit;
