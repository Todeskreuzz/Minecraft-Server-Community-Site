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
 if not exists(select 1 from public.forum_topics where id='00000000-0000-4000-8000-00000000d002' and body='Preserved body') then raise exception 'Existing topic lost';end if;
 if not exists(select 1 from public.forum_owner_settings where notes='Preserved owner notes') then raise exception 'Owner notes lost';end if;
 if not exists(select 1 from private.forum_admins where user_id='00000000-0000-4000-8000-00000000d001') then raise exception 'Owner grant lost';end if;
 if not exists(select 1 from public.forum_profiles where id='00000000-0000-4000-8000-00000000d001' and display_name='Owner') then raise exception 'Private owner label lost';end if;
 if not exists(select 1 from private.forum_owner_names where user_id='00000000-0000-4000-8000-00000000d001' and real_name='PreservedMember') then raise exception 'Private name lost';end if;
end $$;
rollback;
