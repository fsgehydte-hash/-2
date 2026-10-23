-- ريحانة — الأمان: الدوال المساعدة، المشغّلات، سياسات RLS، وواجهات الكتابة (RPC)
-- ملاحظة: لم يُشغَّل هذا الملف على PostgreSQL فعلي في هذه البيئة (انظر docs/05).

-- ───────── دوال الصلاحيات ─────────
create function public.is_active_user() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.is_active)
$$;

create function public.is_owner() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p
                 where p.id = auth.uid() and p.is_active and p.role = 'owner')
$$;

create function public.has_perm(p_code text) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.is_active
      and (p.role = 'owner'
           or exists (select 1 from public.user_permissions up
                      where up.user_id = p.id and up.permission_code = p_code))
  )
$$;

create function public.local_today() returns date
language sql stable set search_path = '' as $$
  select (now() at time zone 'Asia/Baghdad')::date
$$;

-- ───────── مشغّلات عامة ─────────
create function public.bump_version() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.version := old.version + 1;
  if tg_table_name in ('revenues','expenses') then
    new.server_updated_at := now();
  end if;
  return new;
end $$;

create function public.block_delete() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'الحذف ممنوع على %: استخدم الإلغاء مع سبب', tg_table_name using errcode = 'P0001';
end $$;

create function public.block_audit_mutation() returns trigger
language plpgsql set search_path = '' as $$
begin
  raise exception 'سجل التدقيق للإضافة فقط' using errcode = 'P0001';
end $$;

-- منع تسجيل/تعديل عملية في يوم أُغلق نهائياً (لا توجد علامة تجاوز؛ التصحيح = إعادة فتح معتمدة)
create function public.guard_closed_day() returns trigger
language plpgsql set search_path = '' as $$
declare d date;
begin
  foreach d in array array[new.business_date, case when tg_op = 'UPDATE' then old.business_date end] loop
    continue when d is null;
    if exists (select 1 from public.daily_closings c
               where c.business_date = d and c.status = 'final') then
      raise exception 'اليوم % مغلق نهائياً: يلزم إعادة فتح معتمدة', d using errcode = 'P0001';
    end if;
  end loop;
  return new;
end $$;

create function public.enforce_category_kind() returns trigger
language plpgsql set search_path = '' as $$
declare k text;
begin
  select kind into k from public.categories where id = new.category_id;
  if (tg_table_name = 'revenues' and k <> 'income')
     or (tg_table_name = 'expenses' and k <> 'expense') then
    raise exception 'نوع الفئة لا يطابق نوع العملية' using errcode = 'P0001';
  end if;
  return new;
end $$;

create function public.protect_finalized_closing() returns trigger
language plpgsql set search_path = '' as $$
begin
  if old.status = 'final' then
    if (new.opening_cash_iqd, new.cash_receipts_iqd, new.cash_payments_iqd, new.transfers_net_iqd,
        new.expected_cash_iqd, new.counted_cash_iqd, new.business_date, new.account_id)
       is distinct from
       (old.opening_cash_iqd, old.cash_receipts_iqd, old.cash_payments_iqd, old.transfers_net_iqd,
        old.expected_cash_iqd, old.counted_cash_iqd, old.business_date, old.account_id)
       or new.status not in ('final','reopened') then
      raise exception 'الإغلاق النهائي لا يُعدَّل؛ أعد فتحه بموافقة مسجلة' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;

create function public.protect_profile() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- لا يرفع المستخدم صلاحياته بنفسه: تغيير الدور/التفعيل للمالك فقط
  if (new.role is distinct from old.role or new.is_active is distinct from old.is_active)
     and not public.is_owner() then
    raise exception 'غير مسموح بتغيير الدور أو التفعيل' using errcode = '42501';
  end if;
  new.updated_at := now();
  return new;
end $$;

create function public.protect_device() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' and not public.is_owner() then
    new.authorized := false; new.authorized_by := null; new.revoked_at := null;
    new.user_id := auth.uid();
  elsif tg_op = 'UPDATE' and not public.is_owner() then
    raise exception 'اعتماد/إلغاء الأجهزة للمالك فقط' using errcode = '42501';
  end if;
  return new;
end $$;

create function public.audit_row() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_log(actor, action, table_name, row_id, old_data, new_data)
  values (auth.uid(), tg_op, tg_table_name,
          coalesce((to_jsonb(new)->>'id'), (to_jsonb(old)->>'id')),
          case when tg_op = 'INSERT' then null else to_jsonb(old) end,
          case when tg_op = 'DELETE' then null else to_jsonb(new) end);
  return coalesce(new, old);
end $$;

-- ───────── ربط المشغّلات ─────────
do $$
declare t text;
begin
  foreach t in array array['revenues','expenses','transfers','daily_closings'] loop
    execute format('create trigger %I_no_delete before delete on public.%I for each row execute function public.block_delete()', t, t);
    execute format('create trigger %I_audit after insert or update on public.%I for each row execute function public.audit_row()', t, t);
  end loop;
  foreach t in array array['revenues','expenses','transfers'] loop
    execute format('create trigger %I_closed_day before insert or update on public.%I for each row execute function public.guard_closed_day()', t, t);
  end loop;
  foreach t in array array['revenues','expenses','transfers','daily_closings'] loop
    execute format('create trigger %I_version before update on public.%I for each row execute function public.bump_version()', t, t);
  end loop;
  foreach t in array array['profiles','user_permissions','devices','accounts','categories','app_settings','closing_reopens'] loop
    execute format('create trigger %I_audit after insert or update or delete on public.%I for each row execute function public.audit_row()', t, t);
  end loop;
end $$;

create trigger revenues_cat_kind before insert or update on public.revenues
  for each row execute function public.enforce_category_kind();
create trigger expenses_cat_kind before insert or update on public.expenses
  for each row execute function public.enforce_category_kind();
create trigger closings_protect before update on public.daily_closings
  for each row execute function public.protect_finalized_closing();
create trigger profiles_protect before update on public.profiles
  for each row execute function public.protect_profile();
create trigger devices_protect before insert or update on public.devices
  for each row execute function public.protect_device();
create trigger audit_no_update before update or delete on public.audit_log
  for each row execute function public.block_audit_mutation();
create trigger audit_no_truncate before truncate on public.audit_log
  for each statement execute function public.block_audit_mutation();

-- ───────── الصلاحيات على مستوى الجداول ─────────
revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon;

grant select on public.profiles, public.user_permissions, public.permission_catalog,
  public.devices, public.categories, public.accounts, public.revenues, public.expenses,
  public.transfers, public.daily_closings, public.audit_log, public.sync_ops,
  public.sync_conflicts, public.app_settings, public.attachments to authenticated;
grant insert on public.devices to authenticated;                      -- يسجّل جهازه غير معتمد
grant insert, update, delete on public.user_permissions, public.categories,
  public.app_settings to authenticated;                               -- المالك فقط عبر RLS
grant update on public.profiles, public.devices, public.accounts to authenticated;
grant insert on public.accounts to authenticated;
-- لا INSERT/UPDATE/DELETE مباشرة على revenues/expenses/transfers/daily_closings/audit_log:
-- الكتابة عبر دوال RPC فقط.

-- ───────── RLS ─────────
alter table public.profiles           enable row level security;
alter table public.permission_catalog enable row level security;
alter table public.user_permissions   enable row level security;
alter table public.devices            enable row level security;
alter table public.accounts           enable row level security;
alter table public.categories         enable row level security;
alter table public.revenues           enable row level security;
alter table public.expenses           enable row level security;
alter table public.transfers          enable row level security;
alter table public.attachments        enable row level security;
alter table public.daily_closings     enable row level security;
alter table public.closing_reopens    enable row level security;
alter table public.audit_log          enable row level security;
alter table public.sync_ops           enable row level security;
alter table public.sync_conflicts     enable row level security;
alter table public.app_settings       enable row level security;

create policy profiles_read  on public.profiles for select using (id = auth.uid() or public.is_owner());
create policy profiles_write on public.profiles for update using (public.is_owner()) with check (public.is_owner());

create policy catalog_read on public.permission_catalog for select using (public.is_active_user());

create policy perms_read  on public.user_permissions for select using (user_id = auth.uid() or public.is_owner());
create policy perms_ins   on public.user_permissions for insert with check (public.is_owner());
create policy perms_upd   on public.user_permissions for update using (public.is_owner()) with check (public.is_owner());
create policy perms_del   on public.user_permissions for delete using (public.is_owner());

create policy devices_read on public.devices for select using (user_id = auth.uid() or public.is_owner());
create policy devices_ins  on public.devices for insert with check (public.is_active_user());
create policy devices_upd  on public.devices for update using (public.is_owner()) with check (public.is_owner());

-- الأرصدة الافتتاحية حساسة: لا تُقرأ إلا بصلاحية الأرصدة
create policy accounts_read on public.accounts for select using (public.has_perm('balances.view'));
create policy accounts_ins  on public.accounts for insert with check (public.is_owner());
create policy accounts_upd  on public.accounts for update using (public.is_owner()) with check (public.is_owner());

create policy categories_read on public.categories for select using (public.is_active_user());
create policy categories_ins  on public.categories for insert with check (public.is_owner());
create policy categories_upd  on public.categories for update using (public.is_owner()) with check (public.is_owner());
create policy categories_del  on public.categories for delete using (public.is_owner());

create policy revenues_read on public.revenues for select using (
  public.has_perm('revenue.view_history')
  or (public.has_perm('revenue.view_today') and business_date = public.local_today()));
create policy expenses_read on public.expenses for select using (public.has_perm('expense.view'));
create policy transfers_read on public.transfers for select using (public.has_perm('balances.view'));
create policy attachments_read on public.attachments for select using (
  (entry_table = 'revenues' and exists (select 1 from public.revenues r where r.id = entry_id))
  or (entry_table = 'expenses' and exists (select 1 from public.expenses e where e.id = entry_id)));
create policy closings_read on public.daily_closings for select using (
  public.has_perm('balances.view') or public.has_perm('closing.perform'));
create policy reopens_read on public.closing_reopens for select using (public.is_owner());
create policy audit_read   on public.audit_log for select using (public.is_owner());
create policy syncops_read on public.sync_ops for select using (user_id = auth.uid() or public.is_owner());
create policy conflicts_read on public.sync_conflicts for select using (public.is_owner());

create policy settings_read on public.app_settings for select using (public.is_active_user());
create policy settings_ins  on public.app_settings for insert with check (public.is_owner());
create policy settings_upd  on public.app_settings for update using (public.is_owner()) with check (public.is_owner());

-- عرض آمن للحسابات بلا أرصدة، لنموذج الإدخال
create view public.accounts_public as
  select id, name_ar, name_en, kind from public.accounts
  where is_active and public.is_active_user();
grant select on public.accounts_public to authenticated;

-- ───────── التحقق من الجهاز ─────────
create function public.assert_device_ok(p_device uuid) returns void
language plpgsql stable security definer set search_path = '' as $$
declare d public.devices; max_days int;
begin
  select * into d from public.devices where id = p_device and user_id = auth.uid();
  if not found or not d.authorized or d.revoked_at is not null then
    raise exception 'الجهاز غير معتمد أو مُلغى' using errcode = '42501';
  end if;
  select (value #>> '{}')::int into max_days from public.app_settings where key = 'offline_max_days';
  if d.last_sync_at is not null and d.last_sync_at < now() - make_interval(days => coalesce(max_days, 7)) then
    raise exception 'تجاوز الجهاز مدة العمل دون اتصال: يلزم تسجيل الدخول والمزامنة' using errcode = '42501';
  end if;
end $$;

-- ───────── واجهات الكتابة: idempotent وبصلاحية صريحة ─────────
-- تعيد المعرّف فقط، فلا تكشف المبالغ لمن يملك صلاحية التسجيل دون الاطلاع.
create function public.add_revenue(
  p_op_id uuid, p_id uuid, p_device uuid, p_business_date date, p_occurred_at timestamptz,
  p_amount_iqd bigint, p_category uuid, p_account uuid,
  p_description text default null, p_receipt_no text default null, p_notes text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_perm('revenue.create') then
    raise exception 'لا تملك صلاحية تسجيل الإيرادات' using errcode = '42501';
  end if;
  perform public.assert_device_ok(p_device);
  if exists (select 1 from public.sync_ops where op_id = p_op_id) then
    return p_id;                                   -- إعادة إرسال: لا تكرار
  end if;
  insert into public.revenues(id, business_date, occurred_at, amount_iqd, category_id, account_id,
                              description, receipt_no, notes, created_by, device_id)
  values (p_id, p_business_date, p_occurred_at, p_amount_iqd, p_category, p_account,
          p_description, p_receipt_no, p_notes, auth.uid(), p_device);
  insert into public.sync_ops(op_id, user_id, device_id, op_type, entity_id, result)
  values (p_op_id, auth.uid(), p_device, 'add_revenue', p_id, 'applied');
  update public.devices set last_sync_at = now(), last_seen_at = now() where id = p_device;
  return p_id;
end $$;

create function public.add_expense(
  p_op_id uuid, p_id uuid, p_device uuid, p_business_date date, p_occurred_at timestamptz,
  p_amount_iqd bigint, p_category uuid, p_account uuid,
  p_description text default null, p_receipt_no text default null, p_notes text default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_perm('expense.create') then
    raise exception 'لا تملك صلاحية تسجيل المصروفات' using errcode = '42501';
  end if;
  perform public.assert_device_ok(p_device);
  if exists (select 1 from public.sync_ops where op_id = p_op_id) then
    return p_id;
  end if;
  insert into public.expenses(id, business_date, occurred_at, amount_iqd, category_id, account_id,
                              description, receipt_no, notes, created_by, device_id)
  values (p_id, p_business_date, p_occurred_at, p_amount_iqd, p_category, p_account,
          p_description, p_receipt_no, p_notes, auth.uid(), p_device);
  insert into public.sync_ops(op_id, user_id, device_id, op_type, entity_id, result)
  values (p_op_id, auth.uid(), p_device, 'add_expense', p_id, 'applied');
  update public.devices set last_sync_at = now(), last_seen_at = now() where id = p_device;
  return p_id;
end $$;

revoke all on function public.add_revenue(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text) from public, anon;
revoke all on function public.add_expense(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text) from public, anon;
grant execute on function public.add_revenue(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text) to authenticated;
grant execute on function public.add_expense(uuid,uuid,uuid,date,timestamptz,bigint,uuid,uuid,text,text,text) to authenticated;
grant execute on function public.is_active_user(), public.is_owner(), public.has_perm(text), public.local_today() to authenticated;

-- (المرحلة 2) إغلاق منافذ كانت مفتوحة افتراضياً على الكائنات المنشأة بعد أمر revoke العام
revoke all on function public.assert_device_ok(uuid) from public, anon;
revoke all on table public.accounts_public from anon;
