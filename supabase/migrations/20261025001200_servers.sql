-- Community Minecraft server list. Safe to reapply. Does not remove existing rows.
begin;

create table if not exists public.community_servers (
 id uuid primary key default gen_random_uuid(),
 owner_id uuid not null default auth.uid() references public.forum_profiles(id) on delete cascade,
 name text not null,
 address text not null,
 port integer not null default 25565,
 game_version text not null default '',
 description text not null default '',
 tags text[] not null default '{}',
 is_public boolean not null default true,
 banner_path text,
 created_at timestamptz not null default now()
);

create or replace function private.community_server_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare cleaned text[];
begin
 if coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if auth.uid() is not null and new.owner_id is distinct from auth.uid() and not public.forum_is_admin() then raise exception 'Not authorized'; end if;
 if auth.uid() is null and current_user not in ('postgres', 'supabase_admin') then raise exception 'Not authorized'; end if;
 new.name := trim(new.name);
 if char_length(new.name) < 2 or char_length(new.name) > 40 then raise exception 'Invalid name'; end if;
 new.address := lower(trim(new.address));
 if new.address !~ '^[a-z0-9]([a-z0-9.-]{0,78}[a-z0-9])?$' or position('.' in new.address) = 0 or position('..' in new.address) > 0 then raise exception 'Invalid address'; end if;
 if new.port is null or new.port < 1 or new.port > 65535 then raise exception 'Invalid port'; end if;
 new.game_version := trim(coalesce(new.game_version, ''));
 if char_length(new.game_version) > 32 then raise exception 'Invalid version'; end if;
 new.description := trim(coalesce(new.description, ''));
 if char_length(new.description) > 240 then raise exception 'Invalid description'; end if;
 select coalesce(array_agg(distinct lower(trim(tag))), '{}'::text[]) into cleaned from unnest(coalesce(new.tags, '{}'::text[])) as tag where trim(tag) <> '';
 if cleaned is null then cleaned := '{}'; end if;
 if cardinality(cleaned) > 6 or exists(select 1 from unnest(cleaned) as tag where tag !~ '^[a-z0-9-]{2,16}$') then raise exception 'Invalid tags'; end if;
 new.tags := cleaned;
 new.is_public := coalesce(new.is_public, true);
 if new.banner_path = '' then new.banner_path := null; end if;
 if new.banner_path is not null and new.banner_path is distinct from new.owner_id::text || '/' || new.id::text || '.webp' then raise exception 'Invalid banner'; end if;
 return new;
end; $$;
revoke all on function private.community_server_guard() from public, anon, authenticated;
drop trigger if exists community_server_guard on public.community_servers;
create trigger community_server_guard before insert or update on public.community_servers
 for each row execute function private.community_server_guard();

alter table public.community_servers enable row level security;
revoke all on public.community_servers from anon, authenticated;
grant select on public.community_servers to anon, authenticated;
grant insert (name, address, port, game_version, description, tags, is_public) on public.community_servers to authenticated;
grant update (name, address, port, game_version, description, tags, is_public, banner_path) on public.community_servers to authenticated;
grant delete on public.community_servers to authenticated;

drop policy if exists community_servers_read on public.community_servers;
create policy community_servers_read on public.community_servers for select to anon, authenticated
 using (is_public or owner_id = (select auth.uid()) or (select public.forum_is_admin()));
drop policy if exists community_servers_insert on public.community_servers;
create policy community_servers_insert on public.community_servers for insert to authenticated
 with check (owner_id = (select auth.uid()) and coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'false');
drop policy if exists community_servers_update on public.community_servers;
create policy community_servers_update on public.community_servers for update to authenticated
 using (owner_id = (select auth.uid()) or (select public.forum_is_admin()))
 with check (owner_id = (select auth.uid()) or (select public.forum_is_admin()));
drop policy if exists community_servers_delete on public.community_servers;
create policy community_servers_delete on public.community_servers for delete to authenticated
 using (owner_id = (select auth.uid()) or (select public.forum_is_admin()));

insert into storage.buckets (id, name, "public", file_size_limit, allowed_mime_types)
 values ('community-banners', 'community-banners', true, 262144, array['image/webp'])
 on conflict (id) do update set "public" = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.community_banner_guard() returns trigger
language plpgsql security definer set search_path = '' as $$
declare incoming bigint; server_key text; folder text;
begin
 if new.bucket_id is distinct from 'community-banners' then return new; end if;
 if coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if new.name !~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$' then raise exception 'Invalid banner'; end if;
 folder := split_part(new.name, '/', 1);
 server_key := split_part(split_part(new.name, '/', 2), '.', 1);
 if auth.uid() is not null and folder is distinct from auth.uid()::text then raise exception 'Invalid folder'; end if;
 if auth.uid() is null and current_user not in ('postgres', 'supabase_admin') then raise exception 'Invalid folder'; end if;
 incoming := coalesce((new.metadata->>'size')::bigint, (new.metadata->>'contentLength')::bigint, 262144);
 if incoming < 0 or incoming > 262144 then raise exception 'Image is too large'; end if;
 if not exists(select 1 from public.community_servers where id::text = server_key and owner_id::text = folder) then raise exception 'Invalid banner'; end if;
 return new;
end; $$;
revoke all on function private.community_banner_guard() from public, anon, authenticated;
drop trigger if exists community_banner_guard on storage.objects;
create trigger community_banner_guard before insert or update of name, metadata, bucket_id on storage.objects
 for each row execute function private.community_banner_guard();

drop policy if exists community_banner_read on storage.objects;
create policy community_banner_read on storage.objects for select to anon, authenticated
 using (bucket_id = 'community-banners');
drop policy if exists community_banner_insert on storage.objects;
create policy community_banner_insert on storage.objects for insert to authenticated with check (
 bucket_id = 'community-banners'
 and coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'false'
 and split_part(name, '/', 1) = (select auth.uid())::text
 and name ~ '^[0-9a-f-]{36}/[0-9a-f-]{36}\.webp$'
);
drop policy if exists community_banner_update on storage.objects;
create policy community_banner_update on storage.objects for update to authenticated
 using (bucket_id = 'community-banners' and split_part(name, '/', 1) = (select auth.uid())::text)
 with check (bucket_id = 'community-banners' and split_part(name, '/', 1) = (select auth.uid())::text);
drop policy if exists community_banner_delete on storage.objects;
create policy community_banner_delete on storage.objects for delete to authenticated
 using (bucket_id = 'community-banners' and split_part(name, '/', 1) = (select auth.uid())::text);

commit;
