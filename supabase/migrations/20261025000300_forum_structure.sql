-- Forum groups (Oberkategorien), board copy, and pinned threads.
-- Additive and safe to reapply. Existing categories become boards in Community.
-- Names already stored by an admin are left untouched.
begin;

create table if not exists public.forum_groups(
 id text primary key check(id ~ '^[a-z0-9-]{2,32}$'),
 position int not null check(position between 1 and 999),
 name_de text not null check(char_length(trim(name_de)) between 2 and 80),
 name_en text not null check(char_length(trim(name_en)) between 2 and 80),
 description_de text not null default '' check(char_length(description_de)<=400),
 description_en text not null default '' check(char_length(description_en)<=400)
);

insert into public.forum_groups(id,position,name_de,name_en,description_de,description_en)
values('community',1,'Community','Community','Gespräche, Bauwerke, Fragen und Ideen.','Conversations, builds, questions and ideas.')
on conflict do nothing;

alter table public.forum_categories add column if not exists group_id text;
alter table public.forum_categories add column if not exists name_de text;
alter table public.forum_categories add column if not exists name_en text;
alter table public.forum_categories add column if not exists description_de text;
alter table public.forum_categories add column if not exists description_en text;
alter table public.forum_categories add column if not exists icon text;

update public.forum_categories set group_id='community' where group_id is null;

update public.forum_categories c
set name_de=s.name_de,name_en=s.name_en,
 description_de=coalesce(c.description_de,s.description_de),
 description_en=coalesce(c.description_en,s.description_en),
 icon=coalesce(nullif(c.icon,''),s.icon)
from(values
 ('general','Allgemeines','General','Vorstellen, Plaudern und alles rund um den Server.','Introductions, chat and everything about the server.','message'),
 ('builds','Bauwerke & Projekte','Builds & projects','Zeigt eure Bauwerke und Projekte.','Show your builds and projects.','grid'),
 ('help','Fragen & Hilfe','Questions & help','Fragen zur Technik, zum Modpack und zum Spiel.','Questions about tech, the modpack and the game.','help'),
 ('suggestions','Ideen & Vorschläge','Ideas & suggestions','Ideen für den Server und die Community.','Ideas for the server and the community.','idea')
) as s(id,name_de,name_en,description_de,description_en,icon)
where c.id=s.id and c.name_de is null;

update public.forum_categories
set name_de=initcap(replace(id,'-',' ')),name_en=initcap(replace(id,'-',' ')),
 description_de=coalesce(description_de,''),description_en=coalesce(description_en,''),
 icon=coalesce(nullif(icon,''),'message')
where name_de is null;

update public.forum_categories
set description_de=coalesce(description_de,''),description_en=coalesce(description_en,''),
 icon=coalesce(nullif(icon,''),'message')
where description_de is null or description_en is null or icon is null or icon='';

alter table public.forum_categories alter column description_de set default '';
alter table public.forum_categories alter column description_en set default '';
alter table public.forum_categories alter column icon set default 'message';
-- The original category seed inserts only id and position. PostgreSQL checks
-- NOT NULL before ON CONFLICT, so omitted columns need defaults that pass.
alter table public.forum_categories alter column group_id set default 'community';
alter table public.forum_categories alter column name_de set default 'Board';
alter table public.forum_categories alter column name_en set default 'Board';

do $$ begin
 if not exists(select 1 from public.forum_categories where group_id is null or name_de is null or name_en is null or description_de is null or description_en is null or icon is null) then
  alter table public.forum_categories alter column group_id set not null;
  alter table public.forum_categories alter column name_de set not null;
  alter table public.forum_categories alter column name_en set not null;
  alter table public.forum_categories alter column description_de set not null;
  alter table public.forum_categories alter column description_en set not null;
  alter table public.forum_categories alter column icon set not null;
 end if;
 if not exists(select 1 from pg_constraint where conname='forum_categories_group_fkey') then
  alter table public.forum_categories add constraint forum_categories_group_fkey foreign key(group_id) references public.forum_groups(id) on delete restrict;
 end if;
 if not exists(select 1 from pg_constraint where conname='forum_categories_id_check') then
  alter table public.forum_categories add constraint forum_categories_id_check check(id ~ '^[a-z0-9-]{2,32}$');
 end if;
 if not exists(select 1 from pg_constraint where conname='forum_categories_name_de_check') then
  alter table public.forum_categories add constraint forum_categories_name_de_check check(char_length(trim(name_de)) between 2 and 80);
 end if;
 if not exists(select 1 from pg_constraint where conname='forum_categories_name_en_check') then
  alter table public.forum_categories add constraint forum_categories_name_en_check check(char_length(trim(name_en)) between 2 and 80);
 end if;
 if not exists(select 1 from pg_constraint where conname='forum_categories_description_de_check') then
  alter table public.forum_categories add constraint forum_categories_description_de_check check(char_length(description_de)<=400);
 end if;
 if not exists(select 1 from pg_constraint where conname='forum_categories_description_en_check') then
  alter table public.forum_categories add constraint forum_categories_description_en_check check(char_length(description_en)<=400);
 end if;
 if not exists(select 1 from pg_constraint where conname='forum_categories_icon_check') then
  alter table public.forum_categories add constraint forum_categories_icon_check check(icon in('message','grid','help','idea'));
 end if;
end $$;

alter table public.forum_topics add column if not exists pinned boolean not null default false;
create index if not exists forum_categories_group on public.forum_categories(group_id,position);
create index if not exists forum_topics_board on public.forum_topics(category_id,pinned desc,created_at desc);

alter table public.forum_groups enable row level security;
revoke all on public.forum_groups from anon,authenticated;
grant select on public.forum_groups to anon,authenticated;
grant insert,update,delete on public.forum_groups to authenticated;
drop policy if exists groups_read on public.forum_groups;
create policy groups_read on public.forum_groups for select using(true);
drop policy if exists groups_write on public.forum_groups;
create policy groups_write on public.forum_groups for all to authenticated
 using((select public.forum_is_admin())) with check((select public.forum_is_admin()));

grant insert,update,delete on public.forum_categories to authenticated;
grant update(pinned) on public.forum_topics to authenticated;
drop policy if exists categories_write on public.forum_categories;
create policy categories_write on public.forum_categories for all to authenticated
 using((select public.forum_is_admin())) with check((select public.forum_is_admin()));

drop view if exists public.forum_board_cards;
create view public.forum_board_cards with (security_invoker=true) as
select c.id,c.position,c.group_id,c.name_de,c.name_en,c.description_de,c.description_en,c.icon,
 g.position as group_position,g.name_de as group_name_de,g.name_en as group_name_en,
 g.description_de as group_description_de,g.description_en as group_description_en,
 (select count(*) from public.forum_topics t where t.category_id=c.id) as thread_count,
 (select count(*) from public.forum_topics t where t.category_id=c.id)
  +(select count(*) from public.forum_replies r join public.forum_topics t on t.id=r.topic_id where t.category_id=c.id) as post_count,
 latest.id as latest_id,latest.title as latest_title,latest.author_id as latest_author_id,latest.created_at as latest_at
from public.forum_categories c
join public.forum_groups g on g.id=c.group_id
left join lateral(
 select id,title,author_id,created_at from(
  select t.id,t.title,t.author_id,t.created_at from public.forum_topics t where t.category_id=c.id
  union all
  select t.id,t.title,r.author_id,r.created_at from public.forum_replies r join public.forum_topics t on t.id=r.topic_id where t.category_id=c.id
 ) activity order by created_at desc limit 1
) latest on true;

revoke all on public.forum_board_cards from public,anon,authenticated;
grant select on public.forum_board_cards to anon,authenticated;

commit;
