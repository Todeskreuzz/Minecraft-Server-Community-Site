-- Disposable CI database only. The first ten UIDs receive Day One.
begin;
select setval('public.forum_uid_seq', 1, false);
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000c001','day-01@example.invalid','{"display_name":"Day One"}'),
 ('00000000-0000-4000-8000-00000000c002','day-02@example.invalid','{"display_name":"Early Two"}'),
 ('00000000-0000-4000-8000-00000000c003','day-03@example.invalid','{"display_name":"Early Three"}'),
 ('00000000-0000-4000-8000-00000000c004','day-04@example.invalid','{"display_name":"Early Four"}'),
 ('00000000-0000-4000-8000-00000000c005','day-05@example.invalid','{"display_name":"Early Five"}'),
 ('00000000-0000-4000-8000-00000000c006','day-06@example.invalid','{"display_name":"Early Six"}'),
 ('00000000-0000-4000-8000-00000000c007','day-07@example.invalid','{"display_name":"Early Seven"}'),
 ('00000000-0000-4000-8000-00000000c008','day-08@example.invalid','{"display_name":"Early Eight"}'),
 ('00000000-0000-4000-8000-00000000c009','day-09@example.invalid','{"display_name":"Early Nine"}'),
 ('00000000-0000-4000-8000-00000000c010','day-10@example.invalid','{"display_name":"Early Ten"}'),
 ('00000000-0000-4000-8000-00000000c011','day-11@example.invalid','{"display_name":"Later Member"}');
select private.sync_dayone_roles();
insert into private.forum_admins values('00000000-0000-4000-8000-00000000c001');
select private.sync_owner_role();
select private.sync_dayone_roles();

do $$ begin
 if (select role from public.forum_roles where user_id='00000000-0000-4000-8000-00000000c001') <> 'owner' then raise exception 'Owner lost Day One promotion'; end if;
 if (select count(*) from public.forum_roles r join public.forum_profiles p on p.id=r.user_id where p.uid between 2 and 10 and r.role='dayone') <> 9 then raise exception 'Early UIDs missed Day One'; end if;
 if exists(select 1 from public.forum_roles where user_id='00000000-0000-4000-8000-00000000c011') then raise exception 'UID 11 received a rank'; end if;
end $$;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000c011',true);
set local role authenticated;
do $$ begin
 begin update public.forum_profiles set avatar_preset='aurora' where id='00000000-0000-4000-8000-00000000c011'; raise exception 'Later member took Aurora'; exception when raise_exception then if sqlerrm <> 'Day One only' then raise; end if; end;
 begin perform public.forum_set_media('avatar','\x474946383961'::bytea); raise exception 'Later member sent a GIF'; exception when raise_exception then if sqlerrm <> 'Day One only' then raise; end if; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000c002',true);
set local role authenticated;
update public.forum_profiles set background_preset='voxels' where id='00000000-0000-4000-8000-00000000c002';
do $$ begin
 begin perform public.forum_set_media('banner','\x474946383961'::bytea); raise exception 'Missing GIF accepted'; exception when raise_exception then if sqlerrm <> 'Image missing' then raise; end if; end;
end $$;
reset role;

do $$ begin
 begin
  insert into storage.objects(bucket_id,name,metadata) values ('profile-media','00000000-0000-4000-8000-00000000c011/avatar.gif','{"size":100,"mimetype":"image/gif"}');
  raise exception 'Ineligible GIF stored';
 exception when others then if sqlerrm not like '%Day One only%' then raise; end if; end;
 begin
  insert into storage.objects(bucket_id,name,metadata) values ('profile-media','00000000-0000-4000-8000-00000000c002/avatar.gif','{"size":3000000,"mimetype":"image/gif"}');
  raise exception 'Oversized GIF stored';
 exception when others then if sqlerrm not like '%too large%' then raise; end if; end;
end $$;

insert into storage.objects(bucket_id,name,metadata) values
 ('profile-media','00000000-0000-4000-8000-00000000c002/avatar.webp','{"size":1000,"mimetype":"image/webp"}'),
 ('profile-media','00000000-0000-4000-8000-00000000c002/avatar.gif','{"size":2000,"mimetype":"image/gif"}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000c002',true);
set local role authenticated;
select public.forum_set_media('avatar','\x474946383961'::bytea);
do $$ begin
 if (select avatar_path from public.forum_profiles where id='00000000-0000-4000-8000-00000000c002') <> '00000000-0000-4000-8000-00000000c002/avatar.gif' then raise exception 'GIF path was not stored'; end if;
 if (select avatar_preset from public.forum_profiles where id='00000000-0000-4000-8000-00000000c002') <> '' then raise exception 'GIF left a preset active'; end if;
 if (select background_preset from public.forum_profiles where id='00000000-0000-4000-8000-00000000c002') <> 'voxels' then raise exception 'Voxel preset was cleared'; end if;
end $$;
reset role;
do $$ begin raise notice 'Day One tests passed'; end $$;
rollback;
