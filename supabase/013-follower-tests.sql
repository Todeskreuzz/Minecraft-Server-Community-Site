-- Disposable CI database only; fixtures roll back.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000f101','follow1@example.invalid','{"display_name":"Follower"}'),
 ('00000000-0000-4000-8000-00000000f102','follow2@example.invalid','{"display_name":"Followed"}'),
 ('00000000-0000-4000-8000-00000000f103','follow3@example.invalid','{"display_name":"Other"}');
insert into private.forum_owner_names(user_id,real_name) values ('00000000-0000-4000-8000-00000000f102','HiddenOwner');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000f101',true);
select set_config('request.jwt.claims','{"is_anonymous":false}',true);
set local role authenticated;
insert into public.forum_follows(follower_id,followed_id) values ('00000000-0000-4000-8000-00000000f101','00000000-0000-4000-8000-00000000f102');
do $$ begin
 if (select follower_count from public.forum_follow_stats('00000000-0000-4000-8000-00000000f102'))<>1 then raise exception 'Wrong count';end if;
 if (select display_name from public.forum_author_names(array['00000000-0000-4000-8000-00000000f102']::uuid[]))='HiddenOwner' then raise exception 'Follow leaked private owner name';end if;
 begin
  insert into public.forum_follows(follower_id,followed_id) values ('00000000-0000-4000-8000-00000000f101','00000000-0000-4000-8000-00000000f101');
  raise exception 'Self follow allowed';exception when check_violation then null;end;
 begin
  insert into public.forum_follows(follower_id,followed_id) values ('00000000-0000-4000-8000-00000000f101','00000000-0000-4000-8000-00000000f102');
  raise exception 'Duplicate allowed';exception when unique_violation then null;end;
 begin
  insert into public.forum_follows(follower_id,followed_id) values ('00000000-0000-4000-8000-00000000f103','00000000-0000-4000-8000-00000000f102');
  raise exception 'Forged follow allowed';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000f103',true);
set local role authenticated;
delete from public.forum_follows where followed_id='00000000-0000-4000-8000-00000000f102';
do $$ begin if (select count(*) from public.forum_follows)<>1 then raise exception 'Deleted another member follow';end if;end $$;
reset role;
select set_config('request.jwt.claims','{"is_anonymous":true}',true);
set local role authenticated;
do $$ begin
 begin
 insert into public.forum_follows(follower_id,followed_id) values ('00000000-0000-4000-8000-00000000f103','00000000-0000-4000-8000-00000000f102');
 raise exception 'Anonymous auth followed';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
 if (select follower_count from public.forum_follow_stats('00000000-0000-4000-8000-00000000f102'))<>1 then raise exception 'Public count missing';end if;
 begin
 insert into public.forum_follows(follower_id,followed_id) values ('00000000-0000-4000-8000-00000000f103','00000000-0000-4000-8000-00000000f102');
 raise exception 'Public visitor followed';exception when insufficient_privilege then null;end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000f101',true);
select set_config('request.jwt.claims','{"is_anonymous":false}',true);
set local role authenticated;
delete from public.forum_follows where followed_id='00000000-0000-4000-8000-00000000f102';
do $$ begin if (select count(*) from public.forum_follows)<>0 then raise exception 'Unfollow failed';end if;end $$;
reset role;
rollback;
