begin;
select plan(14);

select has_table('public', 'colleges', 'campus registry exists');
select has_table('public', 'profiles', 'rider profiles exist');
select has_table('public', 'stands', 'campus stands exist');
select has_table('public', 'bikes', 'bike inventory exists');
select has_table('public', 'rides', 'ride lifecycle exists');
select has_table('public', 'issue_reports', 'maintenance reports exist');
select has_table('public', 'audit_log', 'audit log exists');

select ok((select relrowsecurity from pg_class where oid = 'public.profiles'::regclass), 'profiles enforce row level security');
select ok((select relrowsecurity from pg_class where oid = 'public.bikes'::regclass), 'bikes enforce row level security');
select ok((select relrowsecurity from pg_class where oid = 'public.rides'::regclass), 'rides enforce row level security');

select has_function('public', 'request_ride', array['text'], 'ride requests go through a database function');
select has_function('public', 'release_ride', array['uuid'], 'attendant release goes through a database function');
select has_function('public', 'complete_ride', array['uuid', 'uuid', 'text'], 'attendant return goes through a database function');
select ok((select count(*) = 30 from public.bikes), 'local demo seed creates 30 bikes');

select * from finish();
rollback;
