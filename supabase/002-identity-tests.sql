-- Run AFTER 002-identity.sql. Fixtures are rolled back; no real accounts changed.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000e001','identity-owner@example.invalid','{"display_name":"PrivateTestName"}'),
 ('00000000-0000-4000-8000-00000000e002','identity-friend@example.invalid','{"display_name":"FriendTest"}'),
 ('00000000-0000-4000-8000-00000000e003','identity-other@example.invalid','{"display_name":"OtherTest"}');
insert into private.forum_admins values('00000000-0000-4000-8000-00000000e001');
set local role anon;
do $$ declare label text;owner boolean;begin
 select display_name,is_owner into label,owner from public.forum_author_names(array['00000000-0000-4000-8000-00000000e001']::uuid[]);
 if label is not null or owner is distinct from true then raise exception 'Anonymous owner name disclosure';end if;
 if exists(select 1 from public.forum_profiles where id='00000000-0000-4000-8000-00000000e001' and display_name<>'Owner') then raise exception 'Raw public profile leaked name';end if;
 begin perform * from private.forum_owner_names;raise exception 'Private table readable';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e001',true);
set local role authenticated;
select public.forum_set_owner_name('PrivateTestName');
select public.forum_set_friend('00000000-0000-4000-8000-00000000e002',true);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e002',true);
set local role authenticated;
do $$ declare label text;begin
 select display_name into label from public.forum_author_names(array['00000000-0000-4000-8000-00000000e001']::uuid[]);
 if label is distinct from 'PrivateTestName' then raise exception 'Approved friend cannot see name';end if;
 if exists(select 1 from public.forum_my_friends()) then raise exception 'Non-owner can list friendships';end if;
 begin perform public.forum_set_friend('00000000-0000-4000-8000-00000000e003',true);raise exception 'Member can approve friends';exception when raise_exception then if sqlerrm<>'Not authorized' then raise;end if;end;
 begin perform public.forum_set_owner_name('Spoof');raise exception 'Member can change owner name';exception when raise_exception then if sqlerrm<>'Not authorized' then raise;end if;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e003',true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.forum_author_names(array['00000000-0000-4000-8000-00000000e001']::uuid[]) where display_name is not null) then raise exception 'Other member can see name';end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e001',true);
set local role authenticated;
select public.forum_set_friend('00000000-0000-4000-8000-00000000e002',false);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e002',true);
set local role authenticated;
do $$ begin
 if exists(select 1 from public.forum_author_names(array['00000000-0000-4000-8000-00000000e001']::uuid[]) where display_name is not null) then raise exception 'Removed friend can still fetch name';end if;
end $$;
reset role;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000e002","is_anonymous":true}',true);
set local role authenticated;
do $$ begin
 begin insert into public.forum_topics(title,body,category_id) values('Anonymous write','Must be denied','general');raise exception 'Anonymous auth can write';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claims','{}',true);
do $$ begin raise notice 'Identity permission tests passed';end $$;
rollback;
