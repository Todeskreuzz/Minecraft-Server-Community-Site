-- Run after setup.sql as postgres in SQL Editor; all fixtures roll back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000f001','forum-test-member@example.invalid','{"display_name":"Test Member"}'),
 ('00000000-0000-4000-8000-00000000f002','forum-test-owner@example.invalid','{"display_name":"Test Owner"}');
insert into private.forum_admins values('00000000-0000-4000-8000-00000000f002');
set local role anon;
do $$ begin
 perform * from public.forum_categories;
 if public.forum_is_admin() then raise exception 'Anonymous user became admin'; end if;
 begin perform * from public.forum_owner_settings; raise exception 'Anonymous owner access'; exception when insufficient_privilege then null; end;
 begin insert into public.forum_topics(title,body,category_id) values('Anonymous topic','Not allowed','general'); raise exception 'Anonymous insert allowed'; exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000f001',true);
set local role authenticated;
do $$ declare topic uuid; affected int; begin
 if public.forum_is_admin() then raise exception 'Member became admin'; end if;
 if exists(select 1 from public.forum_owner_settings) then raise exception 'Member can read notes'; end if;
 begin insert into private.forum_admins values(auth.uid()); raise exception 'Member promoted self'; exception when insufficient_privilege then null; end;
 begin insert into public.forum_topics(author_id,title,body,category_id) values('00000000-0000-4000-8000-00000000f002','Forged author','Bad','general'); raise exception 'Forged author allowed'; exception when insufficient_privilege then null; end;
 insert into public.forum_topics(title,body,category_id) values('Permission test topic','Member can publish','general') returning id into topic;
 insert into public.forum_replies(topic_id,body) values(topic,'Member can reply');
 update public.forum_topics set locked=true where id=topic; get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Member can lock topics'; end if;
 delete from public.forum_topics where id=topic; get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Member can delete topics'; end if;
 update public.forum_owner_settings set notes='Unauthorized';get diagnostics affected=row_count;
 if affected<>0 then raise exception 'Member can write notes'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000f002',true);
set local role authenticated;
do $$ declare topic uuid; affected int; begin
 if not public.forum_is_admin() then raise exception 'Owner not recognized'; end if;
 update public.forum_owner_settings set notes='Test private note' where id=1; get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Owner cannot save notes'; end if;
 select id into topic from public.forum_topics where author_id='00000000-0000-4000-8000-00000000f001';
 update public.forum_topics set locked=true where id=topic; get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Owner cannot moderate'; end if;
 begin insert into public.forum_replies(topic_id,body) values(topic,'Locked reply must fail');raise exception 'Locked reply allowed';exception when raise_exception then if sqlerrm<>'Topic closed or missing' then raise; end if;end;
 delete from public.forum_topics where id=topic;get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Owner cannot remove topic';end if;
end $$;
reset role;
do $$ begin raise notice 'Forum permission tests passed'; end $$;
rollback;
