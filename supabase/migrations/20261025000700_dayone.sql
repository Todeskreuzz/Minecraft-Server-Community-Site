-- Day One for the first ten UIDs, plus exclusive animated profile art.
begin;
create or replace function private.dayone_eligible(p_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(
  select 1 from public.forum_profiles p
  left join public.forum_roles r on r.user_id = p.id
  where p.id = p_id and (p.uid <= 10 or r.role = 'dayone')
 );
$$;
revoke all on function private.dayone_eligible(uuid) from public, anon, authenticated;

create or replace function private.sync_dayone_roles() returns void language plpgsql security definer set search_path='' as $$
begin
 insert into public.forum_roles(user_id, role)
 select p.id, 'dayone' from public.forum_profiles p
 where p.uid <= 10
   and not exists(select 1 from public.forum_roles r where r.user_id = p.id)
 on conflict (user_id) do nothing;
end; $$;
revoke all on function private.sync_dayone_roles() from public, anon, authenticated;

create or replace function private.assign_dayone_role() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.uid <= 10 and not exists(select 1 from public.forum_roles where user_id = new.id) then
  insert into public.forum_roles(user_id, role) values(new.id, 'dayone') on conflict (user_id) do nothing;
 end if;
 return new;
end; $$;
revoke all on function private.assign_dayone_role() from public, anon, authenticated;
drop trigger if exists assign_dayone_role on public.forum_profiles;
create trigger assign_dayone_role after insert on public.forum_profiles for each row execute function private.assign_dayone_role();
select private.sync_dayone_roles();

create or replace function private.protect_owner_role() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op = 'DELETE' and old.role = 'owner' then raise exception 'Owner is fixed'; end if;
 if tg_op = 'UPDATE' and old.role = 'owner' and new.role is distinct from 'owner' then raise exception 'Owner is fixed'; end if;
 if tg_op = 'UPDATE' and new.role = 'owner' and old.role is distinct from 'owner' then
  if exists(select 1 from public.forum_roles where role = 'owner' and user_id <> old.user_id) then raise exception 'Owner is fixed'; end if;
  if not exists(
   select 1 from private.forum_owner_names n
   join public.forum_profiles p on p.id = n.user_id
   where n.user_id = old.user_id
     and p.uid = (select min(p2.uid) from private.forum_owner_names n2 join public.forum_profiles p2 on p2.id = n2.user_id)
  ) then raise exception 'Owner is fixed'; end if;
 end if;
 return coalesce(new, old);
end; $$;

create or replace function private.forum_profile_guard() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op = 'UPDATE' and old.uid is not null and new.uid is distinct from old.uid then raise exception 'UID is permanent'; end if;
 if exists(select 1 from private.forum_owner_names where user_id = new.id) then new.display_name := 'Owner'; end if;
 if new.bio is null then new.bio := ''; end if;
 if not private.dayone_eligible(new.id) and (
  new.avatar_preset in ('aurora','voxels','netherloop','endloop')
  or new.banner_preset in ('aurora','voxels','netherloop','endloop')
  or new.background_preset in ('aurora','voxels','netherloop','endloop')
 ) then raise exception 'Day One only'; end if;
 return new;
end; $$;

alter table public.forum_profiles drop constraint if exists forum_profiles_avatar_preset_ok;
alter table public.forum_profiles add constraint forum_profiles_avatar_preset_ok check (avatar_preset in ('','grove','deepslate','campfire','nether','end','aurora','voxels','netherloop','endloop'));
alter table public.forum_profiles drop constraint if exists forum_profiles_banner_preset_ok;
alter table public.forum_profiles add constraint forum_profiles_banner_preset_ok check (banner_preset in ('','grove','deepslate','campfire','nether','end','aurora','voxels','netherloop','endloop'));
alter table public.forum_profiles drop constraint if exists forum_profiles_background_preset_ok;
alter table public.forum_profiles add constraint forum_profiles_background_preset_ok check (background_preset in ('','grove','deepslate','campfire','nether','end','aurora','voxels','netherloop','endloop'));
alter table public.forum_profiles drop constraint if exists forum_profiles_avatar_path_ok;
alter table public.forum_profiles add constraint forum_profiles_avatar_path_ok check (avatar_path is null or avatar_path in (id::text || '/avatar.webp', id::text || '/avatar.gif', id::text || '/avatar.anim.webp'));
alter table public.forum_profiles drop constraint if exists forum_profiles_banner_path_ok;
alter table public.forum_profiles add constraint forum_profiles_banner_path_ok check (banner_path is null or banner_path in (id::text || '/banner.webp', id::text || '/banner.gif', id::text || '/banner.anim.webp'));
alter table public.forum_profiles drop constraint if exists forum_profiles_background_path_ok;
alter table public.forum_profiles add constraint forum_profiles_background_path_ok check (background_path is null or background_path in (id::text || '/background.webp', id::text || '/background.gif', id::text || '/background.anim.webp'));

insert into storage.buckets (id, name, "public", file_size_limit, allowed_mime_types)
 values ('profile-media', 'profile-media', true, 2097152, array['image/webp','image/gif'])
 on conflict (id) do update set "public" = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.profile_media_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare
 folder text;
 incoming bigint;
 used bigint;
 animated boolean;
begin
 if new.bucket_id is distinct from 'profile-media' then return new; end if;
 if coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if new.name !~ '^[0-9a-f-]{36}/(avatar|banner|background)(\.webp|\.gif|\.anim\.webp)$' then raise exception 'Invalid media path'; end if;
 if auth.uid() is not null and auth.uid()::text is distinct from split_part(new.name, '/', 1) then raise exception 'Invalid folder'; end if;
 if auth.uid() is null and current_user not in ('postgres', 'supabase_admin') then raise exception 'Invalid folder'; end if;
 animated := new.name ~ '\.(gif|anim\.webp)$';
 if animated and not private.dayone_eligible(split_part(new.name, '/', 1)::uuid) then raise exception 'Day One only'; end if;
 if animated then
  incoming := coalesce((new.metadata->>'size')::bigint, (new.metadata->>'contentLength')::bigint, 0);
  if incoming <= 0 or incoming > 2097152 then raise exception 'Image is too large'; end if;
 else
  incoming := coalesce((new.metadata->>'size')::bigint, (new.metadata->>'contentLength')::bigint, 262144);
  if incoming < 0 or incoming > 262144 then raise exception 'Image is too large'; end if;
 end if;
 folder := split_part(new.name, '/', 1);
 select coalesce(sum(coalesce((metadata->>'size')::bigint, (metadata->>'contentLength')::bigint, 262144)), 0) into used
 from storage.objects where bucket_id = 'profile-media' and split_part(name, '/', 1) = folder and name is distinct from new.name;
 if used + incoming > 20971520 then raise exception 'Storage quota exceeded'; end if;
 return new;
end; $$;

drop policy if exists profile_media_insert on storage.objects;
create policy profile_media_insert on storage.objects for insert to authenticated with check (
 bucket_id = 'profile-media'
 and coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'false'
 and name = (select auth.uid())::text || '/' || split_part(name, '/', 2)
 and split_part(name, '/', 2) ~ '^(avatar|banner|background)(\.webp|\.gif|\.anim\.webp)$'
);
drop policy if exists profile_media_update on storage.objects;
create policy profile_media_update on storage.objects for update to authenticated
 using (bucket_id = 'profile-media' and split_part(name, '/', 1) = (select auth.uid())::text)
 with check (
  bucket_id = 'profile-media'
  and name = (select auth.uid())::text || '/' || split_part(name, '/', 2)
  and split_part(name, '/', 2) ~ '^(avatar|banner|background)(\.webp|\.gif|\.anim\.webp)$'
 );

create or replace function public.forum_set_media(p_slot text, p_header bytea) returns void language plpgsql security definer set search_path='' as $$
declare
 path text;
 suffix text;
 limit_bytes bigint;
 bytes bigint;
 gif boolean;
 anim boolean;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if p_slot not in ('avatar', 'banner', 'background') then raise exception 'Invalid slot'; end if;
 gif := octet_length(p_header) >= 6 and substring(p_header from 1 for 6) = '\x474946383961'::bytea;
 anim := octet_length(p_header) >= 21
  and substring(p_header from 1 for 4) = '\x52494646'::bytea
  and substring(p_header from 9 for 4) = '\x57454250'::bytea
  and substring(p_header from 13 for 4) = '\x56503858'::bytea
  and (get_byte(p_header, 20) & 2) = 2;
 if gif or anim then
  if not private.dayone_eligible(auth.uid()) then raise exception 'Day One only'; end if;
  suffix := case when gif then '.gif' else '.anim.webp' end;
  limit_bytes := 2097152;
 elsif octet_length(p_header) >= 12 and substring(p_header from 1 for 4) = '\x52494646'::bytea and substring(p_header from 9 for 4) = '\x57454250'::bytea then
  suffix := '.webp';
  limit_bytes := 262144;
 else raise exception 'Invalid image';
 end if;
 path := auth.uid()::text || '/' || p_slot || suffix;
 if not exists(select 1 from storage.objects where bucket_id = 'profile-media' and name = path) then raise exception 'Image missing'; end if;
 select coalesce((metadata->>'size')::bigint, 0) into bytes from storage.objects where bucket_id = 'profile-media' and name = path;
 if suffix = '.webp' and bytes = 0 then bytes := 262144; end if;
 if bytes <= 0 or bytes > limit_bytes then raise exception 'Image is too large'; end if;
 delete from storage.objects
 where bucket_id = 'profile-media' and split_part(name, '/', 1) = auth.uid()::text and name <> path
   and split_part(name, '/', 2) in (p_slot || '.webp', p_slot || '.gif', p_slot || '.anim.webp');
 if p_slot = 'avatar' then update public.forum_profiles set avatar_path = path, avatar_preset = '' where id = auth.uid();
 elsif p_slot = 'banner' then update public.forum_profiles set banner_path = path, banner_preset = '' where id = auth.uid();
 else update public.forum_profiles set background_path = path, background_preset = '' where id = auth.uid();
 end if;
end; $$;
commit;
