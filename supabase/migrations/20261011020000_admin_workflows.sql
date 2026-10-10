-- Admin-only state transitions, kept out of direct client writes.
create or replace function public.approve_rider(p_profile_id uuid)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_admin public.profiles%rowtype; v_target public.profiles%rowtype;
begin
  select * into v_admin from public.profiles where id=auth.uid();
  if v_admin.id is null or v_admin.status <> 'approved' or v_admin.role not in ('college_admin','super_admin') then
    raise exception 'College administrator authorization required.' using errcode='42501';
  end if;
  select * into v_target from public.profiles where id=p_profile_id and college_id=v_admin.college_id for update;
  if v_target.id is null or v_target.status <> 'pending' then raise exception 'Rider is not pending approval.'; end if;
  if (select u.email_confirmed_at from auth.users u where u.id=v_target.id) is null then raise exception 'Rider must verify their email first.'; end if;
  update public.profiles set status='approved',updated_at=now() where id=v_target.id;
  insert into public.audit_log(college_id,actor_id,action,entity_type,entity_id)
    values(v_admin.college_id,auth.uid(),'rider_approved','profile',v_target.id::text);
end;
$$;

create or replace function public.set_issue_status(p_issue_id uuid, p_status text)
returns void language plpgsql security definer set search_path = ''
as $$
declare v_staff public.profiles%rowtype; v_issue public.issue_reports%rowtype;
begin
  select * into v_staff from public.profiles where id=auth.uid();
  if v_staff.id is null or v_staff.status <> 'approved' or v_staff.role not in ('attendant','college_admin','super_admin') then
    raise exception 'Staff authorization required.' using errcode='42501';
  end if;
  if p_status not in ('open','in_progress','resolved') then raise exception 'Invalid issue status.'; end if;
  select * into v_issue from public.issue_reports where id=p_issue_id and college_id=v_staff.college_id for update;
  if v_issue.id is null then raise exception 'Issue not found.'; end if;
  update public.issue_reports set status=p_status,resolved_at=case when p_status='resolved' then now() else null end,
    resolved_by=case when p_status='resolved' then auth.uid() else null end where id=v_issue.id;
  insert into public.audit_log(college_id,actor_id,action,entity_type,entity_id,details)
    values(v_staff.college_id,auth.uid(),'issue_status_changed','issue_report',v_issue.id::text,jsonb_build_object('status',p_status));
end;
$$;
revoke all on function public.approve_rider(uuid) from public;
revoke all on function public.set_issue_status(uuid,text) from public;
grant execute on function public.approve_rider(uuid) to authenticated;
grant execute on function public.set_issue_status(uuid,text) to authenticated;
