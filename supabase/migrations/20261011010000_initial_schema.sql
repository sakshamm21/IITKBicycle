-- IITK Bicycle: secure multi-college MVP schema.
-- All state-changing ride operations are server-side RPCs. Clients never write bike/ride state directly.
create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table public.colleges (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  short_code text not null unique,
  email_domains text[] not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table public.guest_invitations (
  id uuid primary key default gen_random_uuid(),
  college_id uuid not null references public.colleges(id) on delete cascade,
  email text not null,
  invited_by uuid references auth.users(id),
  expires_at timestamptz not null default (now() + interval '30 days'),
  used_at timestamptz,
  created_at timestamptz not null default now(),
  unique (college_id, email)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  college_id uuid references public.colleges(id),
  full_name text not null default '',
  phone text,
  email text not null,
  role text not null default 'rider' check (role in ('rider','attendant','college_admin','super_admin')),
  status text not null default 'pending' check (status in ('pending','approved','rejected','suspended')),
  member_type text not null default 'campus' check (member_type in ('campus','guest')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.stands (
  id uuid primary key default gen_random_uuid(),
  college_id uuid not null references public.colleges(id) on delete cascade,
  name text not null,
  latitude double precision not null check (latitude between -90 and 90),
  longitude double precision not null check (longitude between -180 and 180),
  capacity integer not null default 20 check (capacity > 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (college_id, name)
);

create table public.bikes (
  id uuid primary key default gen_random_uuid(),
  college_id uuid not null references public.colleges(id) on delete cascade,
  stand_id uuid references public.stands(id),
  short_code text not null,
  status text not null default 'available' check (status in ('available','reserved','in_ride','maintenance','missing','retired')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (college_id, short_code)
);

create table public.rides (
  id uuid primary key default gen_random_uuid(),
  college_id uuid not null references public.colleges(id),
  bike_id uuid not null references public.bikes(id),
  rider_id uuid not null references public.profiles(id),
  status text not null default 'requested' check (status in ('requested','active','completed','cancelled','force_ended')),
  requested_at timestamptz not null default now(),
  released_at timestamptz,
  ended_at timestamptz,
  start_stand_id uuid references public.stands(id),
  end_stand_id uuid references public.stands(id),
  release_verified_by uuid references public.profiles(id),
  return_verified_by uuid references public.profiles(id),
  return_notes text,
  created_at timestamptz not null default now()
);

create unique index rides_one_open_per_rider on public.rides(rider_id) where status in ('requested','active');
create unique index rides_one_open_per_bike on public.rides(bike_id) where status in ('requested','active');

create table public.issue_reports (
  id uuid primary key default gen_random_uuid(),
  college_id uuid not null references public.colleges(id),
  bike_id uuid references public.bikes(id),
  reporter_id uuid not null references public.profiles(id),
  issue_type text not null check (issue_type in ('flat_tyre','brakes','chain','lock','missing','other')),
  description text not null default '',
  status text not null default 'open' check (status in ('open','in_progress','resolved')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references public.profiles(id)
);

create table public.audit_log (
  id bigint generated always as identity primary key,
  college_id uuid references public.colleges(id),
  actor_id uuid references auth.users(id),
  action text not null,
  entity_type text not null,
  entity_id text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index profiles_college_status_idx on public.profiles(college_id, status);
create index bikes_college_status_idx on public.bikes(college_id, status);
create index rides_college_status_idx on public.rides(college_id, status, requested_at desc);
create index issues_college_status_idx on public.issue_reports(college_id, status, created_at desc);

create or replace function private.current_college_id()
returns uuid language sql stable security definer set search_path = ''
as $$ select p.college_id from public.profiles p where p.id = auth.uid() $$;

create or replace function private.is_approved()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.status = 'approved' and (select u.email_confirmed_at from auth.users u where u.id = auth.uid()) is not null) $$;

create or replace function private.is_staff()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.status = 'approved' and p.role in ('attendant','college_admin','super_admin')) $$;

create or replace function private.is_college_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.status = 'approved' and p.role in ('college_admin','super_admin')) $$;

revoke all on function private.current_college_id() from public;
revoke all on function private.is_approved() from public;
revoke all on function private.is_staff() from public;
revoke all on function private.is_college_admin() from public;
grant usage on schema private to authenticated;
grant execute on function private.current_college_id() to authenticated;
grant execute on function private.is_approved() to authenticated;
grant execute on function private.is_staff() to authenticated;
grant execute on function private.is_college_admin() to authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare
  v_college public.colleges%rowtype;
  v_domain text;
  v_member_type text := 'campus';
  v_status text := 'pending';
  v_email text := lower(coalesce(new.email, ''));
begin
  v_domain := split_part(v_email, '@', 2);
  select c.* into v_college from public.colleges c
    where c.active and v_domain = any(c.email_domains) limit 1;

  if v_college.id is null then
    select c.* into v_college from public.colleges c
      join public.guest_invitations g on g.college_id = c.id
      where c.active and lower(g.email) = v_email and g.used_at is null and g.expires_at > now()
      limit 1;
    if v_college.id is not null then v_member_type := 'guest'; end if;
  end if;

  -- Institutional email identifies the campus but does not itself grant riding eligibility.
  -- Campus members remain pending until a college administrator approves them.
  -- An invited guest is eligible only after confirming the invited email.
  if v_college.id is not null and v_member_type = 'guest' then
    update public.guest_invitations set used_at = now()
      where college_id = v_college.id and lower(email) = v_email and used_at is null;
    if new.email_confirmed_at is not null then v_status := 'approved'; end if;
  end if;

  insert into public.profiles(id, college_id, email, full_name, role, status, member_type)
  values (new.id, v_college.id, v_email, coalesce(new.raw_user_meta_data ->> 'full_name',''), 'rider', v_status, v_member_type)
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.handle_email_confirmation()
returns trigger language plpgsql security definer set search_path = ''
as $$
declare v_profile public.profiles%rowtype; v_domain text;
begin
  if old.email_confirmed_at is null and new.email_confirmed_at is not null then
    select * into v_profile from public.profiles where id = new.id;
    v_domain := split_part(lower(coalesce(new.email,'')), '@', 2);
    if v_profile.member_type = 'campus' and exists (
      select 1 from public.colleges c where c.id = v_profile.college_id and v_domain = any(c.email_domains) and c.active
    ) then
      update public.profiles set status = 'approved', updated_at = now() where id = new.id and status = 'pending';
    elsif v_profile.member_type = 'guest' then
      update public.profiles set status = 'approved', updated_at = now() where id = new.id and status = 'pending'
        and exists (select 1 from public.guest_invitations g where g.college_id = v_profile.college_id and lower(g.email) = lower(new.email) and g.used_at is not null);
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
drop trigger if exists on_auth_email_confirmed on auth.users;
create trigger on_auth_email_confirmed after update of email_confirmed_at on auth.users for each row execute function public.handle_email_confirmation();

create or replace function public.request_ride(p_bike_code text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_profile public.profiles%rowtype; v_bike public.bikes%rowtype; v_ride_id uuid;
begin
  select * into v_profile from public.profiles where id = auth.uid() for update;
  if v_profile.id is null or v_profile.status <> 'approved' or v_profile.college_id is null
    or (select u.email_confirmed_at from auth.users u where u.id = auth.uid()) is null then
    raise exception 'Your account is not eligible to ride.' using errcode = '42501';
  end if;
  select * into v_bike from public.bikes b where b.college_id = v_profile.college_id and b.short_code = upper(trim(p_bike_code)) for update;
  if v_bike.id is null or v_bike.status <> 'available' then
    raise exception 'This bicycle is not available.' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.rides r where r.rider_id = auth.uid() and r.status in ('requested','active')) then
    raise exception 'You already have an open ride.' using errcode = 'P0001';
  end if;
  update public.bikes set status = 'reserved', updated_at = now() where id = v_bike.id and status = 'available';
  if not found then raise exception 'This bicycle was just reserved by someone else.' using errcode = 'P0001'; end if;
  insert into public.rides(college_id,bike_id,rider_id,status,start_stand_id)
    values(v_profile.college_id,v_bike.id,auth.uid(),'requested',v_bike.stand_id) returning id into v_ride_id;
  insert into public.audit_log(college_id,actor_id,action,entity_type,entity_id)
    values(v_profile.college_id,auth.uid(),'ride_requested','ride',v_ride_id::text);
  return v_ride_id;
end;
$$;

create or replace function public.release_ride(p_ride_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_ride public.rides%rowtype; v_staff public.profiles%rowtype;
begin
  select * into v_staff from public.profiles where id = auth.uid() for update;
  if v_staff.id is null or v_staff.status <> 'approved' or v_staff.role not in ('attendant','college_admin','super_admin') then
    raise exception 'Staff authorization required.' using errcode = '42501';
  end if;
  select * into v_ride from public.rides where id = p_ride_id and college_id = v_staff.college_id for update;
  if v_ride.id is null or v_ride.status <> 'requested' then raise exception 'Ride request is no longer pending.'; end if;
  update public.rides set status='active', released_at=now(), release_verified_by=auth.uid() where id=v_ride.id;
  update public.bikes set status='in_ride', updated_at=now() where id=v_ride.bike_id and status='reserved';
  if not found then raise exception 'Bicycle reservation state is inconsistent.'; end if;
  insert into public.audit_log(college_id,actor_id,action,entity_type,entity_id)
    values(v_ride.college_id,auth.uid(),'ride_released','ride',v_ride.id::text);
end;
$$;

create or replace function public.cancel_ride_request(p_ride_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_ride public.rides%rowtype;
begin
  select * into v_ride from public.rides where id=p_ride_id and rider_id=auth.uid() for update;
  if v_ride.id is null or v_ride.status <> 'requested' then raise exception 'Only your pending request can be cancelled.'; end if;
  update public.rides set status='cancelled' where id=v_ride.id;
  update public.bikes set status='available',updated_at=now() where id=v_ride.bike_id and status='reserved';
  insert into public.audit_log(college_id,actor_id,action,entity_type,entity_id)
    values(v_ride.college_id,auth.uid(),'ride_request_cancelled','ride',v_ride.id::text);
end;
$$;

create or replace function public.complete_ride(p_ride_id uuid, p_return_stand_id uuid, p_notes text default null)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_ride public.rides%rowtype; v_staff public.profiles%rowtype;
begin
  select * into v_staff from public.profiles where id=auth.uid() for update;
  if v_staff.id is null or v_staff.status <> 'approved' or v_staff.role not in ('attendant','college_admin','super_admin') then
    raise exception 'Staff authorization required.' using errcode = '42501';
  end if;
  select * into v_ride from public.rides where id=p_ride_id and college_id=v_staff.college_id for update;
  if v_ride.id is null or v_ride.status <> 'active' then raise exception 'Ride is not active.'; end if;
  if not exists(select 1 from public.stands s where s.id=p_return_stand_id and s.college_id=v_ride.college_id and s.active) then
    raise exception 'Choose an active stand in this campus.';
  end if;
  update public.rides set status='completed',ended_at=now(),end_stand_id=p_return_stand_id,
    return_verified_by=auth.uid(),return_notes=left(coalesce(p_notes,''),1000) where id=v_ride.id;
  update public.bikes set
    status = case
      when exists (select 1 from public.issue_reports i where i.bike_id=v_ride.bike_id and i.status <> 'resolved' and i.issue_type='missing') then 'missing'
      when exists (select 1 from public.issue_reports i where i.bike_id=v_ride.bike_id and i.status <> 'resolved' and i.issue_type in ('flat_tyre','brakes','chain')) then 'maintenance'
      else 'available'
    end,
    stand_id=p_return_stand_id,updated_at=now()
    where id=v_ride.bike_id;
  insert into public.audit_log(college_id,actor_id,action,entity_type,entity_id)
    values(v_ride.college_id,auth.uid(),'ride_returned','ride',v_ride.id::text);
end;
$$;

create or replace function public.cancel_own_ride_request(p_ride_id uuid)
returns void language sql security invoker set search_path = ''
as $$ select public.cancel_ride_request(p_ride_id) $$;

create or replace function public.report_bike_issue(p_bike_code text, p_issue_type text, p_description text default '')
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_profile public.profiles%rowtype; v_bike public.bikes%rowtype; v_id uuid;
begin
  select * into v_profile from public.profiles where id=auth.uid();
  if v_profile.id is null or v_profile.status <> 'approved' then raise exception 'Approved account required.' using errcode='42501'; end if;
  select * into v_bike from public.bikes where college_id=v_profile.college_id and short_code=upper(trim(p_bike_code));
  if v_bike.id is null then raise exception 'Bicycle not found.'; end if;
  if p_issue_type not in ('flat_tyre','brakes','chain','lock','missing','other') then raise exception 'Invalid issue type.'; end if;
  insert into public.issue_reports(college_id,bike_id,reporter_id,issue_type,description)
    values(v_profile.college_id,v_bike.id,auth.uid(),p_issue_type,left(coalesce(p_description,''),2000)) returning id into v_id;
  if p_issue_type in ('flat_tyre','brakes','chain','missing') then
    update public.bikes set status=case when p_issue_type='missing' then 'missing' else 'maintenance' end,updated_at=now() where id=v_bike.id;
  end if;
  insert into public.audit_log(college_id,actor_id,action,entity_type,entity_id)
    values(v_profile.college_id,auth.uid(),'issue_reported','issue_report',v_id::text);
  return v_id;
end;
$$;

create or replace function public.approve_guest(p_email text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_admin public.profiles%rowtype; v_id uuid;
begin
  select * into v_admin from public.profiles where id=auth.uid();
  if v_admin.id is null or v_admin.status <> 'approved' or v_admin.role not in ('college_admin','super_admin') then
    raise exception 'College administrator authorization required.' using errcode='42501';
  end if;
  insert into public.guest_invitations(college_id,email,invited_by)
    values(v_admin.college_id,lower(trim(p_email)),auth.uid())
    on conflict(college_id,email) do update set invited_by=excluded.invited_by,expires_at=now()+interval '30 days',used_at=null
    returning id into v_id;
  insert into public.audit_log(college_id,actor_id,action,entity_type,entity_id,details)
    values(v_admin.college_id,auth.uid(),'guest_invited','guest_invitation',v_id::text,jsonb_build_object('email',lower(trim(p_email))));
  return v_id;
end;
$$;

alter table public.colleges enable row level security;
alter table public.guest_invitations enable row level security;
alter table public.profiles enable row level security;
alter table public.stands enable row level security;
alter table public.bikes enable row level security;
alter table public.rides enable row level security;
alter table public.issue_reports enable row level security;
alter table public.audit_log enable row level security;

create policy colleges_read_own on public.colleges for select to authenticated using (id=private.current_college_id() and active);
create policy profiles_read_own_or_staff on public.profiles for select to authenticated using (
  id=auth.uid() or (college_id=private.current_college_id() and private.is_staff())
);
create policy profiles_update_own_safe_fields on public.profiles for update to authenticated using (id=auth.uid() and status <> 'suspended') with check (id=auth.uid());
create policy stands_read_approved on public.stands for select to authenticated using (college_id=private.current_college_id() and active and private.is_approved());
create policy bikes_read_approved on public.bikes for select to authenticated using (college_id=private.current_college_id() and private.is_approved());
create policy rides_read_own_or_staff on public.rides for select to authenticated using (
  (rider_id=auth.uid() and college_id=private.current_college_id()) or (college_id=private.current_college_id() and private.is_staff())
);
create policy issues_read_own_or_staff on public.issue_reports for select to authenticated using (
  (reporter_id=auth.uid() and college_id=private.current_college_id()) or (college_id=private.current_college_id() and private.is_staff())
);
create policy issues_staff_update on public.issue_reports for update to authenticated using (
  college_id=private.current_college_id() and private.is_staff()
) with check (college_id=private.current_college_id() and private.is_staff());
create policy audit_staff_read on public.audit_log for select to authenticated using (
  college_id=private.current_college_id() and private.is_college_admin()
);

revoke all on public.guest_invitations, public.audit_log from anon, authenticated;
revoke insert, delete on public.profiles from anon, authenticated;
revoke update on public.profiles from anon, authenticated;
grant update(full_name, phone) on public.profiles to authenticated;
revoke insert, update, delete on public.bikes, public.rides, public.stands, public.issue_reports, public.colleges from anon, authenticated;
grant select on public.colleges, public.profiles, public.stands, public.bikes, public.rides, public.issue_reports, public.audit_log to authenticated;

revoke all on function public.handle_new_user() from public, anon, authenticated;
revoke all on function public.handle_email_confirmation() from public, anon, authenticated;
revoke all on function public.request_ride(text) from public;
revoke all on function public.release_ride(uuid) from public;
revoke all on function public.cancel_ride_request(uuid) from public;
revoke all on function public.complete_ride(uuid,uuid,text) from public;
revoke all on function public.report_bike_issue(text,text,text) from public;
revoke all on function public.approve_guest(text) from public;
grant execute on function public.request_ride(text) to authenticated;
grant execute on function public.release_ride(uuid) to authenticated;
grant execute on function public.cancel_ride_request(uuid) to authenticated;
grant execute on function public.complete_ride(uuid,uuid,text) to authenticated;
grant execute on function public.report_bike_issue(text,text,text) to authenticated;
grant execute on function public.approve_guest(text) to authenticated;

-- Seed one campus and stations only; bike inventory can be safely expanded by an admin later.
insert into public.colleges(name,short_code,email_domains)
values ('Indian Institute of Technology Kanpur','IITK',array['iitk.ac.in'])
on conflict (short_code) do update set email_domains=excluded.email_domains, active=true;

insert into public.stands(college_id,name,latitude,longitude,capacity)
select c.id,s.name,s.lat,s.lng,25 from public.colleges c
cross join (values
  ('Main Gate',26.5114,80.2329),
  ('Academic Area',26.5128,80.2339),
  ('Central Library',26.5134,80.2321),
  ('Students Activity Centre',26.5106,80.2346),
  ('Health Centre',26.5154,80.2324),
  ('Shopping Complex',26.5097,80.2308)
) as s(name,lat,lng)
where c.short_code='IITK'
on conflict (college_id,name) do nothing;
