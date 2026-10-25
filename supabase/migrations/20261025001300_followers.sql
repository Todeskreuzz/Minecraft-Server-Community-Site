-- Public follows are separate from friendship and never grant private-name access.
begin;
create table if not exists public.forum_follows (
 follower_id uuid not null references public.forum_profiles(id) on delete cascade,
 followed_id uuid not null references public.forum_profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 primary key (follower_id, followed_id),
 check (follower_id <> followed_id)
);
create index if not exists forum_follows_target on public.forum_follows(followed_id, created_at desc, follower_id);
alter table public.forum_follows enable row level security;
revoke all on public.forum_follows from public, anon, authenticated;
grant select on public.forum_follows to anon, authenticated;
grant insert (follower_id,followed_id), delete on public.forum_follows to authenticated;
drop policy if exists follows_read on public.forum_follows;
create policy follows_read on public.forum_follows for select to anon, authenticated using (true);
drop policy if exists follows_insert on public.forum_follows;
create policy follows_insert on public.forum_follows for insert to authenticated with check (
 follower_id=(select auth.uid()) and coalesce((select auth.jwt()->>'is_anonymous'),'false')='false'
);
drop policy if exists follows_delete on public.forum_follows;
create policy follows_delete on public.forum_follows for delete to authenticated using (
 follower_id=(select auth.uid()) and coalesce((select auth.jwt()->>'is_anonymous'),'false')='false'
);
create or replace function public.forum_follow_stats(p_id uuid)
returns table(follower_count bigint, following boolean) language sql stable security invoker set search_path='' as $$
 select count(*), coalesce(bool_or(f.follower_id=auth.uid()),false)
 from public.forum_follows f where f.followed_id=p_id;
$$;
revoke all on function public.forum_follow_stats(uuid) from public, anon, authenticated;
grant execute on function public.forum_follow_stats(uuid) to anon, authenticated;
commit;
