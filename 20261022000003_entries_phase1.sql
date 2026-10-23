-- المرحلة 1 (خطة v2): رقم مرجعي فريد، حماية هوية المسجِّل ووقت الإنشاء، إجماليات الفترات من الخادم.
-- لم يُشغَّل على PostgreSQL حقيقي في بيئة الكتابة (انظر docs/08).

-- ───────── الرقم المرجعي ─────────
create sequence public.revenue_ref_seq;
create sequence public.expense_ref_seq;
alter table public.revenues add column reference_no text;
alter table public.expenses add column reference_no text;

create function public.set_reference_no() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.reference_no is null then
    if tg_table_name = 'revenues' then
      new.reference_no := 'R-' || lpad(nextval('public.revenue_ref_seq')::text, 6, '0');
    else
      new.reference_no := 'E-' || lpad(nextval('public.expense_ref_seq')::text, 6, '0');
    end if;
  end if;
  return new;
end $$;

create trigger revenues_refno before insert on public.revenues
  for each row execute function public.set_reference_no();
create trigger expenses_refno before insert on public.expenses
  for each row execute function public.set_reference_no();

alter table public.revenues alter column reference_no set not null;
alter table public.expenses alter column reference_no set not null;
alter table public.revenues add constraint revenues_reference_no_key unique (reference_no);
alter table public.expenses add constraint expenses_reference_no_key unique (reference_no);

-- ───────── لا تغيير لهوية المسجِّل أو وقت الإنشاء أو الرقم المرجعي ─────────
create function public.lock_entry_identity() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.id is distinct from old.id
     or new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at
     or new.occurred_at is distinct from old.occurred_at
     or new.reference_no is distinct from old.reference_no
     or new.device_id is distinct from old.device_id then
    raise exception 'لا يجوز تغيير هوية المسجِّل أو وقت الإنشاء أو الرقم المرجعي' using errcode = 'P0001';
  end if;
  return new;
end $$;

create trigger revenues_identity_lock before update on public.revenues
  for each row execute function public.lock_entry_identity();
create trigger expenses_identity_lock before update on public.expenses
  for each row execute function public.lock_entry_identity();

-- ───────── add_revenue / add_expense: تعيدان الرقم المرجعي (لا المبلغ) ─────────
drop function public.add_revenue(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text);
drop function public.add_expense(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text);

create function public.add_revenue(
  p_op_id uuid, p_id uuid, p_device uuid, p_business_date date, p_occurred_at timestamptz,
  p_amount_iqd bigint, p_category uuid, p_account uuid,
  p_description text default null, p_receipt_no text default null, p_notes text default null
) returns text
language plpgsql security definer set search_path = '' as $$
declare v_ref text;
begin
  if not public.has_perm('revenue.create') then
    raise exception 'لا تملك صلاحية تسجيل الإيرادات' using errcode = '42501';
  end if;
  perform public.assert_device_ok(p_device);
  if p_business_date > public.local_today() then
    raise exception 'لا يجوز تسجيل عملية بتاريخ مستقبلي' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.sync_ops where op_id = p_op_id) then
    select reference_no into v_ref from public.revenues where id = p_id;   -- إعادة إرسال: لا تكرار
    return v_ref;
  end if;
  insert into public.revenues(id, business_date, occurred_at, amount_iqd, category_id, account_id,
                              description, receipt_no, notes, created_by, device_id)
  values (p_id, p_business_date, p_occurred_at, p_amount_iqd, p_category, p_account,
          p_description, p_receipt_no, p_notes, auth.uid(), p_device)
  returning reference_no into v_ref;
  insert into public.sync_ops(op_id, user_id, device_id, op_type, entity_id, result)
  values (p_op_id, auth.uid(), p_device, 'add_revenue', p_id, 'applied');
  update public.devices set last_sync_at = now(), last_seen_at = now() where id = p_device;
  return v_ref;
end $$;

create function public.add_expense(
  p_op_id uuid, p_id uuid, p_device uuid, p_business_date date, p_occurred_at timestamptz,
  p_amount_iqd bigint, p_category uuid, p_account uuid,
  p_description text default null, p_receipt_no text default null, p_notes text default null
) returns text
language plpgsql security definer set search_path = '' as $$
declare v_ref text;
begin
  if not public.has_perm('expense.create') then
    raise exception 'لا تملك صلاحية تسجيل المصروفات' using errcode = '42501';
  end if;
  perform public.assert_device_ok(p_device);
  if p_business_date > public.local_today() then
    raise exception 'لا يجوز تسجيل عملية بتاريخ مستقبلي' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.sync_ops where op_id = p_op_id) then
    select reference_no into v_ref from public.expenses where id = p_id;
    return v_ref;
  end if;
  insert into public.expenses(id, business_date, occurred_at, amount_iqd, category_id, account_id,
                              description, receipt_no, notes, created_by, device_id)
  values (p_id, p_business_date, p_occurred_at, p_amount_iqd, p_category, p_account,
          p_description, p_receipt_no, p_notes, auth.uid(), p_device)
  returning reference_no into v_ref;
  insert into public.sync_ops(op_id, user_id, device_id, op_type, entity_id, result)
  values (p_op_id, auth.uid(), p_device, 'add_expense', p_id, 'applied');
  update public.devices set last_sync_at = now(), last_seen_at = now() where id = p_device;
  return v_ref;
end $$;

-- ───────── إجماليات الفترة من الخادم (لا جمع في الواجهة، ولا سقف 1000 صف) ─────────
create function public.period_totals(p_from date, p_to date)
returns table (revenue_iqd bigint, expense_iqd bigint, net_iqd bigint)
language plpgsql stable security definer set search_path = '' as $$
declare
  v_rev bigint;
  v_exp bigint;
  v_can_rev boolean;
  v_can_exp boolean;
begin
  if p_from is null or p_to is null or p_from > p_to then
    raise exception 'نطاق تاريخ غير صالح' using errcode = '22023';
  end if;
  v_can_rev := public.has_perm('revenue.view_history')
               or (public.has_perm('revenue.view_today') and p_from = public.local_today() and p_to = public.local_today());
  v_can_exp := public.has_perm('expense.view');
  if v_can_rev then
    select coalesce(sum(r.amount_iqd), 0)::bigint into v_rev
    from public.revenues r where r.status = 'active' and r.business_date between p_from and p_to;
  end if;
  if v_can_exp then
    select coalesce(sum(e.amount_iqd), 0)::bigint into v_exp
    from public.expenses e where e.status = 'active' and e.business_date between p_from and p_to;
  end if;
  return query select v_rev, v_exp,
    case when v_can_rev and v_can_exp and public.has_perm('net.view') then v_rev - v_exp end;
end $$;

-- ───────── الصلاحيات ─────────
revoke all on function public.set_reference_no() from public, anon;
revoke all on function public.lock_entry_identity() from public, anon;
revoke all on function public.add_revenue(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text) from public, anon;
revoke all on function public.add_expense(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text) from public, anon;
revoke all on function public.period_totals(date,date) from public, anon;
grant execute on function public.add_revenue(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text) to authenticated;
grant execute on function public.add_expense(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text) to authenticated;
grant execute on function public.period_totals(date,date) to authenticated;
