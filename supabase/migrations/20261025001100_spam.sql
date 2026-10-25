-- Posting limits for new accounts, plus a Turnstile secret reader for the edge function.
begin;
create or replace function private.forum_post_guard() returns trigger language plpgsql security definer set search_path='' as $$
declare started timestamptz; per_minute int := 8; per_day int := 60; recent int; today int;
begin
 if new.author_id is distinct from auth.uid() then raise exception 'Invalid author'; end if;
 perform pg_advisory_xact_lock(hashtextextended(new.author_id::text,0));
 new.created_at := now();
 if tg_table_name='forum_topics' then
  new.locked := false;
  if exists(select 1 from public.forum_topics where author_id=new.author_id and created_at>now()-interval '30 seconds') then raise exception 'Please wait 30 seconds between topics'; end if;
 else
  perform 1 from public.forum_topics where id=new.topic_id and not locked for share;
  if not found then raise exception 'Topic closed or missing'; end if;
  if exists(select 1 from public.forum_replies where author_id=new.author_id and created_at>now()-interval '5 seconds') then raise exception 'Please wait 5 seconds between replies'; end if;
 end if;
 select p.created_at into started from public.forum_profiles p where p.id = new.author_id;
 if started is not null and started > now() - interval '24 hours' then per_minute := 2; per_day := 8; end if;
 select count(*) into recent from (
  select created_at from public.forum_topics where author_id=new.author_id and created_at>now()-interval '1 minute'
  union all
  select created_at from public.forum_replies where author_id=new.author_id and created_at>now()-interval '1 minute'
 ) posts;
 select count(*) into today from (
  select created_at from public.forum_topics where author_id=new.author_id and created_at>now()-interval '1 day'
  union all
  select created_at from public.forum_replies where author_id=new.author_id and created_at>now()-interval '1 day'
 ) posts;
 if recent >= per_minute or today >= per_day then raise exception 'Slow down'; end if;
 return new;
end; $$;

create or replace function private.get_turnstile_secret() returns text language plpgsql security definer set search_path='' as $$
declare secret text;
begin
 if coalesce(auth.role(),'') is distinct from 'service_role' then raise exception 'Not authorized'; end if;
 select decrypted_secret into secret from vault.decrypted_secrets where name='turnstile_secret_key' limit 1;
 if coalesce(secret,'')='' then raise exception 'Captcha is not configured'; end if;
 return secret;
end; $$;

create or replace function public.get_turnstile_secret() returns text language sql security definer set search_path='' as $$
 select private.get_turnstile_secret();
$$;
revoke all on function private.forum_post_guard(), private.get_turnstile_secret(), public.get_turnstile_secret() from public, anon, authenticated;
grant execute on function public.get_turnstile_secret(), private.get_turnstile_secret() to service_role;
commit;
