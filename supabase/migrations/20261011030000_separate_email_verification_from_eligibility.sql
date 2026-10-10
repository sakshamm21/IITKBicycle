-- Keep institutional-email verification separate from ride eligibility.
-- Campus members still need a staff eligibility approval; invited guests become
-- eligible only after using the exact invitation email and confirming it.
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

  -- Campus members remain pending until a college admin approves them.
  -- Guests are approved only if an invited account is already verified.
  if v_college.id is not null and new.email_confirmed_at is not null and v_member_type = 'guest' then
    v_status := 'approved';
    update public.guest_invitations set used_at = now()
      where college_id = v_college.id and lower(email) = v_email and used_at is null;
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
declare v_profile public.profiles%rowtype;
begin
  if old.email_confirmed_at is null and new.email_confirmed_at is not null then
    select * into v_profile from public.profiles where id = new.id;
    if v_profile.member_type = 'guest' and v_profile.status = 'pending' then
      update public.profiles set status = 'approved', updated_at = now()
        where id = new.id and status = 'pending'
          and exists (
            select 1 from public.guest_invitations g
            where g.college_id = v_profile.college_id
              and lower(g.email) = lower(new.email)
              and g.used_at is not null
              and g.expires_at > now()
          );
    end if;
    -- Campus profiles intentionally remain pending after email confirmation.
  end if;
  return new;
end;
$$;
