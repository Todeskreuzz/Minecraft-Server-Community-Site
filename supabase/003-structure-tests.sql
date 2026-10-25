-- Disposable CI database only. Confirms hierarchy, pins, and admin-only structure edits.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000e001','structure-member@example.invalid','{"display_name":"Structure Member"}'),
 ('00000000-0000-4000-8000-00000000e002','structure-owner@example.invalid','{"display_name":"Structure Owner"}');
insert into private.forum_admins values('00000000-0000-4000-8000-00000000e002');

do $$ begin
 if not exists(select 1 from public.forum_groups where id='community') then raise exception 'Community group missing'; end if;
 if not exists(select 1 from public.forum_categories where id='general' and group_id='community' and name_de='Allgemeines' and icon='message') then raise exception 'General board was not adopted'; end if;
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='forum_board_cards' and 'security_invoker=true'=any(c.reloptions)) then raise exception 'Board cards bypass invoker'; end if;
end $$;

set local role anon;
do $$ begin
 perform 1 from public.forum_groups;
 perform 1 from public.forum_board_cards;
 begin insert into public.forum_groups(id,position,name_de,name_en) values('secret',3,'Geheim','Secret'); raise exception 'Anon inserted a group'; exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e001',true);
set local role authenticated;
do $$ declare topic uuid; affected int; begin
 begin insert into public.forum_groups(id,position,name_de,name_en) values('nope',4,'Nein','No'); raise exception 'Member inserted a group'; exception when others then if sqlerrm not like '%row-level security%' then raise; end if; end;
 insert into public.forum_topics(title,body,category_id) values('Structure topic','Member can publish','general') returning id into topic;
 update public.forum_topics set pinned=true where id=topic; get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Member can pin topics'; end if;
 update public.forum_categories set name_de='Geändert' where id='general'; get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Member can edit boards'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e002',true);
set local role authenticated;
do $$ declare topic uuid; affected int; threads bigint; begin
 update public.forum_categories set name_de='Custom General',name_en='Custom General' where id='general';
 update public.forum_categories c set name_de=s.name_de from(values('general','Allgemeines')) as s(id,name_de) where c.id=s.id and c.name_de is null;
 if(select name_de from public.forum_categories where id='general')<>'Custom General' then raise exception 'Board name overwritten'; end if;
 select id into topic from public.forum_topics where title='Structure topic';
 update public.forum_topics set pinned=true where id=topic; get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Owner cannot pin'; end if;
 select thread_count into threads from public.forum_board_cards where id='general';
 if threads<1 then raise exception 'Board card missed a thread'; end if;
 if(select latest_title from public.forum_board_cards where id='general') is null then raise exception 'Latest post missing'; end if;
 begin delete from public.forum_groups where id='community'; raise exception 'Deleted a group that still has boards'; exception when foreign_key_violation then null; end;
 begin delete from public.forum_categories where id='general'; raise exception 'Deleted a board that still has threads'; exception when foreign_key_violation then null; end;
 insert into public.forum_groups(id,position,name_de,name_en) values('events',2,'Events','Events');
 insert into public.forum_categories(id,position,group_id,name_de,name_en) values('events-talk',5,'events','Treffen','Meetups');
 if(select icon from public.forum_categories where id='events-talk')<>'message' then raise exception 'Board icon default missing'; end if;
 delete from public.forum_categories where id='events-talk'; get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Owner cannot delete an empty board'; end if;
 delete from public.forum_groups where id='events'; get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Owner cannot delete an empty group'; end if;
end $$;
reset role;
do $$ begin raise notice 'Forum structure tests passed'; end $$;
rollback;
