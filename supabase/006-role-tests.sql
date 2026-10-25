-- Disposable CI database only. Owner stays fixed; moderators can pin.
begin;
insert into auth.users(id,email,raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000b001','role-owner@example.invalid','{"display_name":"Role Owner"}'),
 ('00000000-0000-4000-8000-00000000b002','role-admin@example.invalid','{"display_name":"Role Admin"}'),
 ('00000000-0000-4000-8000-00000000b003','role-mod@example.invalid','{"display_name":"Role Mod"}'),
 ('00000000-0000-4000-8000-00000000b004','role-member@example.invalid','{"display_name":"Role Member"}');
insert into private.forum_admins values
 ('00000000-0000-4000-8000-00000000b001'),
 ('00000000-0000-4000-8000-00000000b002');
select private.sync_owner_role();

do $$ begin
 if (select role from public.forum_roles where user_id='00000000-0000-4000-8000-00000000b001') <> 'owner' then raise exception 'Earliest owner was not kept'; end if;
 if (select role from public.forum_roles where user_id='00000000-0000-4000-8000-00000000b002') <> 'admin' then raise exception 'Later admin was not ranked'; end if;
 if (select uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000b001')
  > (select uid from public.forum_profiles where id='00000000-0000-4000-8000-00000000b002') then raise exception 'UID order was unexpected'; end if;
end $$;

set local role anon;
do $$ begin
 perform 1 from public.forum_roles;
 begin perform public.forum_set_role('00000000-0000-4000-8000-00000000b003','moderator'); raise exception 'Anon assigned a role'; exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000b002',true);
set local role authenticated;
do $$ begin
 begin perform public.forum_set_role('00000000-0000-4000-8000-00000000b001','member'); raise exception 'Owner rank changed'; exception when raise_exception then if sqlerrm <> 'Owner is fixed' then raise; end if; end;
 begin perform public.forum_set_role('00000000-0000-4000-8000-00000000b003','owner'); raise exception 'Second owner created'; exception when raise_exception then if sqlerrm <> 'Owner is fixed' then raise; end if; end;
 perform public.forum_set_role('00000000-0000-4000-8000-00000000b003','moderator');
 if (select role from public.forum_roles where user_id='00000000-0000-4000-8000-00000000b003') <> 'moderator' then raise exception 'Moderator was not assigned'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000b003',true);
set local role authenticated;
do $$ declare topic uuid; affected int; begin
 begin perform public.forum_set_role('00000000-0000-4000-8000-00000000b004','dayone'); raise exception 'Moderator assigned a role'; exception when raise_exception then if sqlerrm <> 'Not authorized' then raise; end if; end;
 insert into public.forum_topics(title,body,category_id) values('Role topic','Moderator can pin','general') returning id into topic;
 update public.forum_topics set pinned=true where id=topic; get diagnostics affected=row_count;
 if affected <> 1 then raise exception 'Moderator cannot pin'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000b004',true);
set local role authenticated;
do $$ declare affected int; begin
 update public.forum_topics set pinned=false where title='Role topic'; get diagnostics affected=row_count;
 if affected <> 0 then raise exception 'Member can pin'; end if;
end $$;
reset role;
do $$ begin raise notice 'Role tests passed'; end $$;
rollback;
