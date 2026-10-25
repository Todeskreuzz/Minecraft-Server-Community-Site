-- Disposable CI database only.
begin;
insert into auth.users(id, email, raw_user_meta_data) values
 ('00000000-0000-4000-8000-00000000bb01','spam-new@example.invalid','{"display_name":"Spam New"}'),
 ('00000000-0000-4000-8000-00000000bb02','spam-minute@example.invalid','{"display_name":"Spam Minute"}'),
 ('00000000-0000-4000-8000-00000000bb03','spam-old@example.invalid','{"display_name":"Spam Old"}'),
 ('00000000-0000-4000-8000-00000000bb04','spam-cool@example.invalid','{"display_name":"Spam Cool"}');
update public.forum_profiles set created_at=now()-interval '3 days' where id='00000000-0000-4000-8000-00000000bb03';

alter table public.forum_topics disable trigger forum_topic_guard;
insert into public.forum_topics(author_id,title,body,category_id,created_at)
select '00000000-0000-4000-8000-00000000bb01','Tag '||n,'Beitrag','general',now()-interval '2 hours' from generate_series(1,8) n;
insert into public.forum_topics(author_id,title,body,category_id,created_at)
select '00000000-0000-4000-8000-00000000bb02','Min '||n,'Beitrag','general',now()-interval '40 seconds' from generate_series(1,2) n;
insert into public.forum_topics(author_id,title,body,category_id,created_at)
select '00000000-0000-4000-8000-00000000bb03','Old '||n,'Beitrag','general',now()-interval '40 seconds' from generate_series(1,2) n;
alter table public.forum_topics enable trigger forum_topic_guard;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000bb01',true);
set local role authenticated;
do $$ begin
 begin insert into public.forum_topics(title,body,category_id) values('Zu viel','Beitrag','general'); raise exception 'New account passed the daily limit';
 exception when raise_exception then if sqlerrm <> 'Slow down' then raise; end if; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000bb02',true);
set local role authenticated;
do $$ begin
 begin insert into public.forum_topics(title,body,category_id) values('Zu schnell','Beitrag','general'); raise exception 'New account passed the minute limit';
 exception when raise_exception then if sqlerrm <> 'Slow down' then raise; end if; end;
end $$;
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000bb03',true);
set local role authenticated;
insert into public.forum_topics(title,body,category_id) values('Erlaubt','Beitrag','general');
reset role;

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000bb04',true);
set local role authenticated;
insert into public.forum_topics(title,body,category_id) values('Erster','Beitrag','general');
do $$ begin
 begin insert into public.forum_topics(title,body,category_id) values('Zweiter','Beitrag','general'); raise exception 'Cooldown missing';
 exception when raise_exception then if sqlerrm <> 'Please wait 30 seconds between topics' then raise; end if; end;
end $$;
reset role;

do $$ begin
 if has_function_privilege('anon','public.get_turnstile_secret()','execute') then raise exception 'Anon can read the captcha secret'; end if;
 if has_function_privilege('authenticated','public.get_turnstile_secret()','execute') then raise exception 'Members can read the captcha secret'; end if;
 if has_function_privilege('anon','private.get_turnstile_secret()','execute') then raise exception 'Anon can read the private captcha secret'; end if;
 if not has_function_privilege('service_role','private.get_turnstile_secret()','execute') then raise exception 'Service role cannot read the captcha secret'; end if;
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-00000000bb04',true);
set local role authenticated;
do $$ begin
 begin perform public.get_turnstile_secret(); raise exception 'Member read the captcha secret';
 exception when insufficient_privilege then null; end;
end $$;
reset role;
select set_config('request.jwt.claims','{"role":"service_role"}',true);
select set_config('request.jwt.claim.role','service_role',true);
select vault.create_secret('test-turnstile-secret','turnstile_secret_key','ci');
set local role service_role;
do $$ begin
 if public.get_turnstile_secret() is distinct from 'test-turnstile-secret' then raise exception 'Service role secret mismatch'; end if;
end $$;
reset role;
do $$ begin raise notice 'Spam tests passed'; end $$;
rollback;
