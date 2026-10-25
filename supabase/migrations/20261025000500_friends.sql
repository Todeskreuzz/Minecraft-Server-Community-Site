-- Mutual friendships. The old private.forum_friends table stays in place.
begin;
create table if not exists public.friendships(
 user_id uuid not null references auth.users(id) on delete cascade,
 friend_id uuid not null references auth.users(id) on delete cascade,
 status text not null check (status in ('pending','accepted','blocked')),
 created_at timestamptz not null default now(),
 primary key(user_id, friend_id),
 check (user_id <> friend_id)
);
alter table public.friendships enable row level security;
revoke all on public.friendships from anon, authenticated;
grant select on public.friendships to anon, authenticated;
drop policy if exists friendships_read on public.friendships;
create policy friendships_read on public.friendships for select using (
 status = 'accepted'
 or (status = 'pending' and (user_id = (select auth.uid()) or friend_id = (select auth.uid())))
 or (status = 'blocked' and user_id = (select auth.uid()))
);
create or replace function private.copy_legacy_friends() returns void language sql security definer set search_path='' as $$
 insert into public.friendships(user_id, friend_id, status)
 select owner_id, friend_id, 'accepted' from private.forum_friends
 on conflict do nothing;
$$;
revoke all on function private.copy_legacy_friends() from public, anon, authenticated;
select private.copy_legacy_friends();

alter table public.forum_profiles add column if not exists last_seen timestamptz;

create or replace function public.forum_author_names(p_ids uuid[])
 returns table(id uuid, display_name text, is_owner boolean) language sql stable security definer set search_path='' as $$
 select p.id,
 case when n.user_id is null then p.display_name
 when auth.uid() = n.user_id
  or exists(select 1 from private.forum_friends f where f.owner_id = n.user_id and f.friend_id = auth.uid())
  or exists(select 1 from public.friendships s where s.status = 'accepted' and ((s.user_id = n.user_id and s.friend_id = auth.uid()) or (s.friend_id = n.user_id and s.user_id = auth.uid())))
 then n.real_name else null end,
 n.user_id is not null
 from public.forum_profiles p left join private.forum_owner_names n on n.user_id = p.id
 where p.id = any(p_ids) and coalesce(array_length(p_ids, 1), 0) <= 100;
$$;
revoke all on function public.forum_author_names(uuid[]) from public, anon, authenticated;
grant execute on function public.forum_author_names(uuid[]) to anon, authenticated;

create or replace function private.friend_pair(a uuid, b uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.friendships s where (s.user_id=a and s.friend_id=b) or (s.user_id=b and s.friend_id=a));
$$;
revoke all on function private.friend_pair(uuid, uuid) from public, anon, authenticated;

create or replace function public.forum_friend_request(p_uid bigint) returns void language plpgsql security definer set search_path='' as $$
declare target uuid;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' then raise exception 'Not authorized'; end if;
 select id into target from public.forum_profiles where uid=p_uid;
 if target is null or target=auth.uid() then raise exception 'Invalid member'; end if;
 if exists(select 1 from public.friendships s where s.status='blocked' and ((s.user_id=auth.uid() and s.friend_id=target) or (s.user_id=target and s.friend_id=auth.uid()))) then raise exception 'Blocked'; end if;
 if exists(select 1 from public.friendships s where s.status='accepted' and ((s.user_id=auth.uid() and s.friend_id=target) or (s.user_id=target and s.friend_id=auth.uid()))) then return; end if;
 if exists(select 1 from public.friendships s where s.status='pending' and s.user_id=target and s.friend_id=auth.uid()) then
  update public.friendships set status='accepted' where user_id=target and friend_id=auth.uid();
  return;
 end if;
 insert into public.friendships(user_id, friend_id, status) values(auth.uid(), target, 'pending') on conflict do nothing;
end; $$;

create or replace function public.forum_friend_act(p_id uuid, p_action text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' then raise exception 'Not authorized'; end if;
 if p_id is null or p_id=auth.uid() or p_action not in ('accept','decline','cancel','remove','block') then raise exception 'Invalid member'; end if;
 if p_action='accept' then
  update public.friendships set status='accepted' where status='pending' and user_id=p_id and friend_id=auth.uid();
  if not found then raise exception 'Invalid member'; end if;
 elsif p_action='decline' then
  delete from public.friendships where status='pending' and user_id=p_id and friend_id=auth.uid();
 elsif p_action='cancel' then
  delete from public.friendships where status='pending' and user_id=auth.uid() and friend_id=p_id;
 elsif p_action='remove' then
  delete from public.friendships where status='accepted' and ((user_id=auth.uid() and friend_id=p_id) or (user_id=p_id and friend_id=auth.uid()));
 elsif p_action='block' then
  delete from public.friendships where (user_id=auth.uid() and friend_id=p_id) or (user_id=p_id and friend_id=auth.uid());
  insert into public.friendships(user_id, friend_id, status) values(auth.uid(), p_id, 'blocked');
 end if;
end; $$;

create or replace function public.forum_touch() returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous','false')='true' then return; end if;
 update public.forum_profiles set last_seen=now() where id=auth.uid();
end; $$;

create or replace function public.forum_friend_panel()
 returns table(id uuid, uid bigint, display_name text, is_owner boolean, avatar_path text, avatar_preset text, relation text, last_seen timestamptz)
 language sql stable security definer set search_path='' as $$
 select other.id, other.uid,
  case when n.user_id is null then other.display_name
   when auth.uid()=n.user_id
    or exists(select 1 from private.forum_friends f where f.owner_id=n.user_id and f.friend_id=auth.uid())
    or exists(select 1 from public.friendships a where a.status='accepted' and ((a.user_id=n.user_id and a.friend_id=auth.uid()) or (a.friend_id=n.user_id and a.user_id=auth.uid())))
   then n.real_name else null end,
  n.user_id is not null,
  other.avatar_path, other.avatar_preset,
  case when s.status='accepted' then 'accepted' when s.status='blocked' then 'blocked' when s.user_id=auth.uid() then 'outgoing' else 'incoming' end,
  other.last_seen
 from public.friendships s
 join public.forum_profiles other on other.id=case when s.user_id=auth.uid() then s.friend_id else s.user_id end
 left join private.forum_owner_names n on n.user_id=other.id
 where auth.uid() is not null and coalesce(auth.jwt()->>'is_anonymous','false')='false'
  and (s.user_id=auth.uid() or (s.friend_id=auth.uid() and s.status<>'blocked'));
$$;

create or replace function public.forum_friend_state(p_id uuid) returns text language sql stable security definer set search_path='' as $$
 select case
  when auth.uid() is null or p_id is null then 'none'
  when exists(select 1 from public.friendships s where s.status='blocked' and s.user_id=auth.uid() and s.friend_id=p_id) then 'blocked'
  when exists(select 1 from public.friendships s where s.status='blocked' and s.user_id=p_id and s.friend_id=auth.uid()) then 'blocked'
  when exists(select 1 from public.friendships s where s.status='accepted' and ((s.user_id=auth.uid() and s.friend_id=p_id) or (s.user_id=p_id and s.friend_id=auth.uid()))) then 'accepted'
  when exists(select 1 from public.friendships s where s.status='pending' and s.user_id=auth.uid() and s.friend_id=p_id) then 'outgoing'
  when exists(select 1 from public.friendships s where s.status='pending' and s.user_id=p_id and s.friend_id=auth.uid()) then 'incoming'
  else 'none' end;
$$;

revoke all on function public.forum_friend_request(bigint), public.forum_friend_act(uuid, text), public.forum_touch(), public.forum_friend_panel(), public.forum_friend_state(uuid) from public, anon, authenticated;
grant execute on function public.forum_friend_request(bigint), public.forum_friend_act(uuid, text), public.forum_touch(), public.forum_friend_panel(), public.forum_friend_state(uuid) to authenticated;

drop view if exists public.forum_profile_cards;
create view public.forum_profile_cards with (security_invoker = true) as
 select p.id, p.uid, p.display_name, p.bio, p.created_at, p.last_seen,
  p.avatar_path, p.banner_path, p.background_path,
  p.avatar_preset, p.banner_preset, p.background_preset,
  (select count(*) from public.forum_topics t where t.author_id = p.id) as thread_count,
  (select count(*) from public.forum_replies r where r.author_id = p.id) as reply_count,
  (select count(*) from public.friendships s where s.status='accepted' and (s.user_id=p.id or s.friend_id=p.id)) as friend_count
 from public.forum_profiles p;
revoke all on public.forum_profile_cards from anon, authenticated;
grant select on public.forum_profile_cards to anon, authenticated;
commit;
