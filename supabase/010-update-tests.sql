-- Disposable CI database only.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000aa01','update-admin@example.invalid','{"display_name":"Update Admin"}'),
 ('00000000-0000-4000-8000-00000000aa02','update-member@example.invalid','{"display_name":"Update Member"}');
insert into private.forum_admins values('00000000-0000-4000-8000-00000000aa01');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000aa02',true);
set local role authenticated;
do $$ begin
 begin perform public.forum_publish_update('1.0.1','Kleines Update','Small update','small','Text','Text','now',null); raise exception 'Member published an update';
 exception when raise_exception then if sqlerrm <> 'Not authorized' then raise; end if; end;
 begin perform public.forum_storage_report(); raise exception 'Member read storage'; exception when raise_exception then if sqlerrm <> 'Not authorized' then raise; end if; end;
 begin perform public.forum_edit_news('00000000-0000-4000-8000-00000000aa03','Titel','Title','Text','Text'); raise exception 'Member edited news';
 exception when raise_exception then if sqlerrm <> 'Not authorized' then raise; end if; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000aa01',true);
set local role authenticated;
select set_config('faf.news_id', public.forum_publish_update('1.2.0','Großes Update','Large update','large','Mods','Mods','now', now() + interval '2 hours', '[{"action":"added","name":"Example","version":"1"}]'::jsonb, '[{"url":"https://cdn.modrinth.com/data/example/versions/example.jar","sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","file":"example.jar"}]'::jsonb)::text, true);
do $$ begin
 begin perform public.forum_publish_update('9.9.9','Schlecht','Bad','small','x','x','now',null,'[]'::jsonb,'[{"url":"https://evil.example/a.jar","sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","file":"a.jar"}]'::jsonb);
 raise exception 'Bad jar accepted'; exception when raise_exception then if sqlerrm <> 'Invalid update' then raise; end if; end;
 perform public.forum_publish_update('1.3.0','Später','Later','small','Warten','Wait','delay',null);
 perform public.forum_edit_news(current_setting('faf.news_id')::uuid, 'Geändert', 'Changed', 'Mods', 'Mods');
 if (select rollout from public.modpack_updates where version='1.2.0') <> 'scheduled' then raise exception 'Large update was forced now'; end if;
 if (select title_de from public.news_posts where id=current_setting('faf.news_id')::uuid) <> 'Geändert' then raise exception 'News edit missed'; end if;
 if (select mods->0->>'name' from public.modpack_updates where version='1.2.0') <> 'Example' then raise exception 'Mod list missing'; end if;
 if (public.forum_storage_report()->>'database_bytes')::bigint <= 0 then raise exception 'Database size missing'; end if;
end $$;
reset role;
do $$ begin
 if (select count(*) from public.mc_sync_queue where kind='warn' and payload->>'update_id'=(select id::text from public.modpack_updates where version='1.2.0')) <> 3 then raise exception 'Warnings missing'; end if;
 if (select count(*) from public.mc_sync_queue where kind='stop' and payload->>'update_id'=(select id::text from public.modpack_updates where version='1.2.0')) <> 1 then raise exception 'Stop missing'; end if;
 if (select queued_at from public.modpack_updates where version='1.3.0') is not null then raise exception 'Delayed update queued too early'; end if;
end $$;
select private.set_bridge_secret('ci-bridge-secret-0123456789');
select public.bridge_report('ci-bridge-secret-0123456789', 4);
do $$ begin
 if (select queued_at from public.modpack_updates where version='1.3.0') is not null then raise exception 'Players online released a delayed update'; end if;
 if jsonb_array_length(public.bridge_claim('ci-bridge-secret-0123456789')) <> 0 then raise exception 'Future restart was claimed'; end if;
end $$;
select public.bridge_report('ci-bridge-secret-0123456789', 0);
do $$ begin
 if (select count(*) from public.mc_sync_queue where kind='stop' and payload->>'update_id'=(select id::text from public.modpack_updates where version='1.3.0') and done_at is null) <> 1 then raise exception 'Empty server did not queue the restart'; end if;
 if (select count(*) from jsonb_array_elements(public.bridge_claim('ci-bridge-secret-0123456789')) elem where elem->>'kind'='stop') <> 1 then raise exception 'Due restart was not claimed'; end if;
end $$;
do $$ begin raise notice 'Update tests passed'; end $$;
rollback;
