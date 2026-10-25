-- Disposable CI database only.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000a0a1','media-author@example.invalid','{"display_name":"Media Author"}'),
 ('00000000-0000-4000-8000-00000000a0a2','media-other@example.invalid','{"display_name":"Media Other"}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000a0a1',true);
set local role authenticated;
do $$ declare topic uuid; begin
 insert into public.forum_topics(title, body, category_id) values
  ('Media topic','A picture and https://youtu.be/dQw4w9wg','general') returning id into topic;
 perform set_config('faf.media_topic', topic::text, true);
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
insert into storage.objects(bucket_id, name, metadata) values
 ('thread-media','00000000-0000-4000-8000-00000000a0a1/00000000-0000-4000-8000-00000000a0c1.webp','{"size":2048,"mimetype":"image/webp"}');
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000a0a2',true);
set local role authenticated;
do $$ begin
 begin perform public.forum_attach_media(current_setting('faf.media_topic')::uuid, null, '00000000-0000-4000-8000-00000000a0a1/00000000-0000-4000-8000-00000000a0c1.webp', '\x524946460000000057454250'::bytea);
 raise exception 'Stranger attached media';
 exception when raise_exception then if sqlerrm <> 'Not authorized' and sqlerrm <> 'Invalid media path' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000a0a1',true);
set local role authenticated;
select public.forum_attach_media(current_setting('faf.media_topic')::uuid, null, '00000000-0000-4000-8000-00000000a0a1/00000000-0000-4000-8000-00000000a0c1.webp', '\x524946460000000057454250'::bytea);
do $$ begin
 if (select kind from public.forum_media where topic_id=current_setting('faf.media_topic')::uuid) <> 'image' then raise exception 'Image was not attached'; end if;
 begin perform public.forum_attach_media(current_setting('faf.media_topic')::uuid, null, '00000000-0000-4000-8000-00000000a0a1/00000000-0000-4000-8000-00000000a0c1.webp', '\xffd8ff000000000000000000'::bytea);
 raise exception 'JPEG attached';
 exception when raise_exception then if sqlerrm <> 'Invalid image' then raise; end if; end;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',true);
do $$ begin
 begin
  insert into storage.objects(bucket_id, name, metadata) values ('thread-media','00000000-0000-4000-8000-00000000a0a1/00000000-0000-4000-8000-00000000a0c2.webp','{"size":400000}');
  raise exception 'Oversized thread image stored';
 exception when others then if sqlerrm not like '%too large%' then raise; end if; end;
end $$;
do $$ begin raise notice 'Media tests passed'; end $$;
rollback;
