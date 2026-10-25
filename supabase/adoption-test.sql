-- Disposable CI database only. Files included below have BEGIN/COMMIT removed.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000d001','adoption@example.invalid','{"display_name":"PreservedMember"}');
insert into private.forum_admins values('00000000-0000-4000-8000-00000000d001');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000d001',true);
insert into public.forum_topics(id,title,body,category_id) values
 ('00000000-0000-4000-8000-00000000d002','Preserved topic','Preserved body','general');
update public.forum_owner_settings set notes='Preserved owner notes' where id=1;
\ir .adoption-forum.sql
\ir .adoption-identity.sql
do $$ begin
 if exists(select 1 from information_schema.columns where table_schema='public' and table_name='forum_categories' and column_name='name_de') then
  update public.forum_categories set name_de='Custom General',name_en='Custom General' where id='general';
 end if;
end $$;
\ir .adoption-structure.sql
do $$ begin
 if not exists(select 1 from public.forum_topics where id='00000000-0000-4000-8000-00000000d002' and body='Preserved body') then raise exception 'Existing topic lost';end if;
 if not exists(select 1 from public.forum_owner_settings where notes='Preserved owner notes') then raise exception 'Owner notes lost';end if;
 if not exists(select 1 from private.forum_admins where user_id='00000000-0000-4000-8000-00000000d001') then raise exception 'Owner grant lost';end if;
 if not exists(select 1 from public.forum_profiles where id='00000000-0000-4000-8000-00000000d001' and display_name='Owner') then raise exception 'Private owner label lost';end if;
 if not exists(select 1 from private.forum_owner_names where user_id='00000000-0000-4000-8000-00000000d001' and real_name='PreservedMember') then raise exception 'Private name lost';end if;
 if not exists(select 1 from public.forum_categories where id='general' and group_id='community' and name_de in('Custom General','Allgemeines')) then raise exception 'Board adoption lost the general category';end if;
 if not exists(select 1 from public.forum_groups where id='community') then raise exception 'Community group lost';end if;
 if not exists(select 1 from public.forum_board_cards where id='general' and thread_count>=1) then raise exception 'Preserved topic missing from its board';end if;
 if exists(select 1 from public.forum_topics where id='00000000-0000-4000-8000-00000000d002' and pinned) then raise exception 'Preserved topic was pinned by migration';end if;
end $$;
rollback;
