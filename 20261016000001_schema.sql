-- ريحانة للتسوق المنزلي — المخطط الأساسي (PostgreSQL / Supabase)
-- المبالغ: bigint بالدينار العراقي (وحدة صحيحة)، ولا أنواع عشرية عائمة إطلاقاً.
create extension if not exists pgcrypto;

-- ───────── المستخدمون والصلاحيات ─────────
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete restrict,
  full_name   text not null check (length(trim(full_name)) > 0),
  role        text not null default 'staff' check (role in ('owner','staff')),
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.permission_catalog (
  code           text primary key,
  description_ar text not null
);

create table public.user_permissions (
  user_id         uuid not null references public.profiles(id) on delete cascade,
  permission_code text not null references public.permission_catalog(code),
  granted_by      uuid not null references public.profiles(id),
  granted_at      timestamptz not null default now(),
  primary key (user_id, permission_code)
);

create table public.devices (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles(id),
  label         text not null,
  platform      text not null check (platform in ('ios','android','windows','web')),
  authorized    boolean not null default false,
  authorized_by uuid references public.profiles(id),
  revoked_at    timestamptz,
  last_seen_at  timestamptz,
  last_sync_at  timestamptz,
  created_at    timestamptz not null default now(),
  check (revoked_at is null or authorized = false)
);

-- ───────── الحسابات والفئات ─────────
create table public.accounts (
  id                  uuid primary key default gen_random_uuid(),
  name_ar             text not null,
  name_en             text,
  kind                text not null check (kind in ('cash','bank','electronic')),
  opening_balance_iqd bigint not null default 0 check (opening_balance_iqd >= 0),
  is_active           boolean not null default true,
  created_at          timestamptz not null default now()
);

create table public.categories (
  id         uuid primary key default gen_random_uuid(),
  kind       text not null check (kind in ('income','expense')),
  name_ar    text not null,
  name_en    text,
  color      text check (color ~ '^#[0-9A-Fa-f]{6}$'),
  sort_order int  not null default 0,
  is_active  boolean not null default true,
  unique (kind, name_ar)
);

-- ───────── العمليات المالية (المعرّف يولَّد على الجهاز لمنع التكرار) ─────────
create table public.revenues (
  id                uuid primary key,
  business_date     date not null,
  occurred_at       timestamptz not null,
  amount_iqd        bigint not null check (amount_iqd > 0),
  category_id       uuid not null references public.categories(id),
  account_id        uuid not null references public.accounts(id),
  description       text,
  receipt_no        text,
  notes             text,
  created_by        uuid not null references public.profiles(id),
  device_id         uuid references public.devices(id),
  status            text not null default 'active' check (status in ('active','voided')),
  voided_at         timestamptz,
  voided_by         uuid references public.profiles(id),
  void_reason       text,
  version           bigint not null default 1,
  created_at        timestamptz not null default now(),
  server_updated_at timestamptz not null default now(),
  check (status = 'active' or (voided_at is not null and voided_by is not null and void_reason is not null))
);

create table public.expenses (
  id                uuid primary key,
  business_date     date not null,
  occurred_at       timestamptz not null,
  amount_iqd        bigint not null check (amount_iqd > 0),
  category_id       uuid not null references public.categories(id),
  account_id        uuid not null references public.accounts(id),
  description       text,
  receipt_no        text,
  notes             text,
  created_by        uuid not null references public.profiles(id),
  device_id         uuid references public.devices(id),
  status            text not null default 'active' check (status in ('active','voided')),
  voided_at         timestamptz,
  voided_by         uuid references public.profiles(id),
  void_reason       text,
  version           bigint not null default 1,
  created_at        timestamptz not null default now(),
  server_updated_at timestamptz not null default now(),
  check (status = 'active' or (voided_at is not null and voided_by is not null and void_reason is not null))
);

-- التحويل بين الصناديق ليس إيراداً ولا مصروفاً
create table public.transfers (
  id              uuid primary key,
  business_date   date not null,
  occurred_at     timestamptz not null,
  amount_iqd      bigint not null check (amount_iqd > 0),
  from_account_id uuid not null references public.accounts(id),
  to_account_id   uuid not null references public.accounts(id),
  note            text,
  created_by      uuid not null references public.profiles(id),
  status          text not null default 'active' check (status in ('active','voided')),
  version         bigint not null default 1,
  created_at      timestamptz not null default now(),
  check (from_account_id <> to_account_id)
);

create table public.attachments (
  id           uuid primary key default gen_random_uuid(),
  entry_table  text not null check (entry_table in ('revenues','expenses')),
  entry_id     uuid not null,
  storage_path text not null,
  created_by   uuid not null references public.profiles(id),
  created_at   timestamptz not null default now()
);

-- ───────── الإغلاق اليومي ─────────
create table public.daily_closings (
  id                   uuid primary key,
  business_date        date not null,
  account_id           uuid not null references public.accounts(id),
  status               text not null check (status in ('provisional','final','reopened')),
  opening_cash_iqd     bigint not null check (opening_cash_iqd >= 0),
  cash_receipts_iqd    bigint not null check (cash_receipts_iqd >= 0),
  cash_payments_iqd    bigint not null check (cash_payments_iqd >= 0),
  transfers_net_iqd    bigint not null default 0,
  expected_cash_iqd    bigint not null,
  counted_cash_iqd     bigint not null check (counted_cash_iqd >= 0),
  difference_iqd       bigint generated always as (counted_cash_iqd - expected_cash_iqd) stored,
  pending_ops_at_close int not null default 0 check (pending_ops_at_close >= 0),
  closed_by            uuid not null references public.profiles(id),
  closed_at            timestamptz not null default now(),
  note                 text,
  version              bigint not null default 1,
  -- المعادلة: الافتتاحي + المقبوضات النقدية - المدفوعات النقدية (+ صافي التحويلات) = المتوقع
  check (expected_cash_iqd = opening_cash_iqd + cash_receipts_iqd - cash_payments_iqd + transfers_net_iqd)
);
create unique index daily_closings_one_open_per_day
  on public.daily_closings (account_id, business_date) where status in ('provisional','final');

create table public.closing_reopens (
  id          uuid primary key default gen_random_uuid(),
  closing_id  uuid not null references public.daily_closings(id),
  reopened_by uuid not null references public.profiles(id),
  approved_by uuid not null references public.profiles(id),
  reason      text not null check (length(trim(reason)) >= 5),
  reopened_at timestamptz not null default now()
);

-- ───────── التدقيق والمزامنة والإعدادات ─────────
create table public.audit_log (
  id         bigint generated always as identity primary key,
  at         timestamptz not null default now(),
  actor      uuid,
  action     text not null,
  table_name text not null,
  row_id     text,
  old_data   jsonb,
  new_data   jsonb
);

create table public.sync_ops (
  op_id      uuid primary key,              -- مفتاح منع التكرار
  user_id    uuid not null references public.profiles(id),
  device_id  uuid references public.devices(id),
  op_type    text not null,
  entity_id  uuid not null,
  result     text not null check (result in ('applied','conflict','rejected')),
  detail     text,
  applied_at timestamptz not null default now()
);

create table public.sync_conflicts (
  id             uuid primary key default gen_random_uuid(),
  entity_table   text not null,
  entity_id      uuid not null,
  op_id          uuid references public.sync_ops(op_id),
  base_version   bigint,
  server_version bigint,
  client_payload jsonb not null,
  reason         text not null,
  status         text not null default 'open' check (status in ('open','resolved_server','resolved_client')),
  resolved_by    uuid references public.profiles(id),
  resolved_at    timestamptz,
  created_at     timestamptz not null default now()
);

create table public.app_settings (
  key        text primary key,
  value      jsonb not null,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now()
);

-- ───────── فهارس ─────────
create index revenues_date_idx   on public.revenues (business_date) where status = 'active';
create index revenues_cat_idx    on public.revenues (category_id);
create index revenues_acct_idx   on public.revenues (account_id, business_date);
create index expenses_date_idx   on public.expenses (business_date) where status = 'active';
create index expenses_cat_idx    on public.expenses (category_id);
create index expenses_acct_idx   on public.expenses (account_id, business_date);
create index audit_table_row_idx on public.audit_log (table_name, row_id);
create index devices_user_idx    on public.devices (user_id);

-- ───────── بيانات أولية ─────────
insert into public.permission_catalog(code, description_ar) values
 ('revenue.view_today','مشاهدة إيرادات اليوم'),
 ('revenue.view_history','مشاهدة الإيرادات التاريخية'),
 ('expense.view','مشاهدة المصروفات'),
 ('balances.view','مشاهدة الأرصدة'),
 ('net.view','مشاهدة صافي الإيرادات'),
 ('reports.view','مشاهدة التقارير'),
 ('revenue.create','تسجيل الإيرادات'),
 ('expense.create','تسجيل المصروفات'),
 ('entry.edit','تعديل العمليات'),
 ('adjustment.approve','اعتماد التسويات'),
 ('closing.perform','إجراء الإغلاق اليومي'),
 ('reports.export','تصدير التقارير');

insert into public.app_settings(key, value) values
 ('offline_max_days', '7'),
 ('timezone', '"Asia/Baghdad"'),
 ('currency', '"IQD"');

insert into public.categories(kind, name_ar, name_en, sort_order) values
 ('income','مبيعات','Sales',1),
 ('income','إيرادات أخرى','Other income',99),
 ('expense','شراء البضائع','Goods purchase',1),
 ('expense','الرواتب والأجور','Salaries',2),
 ('expense','الإيجار','Rent',3),
 ('expense','الكهرباء والماء','Utilities',4),
 ('expense','النقل والتوصيل','Transport',5),
 ('expense','الصيانة','Maintenance',6),
 ('expense','مواد التعبئة والتغليف','Packaging',7),
 ('expense','مصروفات أخرى','Other expenses',99);
