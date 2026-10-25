-- Public ranks. The owner rank stays on the earliest owner account.
begin;
create table if not exists public.forum_roles(
 user_id uuid primary key references public.forum_profiles(id) on delete cascade,
 role text not null check (role in ('owner','admin','moderator','dayone','member'))
);
alter table public.forum_roles enable row level security;
revoke all on public.forum_roles from anon, authenticated;
grant select on public.forum_roles to anon, authenticated;
drop policy if exists roles_read on public.forum_roles;
create policy roles_read on public.forum_roles for select using (true);

create or replace function private.sync_owner_role() returns void language plpgsql security definer set search_path='' as $$
declare owner_id uuid;
begin
 select user_id into owner_id from public.forum_roles where role='owner' limit 1;
 if owner_id is null then
  select n.user_id into owner_id
  from private.forum_owner_names n join public.forum_profiles p on p.id=n.user_id
  order by p.uid, p.created_at, p.id limit 1;
  if owner_id is not null then
   insert into public.forum_roles(user_id, role) values(owner_id, 'owner')
   on conflict (user_id) do update set role='owner';
  end if;
 end if;
 insert into public.forum_roles(user_id, role)
 select a.user_id, 'admin' from private.forum_admins a
 where a.user_id is distinct from owner_id
   and not exists(select 1 from public.forum_roles r where r.user_id=a.user_id)
 on conflict do nothing;
end; $$;
revoke all on function private.sync_owner_role() from public, anon, authenticated;
select private.sync_owner_role();

create or replace function private.protect_owner_role() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op='DELETE' and old.role='owner' then raise exception 'Owner is fixed'; end if;
 if tg_op='UPDATE' and old.role='owner' and new.role is distinct from 'owner' then raise exception 'Owner is fixed'; end if;
 if tg_op='UPDATE' and new.role='owner' and old.role is distinct from 'owner' then raise exception 'Owner is fixed'; end if;
 return coalesce(new, old);
end; $$;
revoke all on function private.protect_owner_role() from public, anon, authenticated;
drop trigger if exists protect_owner_role on public.forum_roles;
create trigger protect_owner_role before update or delete on public.forum_roles for each row execute function private.protect_owner_role();

create or replace function public.forum_is_admin() returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(auth.jwt()->>'is_anonymous','false')='false' and (
  exists(select 1 from private.forum_admins where user_id=(select auth.uid()))
  or exists(select 1 from public.forum_roles where user_id=(select auth.uid()) and role in ('owner','admin'))
 );
$$;
create or replace function public.forum_can_moderate() returns boolean language sql stable security definer set search_path='' as $$
 select public.forum_is_admin() or (
  coalesce(auth.jwt()->>'is_anonymous','false')='false'
  and exists(select 1 from public.forum_roles where user_id=(select auth.uid()) and role='moderator')
 );
$$;
revoke all on function public.forum_is_admin(), public.forum_can_moderate() from public, anon, authenticated;
grant execute on function public.forum_is_admin(), public.forum_can_moderate() to anon, authenticated;

create or replace function public.forum_set_role(p_id uuid, p_role text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.forum_is_admin() then raise exception 'Not authorized'; end if;
 if p_role not in ('admin','moderator','dayone','member') then raise exception 'Owner is fixed'; end if;
 if exists(select 1 from public.forum_roles where user_id=p_id and role='owner') then raise exception 'Owner is fixed'; end if;
 if not exists(select 1 from public.forum_profiles where id=p_id) then raise exception 'Invalid member'; end if;
 if p_role='member' then delete from public.forum_roles where user_id=p_id;
 else insert into public.forum_roles(user_id, role) values(p_id, p_role)
  on conflict (user_id) do update set role=excluded.role;
 end if;
end; $$;
revoke all on function public.forum_set_role(uuid, text) from public, anon, authenticated;
grant execute on function public.forum_set_role(uuid, text) to authenticated;

drop policy if exists topics_moderate on public.forum_topics;
create policy topics_moderate on public.forum_topics for update to authenticated using ((select public.forum_can_moderate())) with check ((select public.forum_can_moderate()));
drop policy if exists topics_delete on public.forum_topics;
create policy topics_delete on public.forum_topics for delete to authenticated using ((select public.forum_can_moderate()));
drop policy if exists replies_delete on public.forum_replies;
create policy replies_delete on public.forum_replies for delete to authenticated using ((select public.forum_can_moderate()));
commit;
