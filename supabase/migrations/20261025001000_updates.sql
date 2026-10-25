-- Manual modpack updates, news posts and a storage report. Safe to reapply.
begin;
create table if not exists public.news_posts (
 id uuid primary key default gen_random_uuid(),
 title_de text not null check (char_length(trim(title_de)) between 2 and 120),
 title_en text not null check (char_length(trim(title_en)) between 2 and 120),
 body_de text not null default '' check (char_length(body_de) <= 8000),
 body_en text not null default '' check (char_length(body_en) <= 8000),
 kind text not null check (kind in ('small','large')),
 starts_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists public.modpack_updates (
 id uuid primary key default gen_random_uuid(),
 version text not null check (char_length(trim(version)) between 1 and 32),
 title_de text not null,
 title_en text not null,
 kind text not null check (kind in ('small','large')),
 changelog_de text not null default '',
 changelog_en text not null default '',
 rollout text not null check (rollout in ('now','delay','scheduled')),
 scheduled_at timestamptz,
 mods jsonb not null default '[]'::jsonb,
 jars jsonb not null default '[]'::jsonb,
 news_id uuid references public.news_posts(id) on delete set null,
 queued_at timestamptz,
 created_at timestamptz not null default now()
);
alter table public.modpack_updates add column if not exists mods jsonb not null default '[]'::jsonb;
alter table public.modpack_updates add column if not exists jars jsonb not null default '[]'::jsonb;
alter table public.modpack_updates add column if not exists queued_at timestamptz;
create table if not exists public.server_bridge_status (
 id int primary key default 1 check (id = 1),
 players int not null default 0 check (players >= 0 and players <= 500),
 reported_at timestamptz not null default now()
);
alter table public.news_posts enable row level security;
alter table public.modpack_updates enable row level security;
alter table public.server_bridge_status enable row level security;
revoke all on public.news_posts, public.modpack_updates, public.server_bridge_status from anon, authenticated;
grant select on public.news_posts, public.modpack_updates, public.server_bridge_status to anon, authenticated;
drop policy if exists news_read on public.news_posts;
create policy news_read on public.news_posts for select using (true);
drop policy if exists updates_read on public.modpack_updates;
create policy updates_read on public.modpack_updates for select using (true);
drop policy if exists bridge_status_read on public.server_bridge_status;
create policy bridge_status_read on public.server_bridge_status for select using (true);

do $$
declare constraint_name text;
begin
 for constraint_name in
  select con.conname from pg_constraint con
  join pg_class rel on rel.oid = con.conrelid
  join pg_namespace nsp on nsp.oid = rel.relnamespace
  where nsp.nspname = 'public' and rel.relname = 'mc_sync_queue' and con.contype = 'c' and pg_get_constraintdef(con.oid) ilike '%kind%'
 loop
  execute format('alter table public.mc_sync_queue drop constraint %I', constraint_name);
 end loop;
end $$;
alter table public.mc_sync_queue add constraint mc_sync_queue_kind_check check (kind in ('create_group','add_member','remove_member','delete_group','warn','download','stop'));

create or replace function private.queue_update(p_update uuid, p_choice text, p_starts timestamptz, p_jars jsonb) returns void language plpgsql security definer set search_path='' as $$
declare moment timestamptz;
begin
 if exists(select 1 from public.mc_sync_queue where done_at is null and payload->>'update_id' = p_update::text) then return; end if;
 if p_choice = 'delay' then return; end if;
 moment := case when p_choice = 'scheduled' then p_starts else now() end;
 if p_choice = 'scheduled' and moment - interval '15 minutes' > now() then
  insert into public.mc_sync_queue(kind, payload) values
   ('warn', jsonb_build_object('update_id', p_update, 'due_at', moment - interval '15 minutes', 'message', 'Neustart in 15 Minuten.')),
   ('warn', jsonb_build_object('update_id', p_update, 'due_at', moment - interval '5 minutes', 'message', 'Neustart in 5 Minuten.')),
   ('warn', jsonb_build_object('update_id', p_update, 'due_at', moment - interval '1 minute', 'message', 'Neustart in 1 Minute.'));
 elsif p_choice = 'scheduled' and moment - interval '5 minutes' > now() then
  insert into public.mc_sync_queue(kind, payload) values
   ('warn', jsonb_build_object('update_id', p_update, 'due_at', moment - interval '5 minutes', 'message', 'Neustart in 5 Minuten.')),
   ('warn', jsonb_build_object('update_id', p_update, 'due_at', moment - interval '1 minute', 'message', 'Neustart in 1 Minute.'));
 elsif p_choice = 'scheduled' and moment - interval '1 minute' > now() then
  insert into public.mc_sync_queue(kind, payload) values
   ('warn', jsonb_build_object('update_id', p_update, 'due_at', moment - interval '1 minute', 'message', 'Neustart in 1 Minute.'));
 end if;
 insert into public.mc_sync_queue(kind, payload) values
  ('download', jsonb_build_object('update_id', p_update, 'due_at', case when p_choice = 'scheduled' then moment - interval '2 minutes' else now() end, 'jars', coalesce(p_jars, '[]'::jsonb))),
  ('stop', jsonb_build_object('update_id', p_update, 'due_at', moment, 'message', 'Der Server startet neu.'));
 update public.modpack_updates set queued_at = now() where id = p_update and queued_at is null;
end; $$;
revoke all on function private.queue_update(uuid, text, timestamptz, jsonb) from public, anon, authenticated;

create or replace function public.forum_publish_update(
 p_version text, p_title_de text, p_title_en text, p_kind text, p_body_de text, p_body_en text, p_rollout text, p_starts timestamptz, p_mods jsonb default '[]'::jsonb, p_jars jsonb default '[]'::jsonb
) returns uuid language plpgsql security definer set search_path='' as $$
declare posted uuid; update_id uuid; choice text := p_rollout; mod_row jsonb; jar_row jsonb; jar_host text; clean_mods jsonb := '[]'::jsonb; clean_jars jsonb := '[]'::jsonb;
begin
 if not public.forum_is_admin() then raise exception 'Not authorized'; end if;
 if p_kind not in ('small','large') then raise exception 'Invalid update'; end if;
 if choice not in ('now','delay','scheduled') then raise exception 'Invalid update'; end if;
 if p_kind = 'large' and choice = 'now' then choice := 'scheduled'; end if;
 if choice = 'scheduled' and p_starts is null then raise exception 'Missing time'; end if;
 if p_mods is null or jsonb_typeof(p_mods) <> 'array' or jsonb_array_length(p_mods) > 80 then raise exception 'Invalid update'; end if;
 if p_jars is null or jsonb_typeof(p_jars) <> 'array' or jsonb_array_length(p_jars) > 40 then raise exception 'Invalid update'; end if;
 for mod_row in select value from jsonb_array_elements(p_mods) loop
  if mod_row->>'action' not in ('added','removed','updated') then raise exception 'Invalid update'; end if;
  if char_length(trim(coalesce(mod_row->>'name',''))) not between 1 and 64 then raise exception 'Invalid update'; end if;
  if char_length(coalesce(mod_row->>'version','')) > 32 then raise exception 'Invalid update'; end if;
  clean_mods := clean_mods || jsonb_build_array(jsonb_build_object('action', mod_row->>'action', 'name', trim(mod_row->>'name'), 'version', coalesce(mod_row->>'version','')));
 end loop;
 for jar_row in select value from jsonb_array_elements(p_jars) loop
  jar_host := split_part(regexp_replace(coalesce(jar_row->>'url',''), '^https://', ''), '/', 1);
  if jar_host not in ('cdn.modrinth.com','github.com','objects.githubusercontent.com','mediafilez.forgecdn.net','edge.forgecdn.net','media.forgecdn.net') then raise exception 'Invalid update'; end if;
  if coalesce(jar_row->>'url','') !~ '^https://' or char_length(jar_row->>'url') > 400 then raise exception 'Invalid update'; end if;
  if lower(coalesce(jar_row->>'sha256','')) !~ '^[a-f0-9]{64}$' then raise exception 'Invalid update'; end if;
  if coalesce(jar_row->>'file','') !~ '^[A-Za-z0-9._-]{1,64}\.jar$' then raise exception 'Invalid update'; end if;
  clean_jars := clean_jars || jsonb_build_array(jsonb_build_object('url', jar_row->>'url', 'sha256', lower(jar_row->>'sha256'), 'file', jar_row->>'file'));
 end loop;
 insert into public.news_posts(title_de, title_en, body_de, body_en, kind, starts_at)
 values(trim(p_title_de), trim(p_title_en), coalesce(p_body_de,''), coalesce(p_body_en,''), p_kind, case when choice = 'scheduled' then p_starts else null end)
 returning id into posted;
 insert into public.modpack_updates(version, title_de, title_en, kind, changelog_de, changelog_en, rollout, scheduled_at, mods, jars, news_id)
 values(trim(p_version), trim(p_title_de), trim(p_title_en), p_kind, coalesce(p_body_de,''), coalesce(p_body_en,''), choice, case when choice = 'scheduled' then p_starts else null end, clean_mods, clean_jars, posted)
 returning id into update_id;
 perform private.queue_update(update_id, choice, p_starts, clean_jars);
 return posted;
end; $$;

create or replace function public.forum_edit_news(p_id uuid, p_title_de text, p_title_en text, p_body_de text, p_body_en text) returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.forum_is_admin() then raise exception 'Not authorized'; end if;
 if char_length(trim(coalesce(p_title_de,''))) not between 2 and 120 or char_length(trim(coalesce(p_title_en,''))) not between 2 and 120 then raise exception 'Invalid update'; end if;
 if char_length(coalesce(p_body_de,'')) > 8000 or char_length(coalesce(p_body_en,'')) > 8000 then raise exception 'Invalid update'; end if;
 update public.news_posts set title_de = trim(p_title_de), title_en = trim(p_title_en), body_de = coalesce(p_body_de,''), body_en = coalesce(p_body_en,'') where id = p_id;
 if not found then raise exception 'Invalid update'; end if;
end; $$;

create or replace function public.forum_storage_report() returns jsonb language plpgsql stable security definer set search_path='' as $$
declare db_bytes bigint; file_bytes bigint; online_players int := 0;
begin
 if not public.forum_is_admin() then raise exception 'Not authorized'; end if;
 select pg_database_size(current_database()) into db_bytes;
 select coalesce(sum(coalesce((metadata->>'size')::bigint, 0)), 0) into file_bytes from storage.objects;
 select coalesce(players, 0) into online_players from public.server_bridge_status where id = 1;
 return jsonb_build_object('database_bytes', db_bytes, 'storage_bytes', file_bytes, 'database_limit', 524288000, 'storage_limit', 1073741824, 'players', online_players, 'egress_limit', 5368709120, 'upload_limit', 52428800, 'realtime_limit', 200);
end; $$;

create or replace function public.bridge_report(p_secret text, p_players int) returns void language plpgsql security definer set search_path='' as $$
declare waiting record;
begin
 perform private.assert_bridge(p_secret);
 if p_players is null or p_players < 0 or p_players > 500 then raise exception 'Invalid update'; end if;
 insert into public.server_bridge_status(id, players, reported_at) values(1, p_players, now())
 on conflict (id) do update set players = excluded.players, reported_at = excluded.reported_at;
 if p_players = 0 then
  for waiting in select id, jars from public.modpack_updates where rollout = 'delay' and queued_at is null loop
   perform private.queue_update(waiting.id, 'now', now(), waiting.jars);
  end loop;
 end if;
end; $$;

create or replace function public.bridge_claim(p_secret text) returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.assert_bridge(p_secret);
 select coalesce(jsonb_agg(jsonb_build_object('id', q.id, 'kind', q.kind, 'payload', q.payload) order by q.created_at), '[]'::jsonb)
 into result from (
  select id, kind, payload, created_at from public.mc_sync_queue
  where done_at is null
  and (
   kind in ('create_group','add_member','remove_member','delete_group')
   or nullif(payload->>'due_at','') is null
   or (payload->>'due_at')::timestamptz <= now()
  )
  order by created_at
  limit 20
 ) q;
 return result;
end; $$;

revoke all on function public.forum_publish_update(text, text, text, text, text, text, text, timestamptz, jsonb, jsonb), public.forum_edit_news(uuid, text, text, text, text), public.forum_storage_report(), public.bridge_report(text, int) from public, anon, authenticated;
grant execute on function public.forum_publish_update(text, text, text, text, text, text, text, timestamptz, jsonb, jsonb), public.forum_edit_news(uuid, text, text, text, text), public.forum_storage_report() to authenticated;
grant execute on function public.bridge_report(text, int), public.bridge_claim(text) to anon, authenticated;
commit;
