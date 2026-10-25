-- Disposable CI database only. Community server list visibility and banners.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000c101','server-owner@example.invalid','{"display_name":"Server Owner"}'),
 ('00000000-0000-4000-8000-00000000c102','server-other@example.invalid','{"display_name":"Server Other"}'),
 ('00000000-0000-4000-8000-00000000c103','server-admin@example.invalid','{"display_name":"Server Admin"}');
insert into private.forum_admins(user_id) values ('00000000-0000-4000-8000-00000000c103');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000c101',true);
set local role authenticated;
do $$ declare sid uuid; begin
 begin
  insert into public.community_servers(name, address) values ('Bad','localhost');
  raise exception 'Bare host stored';
 exception when raise_exception then if sqlerrm <> 'Invalid address' then raise; end if; end;
 begin
  insert into public.community_servers(name, address, tags) values ('Bad','play.example.com', array['Nope Tag']);
  raise exception 'Bad tag stored';
 exception when raise_exception then if sqlerrm <> 'Invalid tags' then raise; end if; end;
 insert into public.community_servers(name, address, port, game_version, description, tags, is_public)
  values ('Lagerfeuer','Play.Example.com',25566,'1.20.1','Ein Modpack', array['Forge','Survival'], true);
 insert into public.community_servers(name, address, is_public) values ('Geheim','secret.example.com', false);
 select id into sid from public.community_servers where address = 'play.example.com';
 if sid is null then raise exception 'Public server missing'; end if;
 if (select port from public.community_servers where id = sid) <> 25566 then raise exception 'Port was not stored'; end if;
 if not ((select tags from public.community_servers where id = sid) @> array['forge','survival']) then raise exception 'Tags were not normalized'; end if;
 perform set_config('faf.server_id', sid::text, true);
end $$;
reset role;

select set_config('request.jwt.claim.sub','',true);
set local role anon;
do $$ begin
 if (select count(*) from public.community_servers) <> 1 then raise exception 'Anon saw a private server'; end if;
 if (select address from public.community_servers) <> 'play.example.com' then raise exception 'Anon missed the public server'; end if;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000c102',true);
set local role authenticated;
do $$ declare affected int; begin
 if (select count(*) from public.community_servers where is_public = false) <> 0 then raise exception 'Other member saw a private server'; end if;
 begin
  update public.community_servers set name = 'Übernommen' where address = 'play.example.com';
  get diagnostics affected = row_count;
  if affected <> 0 then raise exception 'Other member edited the server'; end if;
 exception when insufficient_privilege then null; end;
 begin
  insert into public.community_servers(name, address, owner_id) values ('Fremd','other.example.com','00000000-0000-4000-8000-00000000c101');
  raise exception 'Owner column was writable';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000c101',true);
set local role authenticated;
insert into storage.objects(bucket_id, name, metadata)
 values ('community-banners','00000000-0000-4000-8000-00000000c101/' || current_setting('faf.server_id') || '.webp','{"size":2048,"mimetype":"image/webp"}');
update public.community_servers set banner_path = owner_id::text || '/' || id::text || '.webp' where id = current_setting('faf.server_id')::uuid;
do $$ begin
 if (select banner_path from public.community_servers where id = current_setting('faf.server_id')::uuid) not like '%/' || current_setting('faf.server_id') || '.webp' then raise exception 'Banner path was not stored'; end if;
 begin
  insert into storage.objects(bucket_id, name, metadata) values ('community-banners','00000000-0000-4000-8000-00000000c102/00000000-0000-4000-8000-00000000c999.webp','{"size":10}');
  raise exception 'Foreign banner stored';
 exception when others then if sqlerrm not like '%Invalid%' and sqlerrm not like '%permission denied%' and sqlerrm not like '%row-level security%' then raise; end if; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000c103',true);
set local role authenticated;
delete from public.community_servers where address = 'secret.example.com';
do $$ begin
 if exists(select 1 from public.community_servers where address = 'secret.example.com') then raise exception 'Admin could not remove a private server'; end if;
 raise notice 'Server list tests passed';
end $$;
reset role;
rollback;
