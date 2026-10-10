-- Local/demo fleet data. This file runs only when the local Supabase database is reset.
with stand_order as (
  select id, row_number() over (order by name) as n
  from public.stands
  where college_id = (select id from public.colleges where short_code = 'IITK')
)
insert into public.bikes(college_id, stand_id, short_code, status, notes)
select c.id, s.id, 'K-' || lpad(gs.n::text, 3, '0'), 'available',
       case when gs.n % 9 = 0 then 'Demo inventory — inspect before first use' else null end
from generate_series(1, 30) as gs(n)
join public.colleges c on c.short_code = 'IITK'
join stand_order s on s.n = ((gs.n - 1) % (select count(*) from stand_order)) + 1
on conflict (college_id, short_code) do nothing;
