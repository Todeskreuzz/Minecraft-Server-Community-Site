-- Disposable CI database only. Confirms permanent UIDs, profile edits, and media checks.
begin;
insert into auth.users(id,email,raw_user_meta_data,created_at) values
 ('00000000-0000-4000-8000-00000000f001','profile-owner@example.invalid','{"display_name":"Profile Owner"}','2024-02-02'),
 ('00000000-0000-4000-8000-00000000f002','profile-second@example.invalid','{"display_name":"Second Player"}','2024-03-03'),
 ('00000000-0000-4000-8000-00000000f003','profile-early@example.invalid','{"display_name":"Early Player"}','2020-01-01');
insert into private.forum_admins values('00000000-0000-4000-8000-00000000f001');
update public.forum_profiles set created_at='2024-02-02' where id='00000000-0000-4000-8000-00000000f001';
update public.forum_profiles set created_at='2024-03-03' where id='00000000-0000-4000-8000-00000000f002';
update public.forum_profiles set created_at='2020-01-01' where id='00000000-0000-4000-8000-00000000f003';

do $$ declare first_uid bigint; second_uid bigint; third_uid bigint; reused bigint; begin
 select uid into first_uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000f001';
 select uid into second_uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000f002';
 if second_uid <> first_uid + 1 then raise exception 'UID sequence skipped a registration'; end if;
 delete from auth.users where id='00000000-0000-4000-8000-00000000f002';
 insert into auth.users(id,email,raw_user_meta_data) values
  ('00000000-0000-4000-8000-00000000f004','profile-third@example.invalid','{"display_name":"Third Player"}');
 select uid into third_uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000f004';
 if third_uid <= second_uid then raise exception 'Deleted UID was reused'; end if;
 alter table public.forum_profiles disable trigger forum_profile_guard;
 alter table public.forum_profiles alter column uid drop not null;
 update public.forum_profiles set uid=null where id in ('00000000-0000-4000-8000-00000000f001','00000000-0000-4000-8000-00000000f003','00000000-0000-4000-8000-00000000f004');
 perform private.assign_missing_uids();
 if (select uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000f003')
  >= (select uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000f001') then
  raise exception 'Backfill ignored registration order';
 end if;
 select uid into reused from public.forum_profiles where id='00000000-0000-4000-8000-00000000f003';
 perform private.assign_missing_uids();
 if (select uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000f003') <> reused then raise exception 'Backfill changed an existing UID'; end if;
 alter table public.forum_profiles alter column uid set not null;
 alter table public.forum_profiles enable trigger forum_profile_guard;
 begin
  update public.forum_profiles set uid=uid+50 where id='00000000-0000-4000-8000-00000000f001';
  raise exception 'UID changed';
 exception when others then if sqlerrm not like '%UID is permanent%' then raise; end if; end;
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='forum_profile_cards' and 'security_invoker=true'=any(c.reloptions)) then
  raise exception 'Profile cards bypass invoker';
 end if;
end $$;

set local role anon;
do $$ begin
 perform 1 from public.forum_profile_cards;
 begin perform public.forum_set_media('avatar','\x524946460000000057454250'::bytea); raise exception 'Anon set media'; exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000f001',true);
set local role authenticated;
do $$ declare affected int; begin
 update public.forum_profiles set display_name='Tim', bio='Hallo' where id='00000000-0000-4000-8000-00000000f001';
 if (select display_name from public.forum_profiles where id='00000000-0000-4000-8000-00000000f001') <> 'Owner' then raise exception 'Owner public name changed'; end if;
 if (select bio from public.forum_profiles where id='00000000-0000-4000-8000-00000000f001') <> 'Hallo' then raise exception 'Owner bio was not saved'; end if;
 update public.forum_profiles set bio='Fremd' where id='00000000-0000-4000-8000-00000000f003';
 get diagnostics affected = row_count;
 if affected <> 0 then raise exception 'Member edited another profile'; end if;
 begin update public.forum_profiles set avatar_path=id::text||'/avatar.webp' where id='00000000-0000-4000-8000-00000000f001'; raise exception 'Direct media path update'; exception when insufficient_privilege then null; end;
 begin perform public.forum_set_media('avatar','\xffd8ff000000000000000000'::bytea); raise exception 'JPEG header accepted'; exception when raise_exception then if sqlerrm <> 'Invalid image' then raise; end if; end;
 begin perform public.forum_set_media('avatar','\x524946460000000057454250'::bytea); raise exception 'Missing object accepted'; exception when raise_exception then if sqlerrm <> 'Image missing' then raise; end if; end;
end $$;
reset role;

insert into storage.objects(bucket_id,name,metadata) values
 ('profile-media','00000000-0000-4000-8000-00000000f001/avatar.webp','{"size":1200,"mimetype":"image/webp"}');
do $$ begin
 begin
  insert into storage.objects(bucket_id,name,metadata) values ('profile-media','not-a-path.webp','{"size":10}');
  raise exception 'Bad media path accepted';
 exception when others then if sqlerrm not like '%Invalid media path%' then raise; end if; end;
 begin
  insert into storage.objects(bucket_id,name,metadata) values ('profile-media','00000000-0000-4000-8000-00000000f001/banner.webp','{"size":300000}');
  raise exception 'Oversized image accepted';
 exception when others then if sqlerrm not like '%too large%' then raise; end if; end;
end $$;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000f001',true);
set local role authenticated;
select public.forum_set_media('avatar','\x524946460000000057454250'::bytea);
do $$ begin
 if (select avatar_path from public.forum_profiles where id='00000000-0000-4000-8000-00000000f001') <> '00000000-0000-4000-8000-00000000f001/avatar.webp' then raise exception 'Avatar path was not stored'; end if;
 if (select avatar_preset from public.forum_profiles where id='00000000-0000-4000-8000-00000000f001') <> '' then raise exception 'Upload left a preset active'; end if;
 perform public.forum_clear_media('avatar');
 if (select avatar_path from public.forum_profiles where id='00000000-0000-4000-8000-00000000f001') is not null then raise exception 'Avatar path stayed after clear'; end if;
 update public.forum_profiles set avatar_preset='grove' where id='00000000-0000-4000-8000-00000000f001';
 if (select thread_count from public.forum_profile_cards where id='00000000-0000-4000-8000-00000000f001') <> 0 then raise exception 'Empty profile reported threads'; end if;
end $$;
reset role;

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-00000000f003","is_anonymous":true}',true);
set local role authenticated;
do $$ begin
 begin perform public.forum_clear_media('avatar'); raise exception 'Anonymous media clear'; exception when raise_exception then if sqlerrm <> 'Not authorized' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claims','{}',true);
do $$ begin raise notice 'Profile tests passed'; end $$;
rollback;
