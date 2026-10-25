-- Disposable CI database only. Groups, link codes and the bridge queue.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000e001','group-owner@example.invalid','{"display_name":"Group Owner"}'),
 ('00000000-0000-4000-8000-00000000e002','group-member@example.invalid','{"display_name":"Group Member"}');
select private.set_bridge_secret('test-bridge-secret-value-24');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e001',true);
set local role authenticated;
select public.forum_set_minecraft('OwnerPlayer');
do $$ declare code text; gid uuid; begin
 begin perform public.forum_create_group('Friends','bad tag','green',''); raise exception 'Bad tag stored'; exception when raise_exception then if sqlerrm <> 'Invalid tag' then raise; end if; end;
 gid := public.forum_create_group('Friends','FaF','green','Zusammen spielen');
 if (select tag from public.player_groups where id=gid) <> 'FAF' then raise exception 'Tag was not normalized'; end if;
 begin perform public.forum_create_group('Other','FAF','gold',''); raise exception 'Duplicate tag stored'; exception when raise_exception then if sqlerrm <> 'Tag already used' then raise; end if; end;
 code := public.forum_link_code();
 if char_length(code) <> 8 then raise exception 'Link code length'; end if;
 perform set_config('faf.group_code', code, true);
 perform set_config('faf.group_id', gid::text, true);
end $$;
reset role;
do $$ begin
 if (select count(*) from public.mc_sync_queue where kind='create_group' and payload->>'tag'='FAF') <> 1 then raise exception 'Create job missing'; end if;
end $$;

select public.bridge_link('test-bridge-secret-value-24', current_setting('faf.group_code'), 'OwnerPlayer');
do $$ begin
 if (select minecraft_verified from public.forum_profiles where id='00000000-0000-4000-8000-00000000e001') is not true then raise exception 'Name stayed unverified'; end if;
 if (select count(*) from public.mc_sync_queue where kind='add_member' and payload->>'player'='OwnerPlayer') <> 1 then raise exception 'Verified member was not queued'; end if;
 begin perform public.bridge_claim('wrong-secret-value-000000000'); raise exception 'Wrong bridge secret worked'; exception when raise_exception then if sqlerrm <> 'Not authorized' then raise; end if; end;
 if jsonb_array_length(public.bridge_claim('test-bridge-secret-value-24')) < 2 then raise exception 'Bridge claim was empty'; end if;
end $$;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e002',true);
set local role authenticated;
select public.forum_group_request(current_setting('faf.group_id')::uuid);
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e001',true);
set local role authenticated;
select public.forum_group_act(current_setting('faf.group_id')::uuid, '00000000-0000-4000-8000-00000000e002', 'accept');
do $$ begin
 if (select status from public.player_group_members where user_id='00000000-0000-4000-8000-00000000e002') <> 'member' then raise exception 'Request was not accepted'; end if;
end $$;
select public.forum_group_act(current_setting('faf.group_id')::uuid, '00000000-0000-4000-8000-00000000e002', 'kick');
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000e002',true);
set local role authenticated;
do $$ begin
 begin perform public.forum_delete_group(current_setting('faf.group_id')::uuid); raise exception 'Member deleted the group'; exception when raise_exception then if sqlerrm <> 'Not authorized' then raise; end if; end;
end $$;
reset role;

select public.bridge_done('test-bridge-secret-value-24', array(select id from public.mc_sync_queue));
do $$ begin
 if exists(select 1 from public.mc_sync_queue where done_at is null) then raise exception 'Queue stayed open'; end if;
 raise notice 'Group tests passed';
end $$;
rollback;
