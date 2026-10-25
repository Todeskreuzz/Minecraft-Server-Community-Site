-- Disposable CI database only. Friend requests, legacy copy, and owner-name visibility.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000a001','friend-owner@example.invalid','{"display_name":"Hidden Owner"}'),
 ('00000000-0000-4000-8000-00000000a002','friend-one@example.invalid','{"display_name":"Friend One"}'),
 ('00000000-0000-4000-8000-00000000a003','friend-two@example.invalid','{"display_name":"Friend Two"}');
insert into private.forum_admins values('00000000-0000-4000-8000-00000000a001');
insert into private.forum_friends(owner_id,friend_id) values('00000000-0000-4000-8000-00000000a001','00000000-0000-4000-8000-00000000a002');
select private.copy_legacy_friends();

do $$ begin
 if to_regclass('private.forum_friends') is null then raise exception 'Legacy friend table was dropped'; end if;
 if not exists(select 1 from public.friendships where user_id='00000000-0000-4000-8000-00000000a001' and friend_id='00000000-0000-4000-8000-00000000a002' and status='accepted') then raise exception 'Legacy friend was not copied'; end if;
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='forum_profile_cards' and 'security_invoker=true'=any(c.reloptions)) then raise exception 'Profile cards bypass invoker'; end if;
end $$;

set local role anon;
do $$ begin
 if exists(select 1 from public.friendships where status='pending') then raise exception 'Anon saw a pending request'; end if;
 if (select friend_count from public.forum_profile_cards where id='00000000-0000-4000-8000-00000000a001') < 1 then raise exception 'Public friend count missing'; end if;
 begin perform public.forum_friend_request(1); raise exception 'Anon sent a request'; exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000a002',true);
set local role authenticated;
do $$ declare label text; begin
 select display_name into label from public.forum_author_names(array['00000000-0000-4000-8000-00000000a001']::uuid[]);
 if label is distinct from 'Hidden Owner' then raise exception 'Accepted friend cannot see the owner name'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000a003',true);
set local role authenticated;
do $$ declare owner_uid bigint; begin
 if exists(select 1 from public.forum_author_names(array['00000000-0000-4000-8000-00000000a001']::uuid[]) where display_name is not null) then raise exception 'Stranger can see the owner name'; end if;
 select uid into owner_uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000a002';
 perform public.forum_friend_request(owner_uid);
 if public.forum_friend_state('00000000-0000-4000-8000-00000000a002') <> 'outgoing' then raise exception 'Request was not outgoing'; end if;
 begin perform public.forum_friend_request((select uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000a003')); raise exception 'Self request'; exception when raise_exception then if sqlerrm <> 'Invalid member' then raise; end if; end;
 perform public.forum_touch();
 if (select last_seen from public.forum_profiles where id='00000000-0000-4000-8000-00000000a003') is null then raise exception 'Presence was not stored'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000a002',true);
set local role authenticated;
do $$ begin
 if public.forum_friend_state('00000000-0000-4000-8000-00000000a003') <> 'incoming' then raise exception 'Incoming request missing'; end if;
 if not exists(select 1 from public.forum_friend_panel() where id='00000000-0000-4000-8000-00000000a003' and relation='incoming') then raise exception 'Panel missed the request'; end if;
 perform public.forum_friend_act('00000000-0000-4000-8000-00000000a003','accept');
 if public.forum_friend_state('00000000-0000-4000-8000-00000000a003') <> 'accepted' then raise exception 'Accept failed'; end if;
 perform public.forum_friend_act('00000000-0000-4000-8000-00000000a003','remove');
 if public.forum_friend_state('00000000-0000-4000-8000-00000000a003') <> 'none' then raise exception 'Remove failed'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000a003',true);
set local role authenticated;
select public.forum_friend_request((select uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000a002'));
select public.forum_friend_act('00000000-0000-4000-8000-00000000a002','cancel');
do $$ begin
 if exists(select 1 from public.friendships where status='pending' and user_id='00000000-0000-4000-8000-00000000a003') then raise exception 'Cancel left a request'; end if;
 perform public.forum_friend_act('00000000-0000-4000-8000-00000000a002','block');
 begin perform public.forum_friend_request((select uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000a002')); raise exception 'Blocked request succeeded'; exception when raise_exception then if sqlerrm <> 'Blocked' then raise; end if; end;
end $$;
reset role;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000a003","is_anonymous":true}',true);
set local role authenticated;
do $$ begin
 begin perform public.forum_friend_request(1); raise exception 'Anonymous request'; exception when raise_exception then if sqlerrm <> 'Not authorized' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claims','{}',true);
do $$ begin raise notice 'Friend tests passed'; end $$;
rollback;
