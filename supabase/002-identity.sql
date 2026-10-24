-- Existing installations: run AFTER setup.sql. Safe to reapply.
begin;
create table if not exists private.forum_owner_names(
 user_id uuid primary key references auth.users(id) on delete cascade,
 real_name text not null check(char_length(real_name) between 2 and 32)
);
create table if not exists private.forum_friends(
 owner_id uuid not null references auth.users(id) on delete cascade,
 friend_id uuid not null references auth.users(id) on delete cascade,
 primary key(owner_id,friend_id),check(owner_id<>friend_id)
);
revoke all on private.forum_owner_names,private.forum_friends from public,anon,authenticated;

-- Preserve existing names privately before replacing public owner names.
insert into private.forum_owner_names(user_id,real_name)
 select a.user_id,p.display_name from private.forum_admins a join public.forum_profiles p on p.id=a.user_id
 on conflict do nothing;
update public.forum_profiles set display_name='Owner' where id in(select user_id from private.forum_owner_names);

create or replace function private.protect_forum_owner_name() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into private.forum_owner_names(user_id,real_name)
 select new.user_id,display_name
 from public.forum_profiles where id=new.user_id on conflict do nothing;
 update public.forum_profiles set display_name='Owner' where id=new.user_id;
 return new;
end;$$;
drop trigger if exists protect_forum_owner_name on private.forum_admins;
create trigger protect_forum_owner_name after insert on private.forum_admins for each row execute function private.protect_forum_owner_name();

-- Anonymous Supabase auth is not used by the website. Deny it server-side too.
drop policy if exists permanent_topics_only on public.forum_topics;
create policy permanent_topics_only on public.forum_topics as restrictive for insert to authenticated
 with check(coalesce((select auth.jwt()->>'is_anonymous'),'false')='false');
drop policy if exists permanent_replies_only on public.forum_replies;
create policy permanent_replies_only on public.forum_replies as restrictive for insert to authenticated
 with check(coalesce((select auth.jwt()->>'is_anonymous'),'false')='false');
create or replace function public.forum_is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(auth.jwt()->>'is_anonymous','false')='false' and exists(select 1 from private.forum_admins where user_id=(select auth.uid()));
$$;

create or replace function public.forum_author_names(p_ids uuid[])
 returns table(id uuid,display_name text,is_owner boolean) language sql stable security definer set search_path='' as $$
 select p.id,
 case when n.user_id is null then p.display_name
 when auth.uid()=n.user_id or exists(select 1 from private.forum_friends f where f.owner_id=n.user_id and f.friend_id=auth.uid())
 then n.real_name else null end,
 n.user_id is not null
 from public.forum_profiles p left join private.forum_owner_names n on n.user_id=p.id
 where p.id=any(p_ids) and coalesce(array_length(p_ids,1),0)<=100;
$$;
-- Only the caller's friendships can be listed or changed; friendship is one-way owner approval.
create or replace function public.forum_my_friends()
 returns table(friend_id uuid,display_name text) language sql stable security definer set search_path='' as $$
 select f.friend_id,p.display_name from private.forum_friends f join public.forum_profiles p on p.id=f.friend_id
 where f.owner_id=auth.uid() and public.forum_is_admin();
$$;
create or replace function public.forum_set_friend(p_friend uuid,p_allow boolean)
 returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.forum_is_admin() then raise exception 'Not authorized';end if;
 if p_friend=auth.uid() or not exists(select 1 from public.forum_profiles where id=p_friend) then raise exception 'Invalid member';end if;
 if p_allow then insert into private.forum_friends(owner_id,friend_id) values(auth.uid(),p_friend) on conflict do nothing;
 else delete from private.forum_friends where owner_id=auth.uid() and friend_id=p_friend;end if;
end;$$;
create or replace function public.forum_set_owner_name(p_name text)
 returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.forum_is_admin() then raise exception 'Not authorized';end if;
 if char_length(trim(p_name)) not between 2 and 32 then raise exception 'Name must contain 2-32 characters';end if;
 insert into private.forum_owner_names(user_id,real_name) values(auth.uid(),trim(p_name))
 on conflict(user_id) do update set real_name=excluded.real_name;
 update public.forum_profiles set display_name='Owner' where id=auth.uid();
end;$$;
revoke all on function private.protect_forum_owner_name() from public,anon,authenticated;
revoke all on function public.forum_author_names(uuid[]),public.forum_my_friends(),public.forum_set_friend(uuid,boolean) from public,anon,authenticated;
revoke all on function public.forum_set_owner_name(text) from public,anon,authenticated;
grant execute on function public.forum_author_names(uuid[]) to anon,authenticated;
grant execute on function public.forum_my_friends(),public.forum_set_friend(uuid,boolean) to authenticated;
grant execute on function public.forum_set_owner_name(text) to authenticated;
commit;
