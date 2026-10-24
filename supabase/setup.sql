-- Run once in Supabase SQL Editor. Transactional: failures roll back the setup.
begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
create table private.forum_admins(user_id uuid primary key references auth.users(id) on delete cascade);
create or replace function public.forum_is_admin() returns boolean language sql stable security definer set search_path = '' as $$
 select exists(select 1 from private.forum_admins where user_id=(select auth.uid()));
$$;
revoke all on function public.forum_is_admin() from public;
grant execute on function public.forum_is_admin() to anon, authenticated;

create table public.forum_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null check(char_length(display_name) between 2 and 32),
 created_at timestamptz not null default now()
);
create or replace function private.create_forum_profile() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 insert into public.forum_profiles(id,display_name) values(new.id,
 case when char_length(trim(new.raw_user_meta_data->>'display_name')) between 2 and 32
 then trim(new.raw_user_meta_data->>'display_name') else 'Spieler' end);
 return new;
end; $$;
create trigger on_forum_signup after insert on auth.users for each row execute function private.create_forum_profile();
-- Include accounts registered before setup without exposing their email addresses.
insert into public.forum_profiles(id,display_name) select id,
 case when char_length(trim(raw_user_meta_data->>'display_name')) between 2 and 32 then trim(raw_user_meta_data->>'display_name') else 'Spieler' end from auth.users;

create table public.forum_categories(id text primary key,position int not null);
insert into public.forum_categories values ('general',1),('builds',2),('help',3),('suggestions',4);
create table public.forum_topics(
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null default auth.uid() references public.forum_profiles(id) on delete cascade,
 category_id text not null references public.forum_categories(id),
 title text not null check(char_length(trim(title)) between 3 and 120),
 body text not null check(char_length(trim(body)) between 1 and 10000),
 locked boolean not null default false,
 created_at timestamptz not null default now()
);
create table public.forum_replies(
 id uuid primary key default gen_random_uuid(),
 topic_id uuid not null references public.forum_topics(id) on delete cascade,
 author_id uuid not null default auth.uid() references public.forum_profiles(id) on delete cascade,
 body text not null check(char_length(trim(body)) between 1 and 10000),
 created_at timestamptz not null default now()
);
create index forum_topics_recent on public.forum_topics(created_at desc);
create index forum_replies_topic on public.forum_replies(topic_id,created_at);
create index forum_topics_author on public.forum_topics(author_id,created_at);
create index forum_replies_author on public.forum_replies(author_id,created_at);
create table public.forum_owner_settings(
 id int primary key default 1 check(id=1),
 notes text not null default '' check(char_length(notes)<=10000)
);
insert into public.forum_owner_settings(id) values(1);

-- One write at a time per user, with a small posting cooldown.
create function private.forum_post_guard() returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.author_id is distinct from auth.uid() then raise exception 'Invalid author'; end if;
 perform pg_advisory_xact_lock(hashtextextended(new.author_id::text,0));
 new.created_at := now();
 if tg_table_name='forum_topics' then
  new.locked := false;
  if exists(select 1 from public.forum_topics where author_id=new.author_id and created_at>now()-interval '30 seconds') then raise exception 'Please wait 30 seconds between topics'; end if;
 else
  perform 1 from public.forum_topics where id=new.topic_id and not locked for share;
  if not found then raise exception 'Topic closed or missing'; end if;
  if exists(select 1 from public.forum_replies where author_id=new.author_id and created_at>now()-interval '5 seconds') then raise exception 'Please wait 5 seconds between replies'; end if;
 end if;
 return new;
end; $$;
create trigger forum_topic_guard before insert on public.forum_topics for each row execute function private.forum_post_guard();
create trigger forum_reply_guard before insert on public.forum_replies for each row execute function private.forum_post_guard();

alter table public.forum_profiles enable row level security;
alter table public.forum_categories enable row level security;
alter table public.forum_topics enable row level security;
alter table public.forum_replies enable row level security;
alter table public.forum_owner_settings enable row level security;
revoke all on public.forum_profiles,public.forum_categories,public.forum_topics,public.forum_replies,public.forum_owner_settings from anon,authenticated;
grant select on public.forum_profiles,public.forum_categories,public.forum_topics,public.forum_replies to anon,authenticated;
grant insert(title,body,category_id) on public.forum_topics to authenticated;
grant insert(topic_id,body) on public.forum_replies to authenticated;
grant update(locked) on public.forum_topics to authenticated;
grant delete on public.forum_topics,public.forum_replies to authenticated;
grant select on public.forum_owner_settings to authenticated;
grant update(notes) on public.forum_owner_settings to authenticated;
create policy profiles_read on public.forum_profiles for select using(true);
create policy categories_read on public.forum_categories for select using(true);
create policy topics_read on public.forum_topics for select using(true);
create policy replies_read on public.forum_replies for select using(true);
create policy topics_create on public.forum_topics for insert to authenticated with check(author_id=(select auth.uid()) and not locked);
create policy replies_create on public.forum_replies for insert to authenticated with check(author_id=(select auth.uid()) and exists(select 1 from public.forum_topics t where t.id=topic_id and not t.locked));
create policy topics_moderate on public.forum_topics for update to authenticated using((select public.forum_is_admin())) with check((select public.forum_is_admin()));
create policy topics_delete on public.forum_topics for delete to authenticated using((select public.forum_is_admin()));
create policy replies_delete on public.forum_replies for delete to authenticated using((select public.forum_is_admin()));
create policy owner_read on public.forum_owner_settings for select to authenticated using((select public.forum_is_admin()));
create policy owner_update on public.forum_owner_settings for update to authenticated using((select public.forum_is_admin())) with check((select public.forum_is_admin()));
revoke all on function private.create_forum_profile(),private.forum_post_guard() from public,anon,authenticated;
commit;

-- AFTER signing up and confirming YOUR account, assign owner rights separately:
-- insert into private.forum_admins(user_id)
-- select id from auth.users where email = 'YOUR_OWN_EMAIL';
-- Never run this with somebody else's address; no automatic first-user admin.
