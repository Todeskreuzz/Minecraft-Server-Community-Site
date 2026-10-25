-- Permanent profile UIDs and public profile media. Safe to reapply. Never recycles a UID.
begin;
alter table public.forum_profiles add column if not exists uid bigint;
alter table public.forum_profiles add column if not exists bio text not null default '';
alter table public.forum_profiles add column if not exists avatar_path text;
alter table public.forum_profiles add column if not exists banner_path text;
alter table public.forum_profiles add column if not exists background_path text;
alter table public.forum_profiles add column if not exists avatar_preset text not null default '';
alter table public.forum_profiles add column if not exists banner_preset text not null default '';
alter table public.forum_profiles add column if not exists background_preset text not null default '';
create sequence if not exists public.forum_uid_seq as bigint;

create or replace function private.assign_missing_uids() returns void language plpgsql security definer set search_path='' as $$
begin
 with ranked as (
  select id, row_number() over (order by created_at, id) as n
  from public.forum_profiles where uid is null
 ), base as (
  select coalesce(max(uid), 0) as m from public.forum_profiles
 )
 update public.forum_profiles p set uid = base.m + ranked.n
 from ranked, base where p.id = ranked.id and p.uid is null;
 perform setval('public.forum_uid_seq', coalesce((select max(uid) from public.forum_profiles), 1), exists(select 1 from public.forum_profiles where uid is not null));
end; $$;
revoke all on function private.assign_missing_uids() from public, anon, authenticated;
select private.assign_missing_uids();
alter table public.forum_profiles alter column uid set default nextval('public.forum_uid_seq');
alter table public.forum_profiles alter column uid set not null;
alter sequence public.forum_uid_seq owned by public.forum_profiles.uid;
create unique index if not exists forum_profiles_uid_key on public.forum_profiles(uid);

alter table public.forum_profiles drop constraint if exists forum_profiles_bio_len;
alter table public.forum_profiles add constraint forum_profiles_bio_len check (char_length(bio) <= 400);
alter table public.forum_profiles drop constraint if exists forum_profiles_avatar_preset_ok;
alter table public.forum_profiles add constraint forum_profiles_avatar_preset_ok check (avatar_preset in ('','grove','deepslate','campfire','nether','end'));
alter table public.forum_profiles drop constraint if exists forum_profiles_banner_preset_ok;
alter table public.forum_profiles add constraint forum_profiles_banner_preset_ok check (banner_preset in ('','grove','deepslate','campfire','nether','end'));
alter table public.forum_profiles drop constraint if exists forum_profiles_background_preset_ok;
alter table public.forum_profiles add constraint forum_profiles_background_preset_ok check (background_preset in ('','grove','deepslate','campfire','nether','end'));
alter table public.forum_profiles drop constraint if exists forum_profiles_avatar_path_ok;
alter table public.forum_profiles add constraint forum_profiles_avatar_path_ok check (avatar_path is null or avatar_path = id::text || '/avatar.webp');
alter table public.forum_profiles drop constraint if exists forum_profiles_banner_path_ok;
alter table public.forum_profiles add constraint forum_profiles_banner_path_ok check (banner_path is null or banner_path = id::text || '/banner.webp');
alter table public.forum_profiles drop constraint if exists forum_profiles_background_path_ok;
alter table public.forum_profiles add constraint forum_profiles_background_path_ok check (background_path is null or background_path = id::text || '/background.webp');

create or replace function private.forum_profile_guard() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_op = 'UPDATE' and old.uid is not null and new.uid is distinct from old.uid then
  raise exception 'UID is permanent';
 end if;
 if exists(select 1 from private.forum_owner_names where user_id = new.id) then
  new.display_name := 'Owner';
 end if;
 if new.bio is null then new.bio := ''; end if;
 return new;
end; $$;
revoke all on function private.forum_profile_guard() from public, anon, authenticated;
drop trigger if exists forum_profile_guard on public.forum_profiles;
create trigger forum_profile_guard before insert or update on public.forum_profiles for each row execute function private.forum_profile_guard();

drop policy if exists profiles_update_own on public.forum_profiles;
create policy profiles_update_own on public.forum_profiles for update to authenticated
 using (id = (select auth.uid()) and coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'false')
 with check (id = (select auth.uid()));
grant update (display_name, bio, avatar_preset, banner_preset, background_preset) on public.forum_profiles to authenticated;

drop function if exists public.forum_author_names(uuid[]);
create function public.forum_author_names(p_ids uuid[])
 returns table(id uuid, display_name text, is_owner boolean, uid bigint, avatar_path text, avatar_preset text)
 language sql stable security definer set search_path='' as $$
 select p.id,
 case when n.user_id is null then p.display_name
 when auth.uid() = n.user_id or exists(select 1 from private.forum_friends f where f.owner_id = n.user_id and f.friend_id = auth.uid())
 then n.real_name else null end,
 n.user_id is not null,
 p.uid, p.avatar_path, p.avatar_preset
 from public.forum_profiles p left join private.forum_owner_names n on n.user_id = p.id
 where p.id = any(p_ids) and coalesce(array_length(p_ids, 1), 0) <= 100;
$$;
revoke all on function public.forum_author_names(uuid[]) from public, anon, authenticated;
grant execute on function public.forum_author_names(uuid[]) to anon, authenticated;

insert into storage.buckets (id, name, "public", file_size_limit, allowed_mime_types)
 values ('profile-media', 'profile-media', true, 262144, array['image/webp'])
 on conflict (id) do update set "public" = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create or replace function private.profile_media_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare
 folder text;
 incoming bigint;
 used bigint;
begin
 if new.bucket_id is distinct from 'profile-media' then return new; end if;
 if coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if new.name !~ '^[0-9a-f-]{36}/(avatar|banner|background)\.webp$' then raise exception 'Invalid media path'; end if;
 if auth.uid() is not null and auth.uid()::text is distinct from split_part(new.name, '/', 1) then raise exception 'Invalid folder'; end if;
 if auth.uid() is null and current_user not in ('postgres', 'supabase_admin') then raise exception 'Invalid folder'; end if;
 incoming := coalesce((new.metadata->>'size')::bigint, (new.metadata->>'contentLength')::bigint, 262144);
 if incoming < 0 or incoming > 262144 then raise exception 'Image is too large'; end if;
 folder := split_part(new.name, '/', 1);
 select coalesce(sum(coalesce((metadata->>'size')::bigint, (metadata->>'contentLength')::bigint, 262144)), 0) into used
 from storage.objects where bucket_id = 'profile-media' and split_part(name, '/', 1) = folder and name is distinct from new.name;
 if used + incoming > 20971520 then raise exception 'Storage quota exceeded'; end if;
 return new;
end; $$;
revoke all on function private.profile_media_guard() from public, anon, authenticated;
drop trigger if exists profile_media_guard on storage.objects;
create trigger profile_media_guard before insert or update of name, metadata, bucket_id on storage.objects for each row execute function private.profile_media_guard();

drop policy if exists profile_media_read on storage.objects;
create policy profile_media_read on storage.objects for select to anon, authenticated using (bucket_id = 'profile-media');
drop policy if exists profile_media_insert on storage.objects;
create policy profile_media_insert on storage.objects for insert to authenticated with check (
 bucket_id = 'profile-media'
 and coalesce((select auth.jwt()->>'is_anonymous'), 'false') = 'false'
 and name = (select auth.uid())::text || '/' || split_part(name, '/', 2)
 and split_part(name, '/', 2) in ('avatar.webp', 'banner.webp', 'background.webp')
);
drop policy if exists profile_media_update on storage.objects;
create policy profile_media_update on storage.objects for update to authenticated
 using (bucket_id = 'profile-media' and split_part(name, '/', 1) = (select auth.uid())::text)
 with check (bucket_id = 'profile-media' and name = (select auth.uid())::text || '/' || split_part(name, '/', 2) and split_part(name, '/', 2) in ('avatar.webp', 'banner.webp', 'background.webp'));
drop policy if exists profile_media_delete on storage.objects;
create policy profile_media_delete on storage.objects for delete to authenticated
 using (bucket_id = 'profile-media' and split_part(name, '/', 1) = (select auth.uid())::text);

create or replace function public.forum_set_media(p_slot text, p_header bytea) returns void language plpgsql security definer set search_path='' as $$
declare
 path text;
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if p_slot not in ('avatar', 'banner', 'background') then raise exception 'Invalid slot'; end if;
 if octet_length(p_header) < 12 or substring(p_header from 1 for 4) <> '\x52494646'::bytea or substring(p_header from 9 for 4) <> '\x57454250'::bytea then
  raise exception 'Invalid image';
 end if;
 path := auth.uid()::text || '/' || p_slot || '.webp';
 if not exists(select 1 from storage.objects where bucket_id = 'profile-media' and name = path) then raise exception 'Image missing'; end if;
 if p_slot = 'avatar' then update public.forum_profiles set avatar_path = path, avatar_preset = '' where id = auth.uid();
 elsif p_slot = 'banner' then update public.forum_profiles set banner_path = path, banner_preset = '' where id = auth.uid();
 else update public.forum_profiles set background_path = path, background_preset = '' where id = auth.uid();
 end if;
end; $$;
create or replace function public.forum_clear_media(p_slot text) returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or coalesce(auth.jwt()->>'is_anonymous', 'false') = 'true' then raise exception 'Not authorized'; end if;
 if p_slot not in ('avatar', 'banner', 'background') then raise exception 'Invalid slot'; end if;
 if p_slot = 'avatar' then update public.forum_profiles set avatar_path = null where id = auth.uid();
 elsif p_slot = 'banner' then update public.forum_profiles set banner_path = null where id = auth.uid();
 else update public.forum_profiles set background_path = null where id = auth.uid();
 end if;
end; $$;
revoke all on function public.forum_set_media(text, bytea), public.forum_clear_media(text) from public, anon, authenticated;
grant execute on function public.forum_set_media(text, bytea), public.forum_clear_media(text) to authenticated;

drop view if exists public.forum_profile_cards;
create view public.forum_profile_cards with (security_invoker = true) as
 select p.id, p.uid, p.display_name, p.bio, p.created_at,
  p.avatar_path, p.banner_path, p.background_path,
  p.avatar_preset, p.banner_preset, p.background_preset,
  (select count(*) from public.forum_topics t where t.author_id = p.id) as thread_count,
  (select count(*) from public.forum_replies r where r.author_id = p.id) as reply_count
 from public.forum_profiles p;
revoke all on public.forum_profile_cards from anon, authenticated;
grant select on public.forum_profile_cards to anon, authenticated;
commit;
