-- Images and short videos on topics and replies. Safe to reapply.
begin;
create table if not exists public.forum_media (
 id uuid primary key default gen_random_uuid(),
 author_id uuid not null references public.forum_profiles(id) on delete cascade,
 topic_id uuid references public.forum_topics(id) on delete cascade,
 reply_id uuid references public.forum_replies(id) on delete cascade,
 path text not null,
 kind text not null check (kind in ('image','video')),
 bytes integer not null check (bytes > 0 and bytes <= 10485760),
 created_at timestamptz not null default now(),
 check ((topic_id is null) <> (reply_id is null)),
 check (path ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(webp|webm|mp4)$')
);
create index if not exists forum_media_topic on public.forum_media(topic_id);
create index if not exists forum_media_reply on public.forum_media(reply_id);
alter table public.forum_media enable row level security;
revoke all on public.forum_media from anon, authenticated;
grant select on public.forum_media to anon, authenticated;
drop policy if exists forum_media_read on public.forum_media;
create policy forum_media_read on public.forum_media for select using (true);

insert into storage.buckets (id, name, "public", file_size_limit, allowed_mime_types)
 values ('thread-media', 'thread-media', true, 10485760, array['image/webp','video/webm','video/mp4'])
 on conflict (id) do update set "public" = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.thread_media_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare incoming bigint; object_kind text; used bigint;
begin
 if new.bucket_id is distinct from 'thread-media' then return new; end if;
 if coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if new.name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(webp|webm|mp4)$' then raise exception 'Invalid media path'; end if;
 if auth.uid() is not null and auth.uid()::text is distinct from split_part(new.name, '/', 1) then raise exception 'Invalid folder'; end if;
 if auth.uid() is null and current_user not in ('postgres', 'supabase_admin') then raise exception 'Invalid folder'; end if;
 incoming := coalesce((new.metadata->>'size')::bigint, (new.metadata->>'contentLength')::bigint, 0);
 object_kind := case when new.name ~ '\.webp$' then 'image' else 'video' end;
 if object_kind = 'image' and (incoming <= 0 or incoming > 262144) then raise exception 'Image is too large'; end if;
 if object_kind = 'video' and (incoming <= 0 or incoming > 8388608) then raise exception 'Video is too large'; end if;
 if object_kind = 'video' then
  select coalesce(sum(coalesce((metadata->>'size')::bigint, 0)), 0) into used
  from storage.objects where bucket_id = 'thread-media' and name ~ '\.(webm|mp4)$' and name is distinct from new.name;
  if used + incoming > 838860800 then raise exception 'Video uploads are paused'; end if;
  select coalesce(sum(bytes), 0) into used from public.forum_media where author_id = split_part(new.name, '/', 1)::uuid and kind = 'video';
  if used + incoming > 26214400 then raise exception 'Video quota exceeded'; end if;
  if (select count(*) from public.forum_media where author_id = split_part(new.name, '/', 1)::uuid and kind = 'video') >= 3 then raise exception 'Video quota exceeded'; end if;
 end if;
 return new;
end; $$;
revoke all on function private.thread_media_guard() from public, anon, authenticated;
drop trigger if exists thread_media_guard on storage.objects;
create trigger thread_media_guard before insert or update of name, metadata, bucket_id on storage.objects for each row execute function private.thread_media_guard();

drop policy if exists thread_media_read on storage.objects;
create policy thread_media_read on storage.objects for select to anon, authenticated using (bucket_id = 'thread-media');
drop policy if exists thread_media_insert on storage.objects;
create policy thread_media_insert on storage.objects for insert to authenticated with check (
 bucket_id = 'thread-media'
 and coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'false'
 and split_part(name, '/', 1) = (select auth.uid())::text
 and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(webp|webm|mp4)$'
);
drop policy if exists thread_media_delete on storage.objects;
create policy thread_media_delete on storage.objects for delete to authenticated
 using (bucket_id = 'thread-media' and split_part(name, '/', 1) = (select auth.uid())::text);

create or replace function public.forum_attach_media(p_topic uuid, p_reply uuid, p_path text, p_header bytea) returns uuid language plpgsql security definer set search_path='' as $$
declare
 linked uuid;
 media_kind text;
 stored bigint;
 post_author uuid;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if (p_topic is null) = (p_reply is null) then raise exception 'Invalid post'; end if;
 if p_path !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.(webp|webm|mp4)$' or split_part(p_path, '/', 1) is distinct from auth.uid()::text then raise exception 'Invalid media path'; end if;
 if p_topic is not null then select author_id into post_author from public.forum_topics where id = p_topic;
 else select author_id into post_author from public.forum_replies where id = p_reply; end if;
 if post_author is distinct from auth.uid() then raise exception 'Not authorized'; end if;
 if octet_length(p_header) >= 12 and substring(p_header from 1 for 4) = '\x52494646'::bytea and substring(p_header from 9 for 4) = '\x57454250'::bytea and p_path ~ '\.webp$' then media_kind := 'image';
 elsif octet_length(p_header) >= 4 and substring(p_header from 1 for 4) = '\x1a45dfa3'::bytea and p_path ~ '\.webm$' then media_kind := 'video';
 elsif octet_length(p_header) >= 8 and substring(p_header from 5 for 4) = '\x66747970'::bytea and p_path ~ '\.mp4$' then media_kind := 'video';
 else raise exception 'Invalid image'; end if;
 select coalesce((metadata->>'size')::bigint, 0) into stored from storage.objects where bucket_id = 'thread-media' and name = p_path;
 if media_kind = 'image' and (stored <= 0 or stored > 262144) then raise exception 'Image is too large'; end if;
 if media_kind = 'video' and (stored <= 0 or stored > 8388608) then raise exception 'Video is too large'; end if;
 if media_kind = 'video' and (select count(*) from public.forum_media where author_id = auth.uid() and forum_media.kind = 'video') >= 3 then raise exception 'Video quota exceeded'; end if;
 insert into public.forum_media(author_id, topic_id, reply_id, path, kind, bytes)
 values(auth.uid(), p_topic, p_reply, p_path, media_kind, stored) returning id into linked;
 return linked;
end; $$;
revoke all on function public.forum_attach_media(uuid, uuid, text, bytea) from public, anon, authenticated;
grant execute on function public.forum_attach_media(uuid, uuid, text, bytea) to authenticated;
commit;
