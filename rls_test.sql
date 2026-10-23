-- اختبارات RLS والصلاحيات والمزامنة على PostgreSQL حقيقي. بيانات تجريبية وهمية فقط.
-- التشغيل: scripts/run_db_tests.sh   (لم تُشغَّل بعد في بيئة المرحلة الأولى/الثانية: لا PostgreSQL فيها)
\set ON_ERROR_STOP on
drop schema if exists t cascade;
create schema t;
grant usage on schema t to anon, authenticated;

create function t.login(u uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claim.sub', u::text, false);
  perform set_config('request.jwt.claims', json_build_object('sub', u::text, 'role', 'authenticated')::text, false);
  execute 'set role authenticated';
end $$;

create function t.expect_error(p_name text, p_sql text, p_state text default null) returns void
language plpgsql as $$
begin
  begin
    execute p_sql;
  exception when others then
    if p_state is not null and sqlstate <> p_state then
      raise exception 'FAIL: % — wrong sqlstate % (%)', p_name, sqlstate, sqlerrm;
    end if;
    raise notice 'PASS: %', p_name;
    return;
  end;
  raise exception 'FAIL: % — no error raised', p_name;
end $$;

create function t.expect_count(p_name text, p_sql text, p_expected bigint) returns void
language plpgsql as $$
declare n bigint;
begin
  execute p_sql into n;
  if n is distinct from p_expected then
    raise exception 'FAIL: % — expected %, got %', p_name, p_expected, n;
  end if;
  raise notice 'PASS: %', p_name;
end $$;

-- ───────── تجهيز (بصلاحية المالك داخل الجلسة) ─────────
insert into auth.users(id, email) values
 ('a0000000-0000-0000-0000-000000000001','owner@test.local'),
 ('a0000000-0000-0000-0000-000000000002','cashier@test.local'),
 ('a0000000-0000-0000-0000-000000000003','viewer@test.local'),
 ('a0000000-0000-0000-0000-000000000004','manager@test.local');
insert into public.profiles(id, full_name, role) values
 ('a0000000-0000-0000-0000-000000000001','مالك تجريبي','owner'),
 ('a0000000-0000-0000-0000-000000000002','أمين صندوق تجريبي','staff'),
 ('a0000000-0000-0000-0000-000000000003','مطّلع تجريبي','staff'),
 ('a0000000-0000-0000-0000-000000000004','مدير تجريبي','staff');
insert into public.user_permissions(user_id, permission_code, granted_by) values
 ('a0000000-0000-0000-0000-000000000002','revenue.create','a0000000-0000-0000-0000-000000000001'),
 ('a0000000-0000-0000-0000-000000000002','expense.create','a0000000-0000-0000-0000-000000000001'),
 ('a0000000-0000-0000-0000-000000000003','revenue.view_today','a0000000-0000-0000-0000-000000000001'),
 ('a0000000-0000-0000-0000-000000000004','revenue.view_history','a0000000-0000-0000-0000-000000000001'),
 ('a0000000-0000-0000-0000-000000000004','expense.view','a0000000-0000-0000-0000-000000000001'),
 ('a0000000-0000-0000-0000-000000000004','balances.view','a0000000-0000-0000-0000-000000000001');

select set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001', false);  -- المالك، مع بقاء دور superuser للتجهيز
insert into public.devices(id, user_id, label, platform, authorized, authorized_by) values
 ('d0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','ok','android', true,'a0000000-0000-0000-0000-000000000001'),
 ('d0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000002','unauth','android', false, null),
 ('d0000000-0000-0000-0000-000000000003','a0000000-0000-0000-0000-000000000002','stale','android', true,'a0000000-0000-0000-0000-000000000001'),
 ('d0000000-0000-0000-0000-000000000004','a0000000-0000-0000-0000-000000000003','viewer-dev','ios', true,'a0000000-0000-0000-0000-000000000001');
insert into public.devices(id, user_id, label, platform, authorized, revoked_at) values
 ('d0000000-0000-0000-0000-000000000005','a0000000-0000-0000-0000-000000000002','revoked','android', false, now());
update public.devices set last_sync_at = now() - interval '30 days' where id = 'd0000000-0000-0000-0000-000000000003';
insert into public.accounts(id, name_ar, kind) values ('c0000000-0000-0000-0000-000000000001','صندوق تجريبي','cash');
select id as inc_cat from public.categories where kind='income'  order by sort_order limit 1 \gset
select id as exp_cat from public.categories where kind='expense' order by sort_order limit 1 \gset
\set owner   '''a0000000-0000-0000-0000-000000000001'''
\set cashier '''a0000000-0000-0000-0000-000000000002'''
\set viewer  '''a0000000-0000-0000-0000-000000000003'''
\set manager '''a0000000-0000-0000-0000-000000000004'''
\set acct    '''c0000000-0000-0000-0000-000000000001'''
\set dev_ok  '''d0000000-0000-0000-0000-000000000001'''

-- ───────── أمين الصندوق: يسجّل ولا يرى ─────────
select t.login(:cashier::uuid);
select public.add_revenue('b0000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001',:dev_ok::uuid,
  public.local_today(), now(), 150000, :'inc_cat', :acct::uuid, 'بيع تجريبي');
select t.expect_count('cashier cannot read revenues', 'select count(*) from public.revenues', 0);
select t.expect_error('cashier direct insert denied',
  format($q$insert into public.revenues(id,business_date,occurred_at,amount_iqd,category_id,account_id,created_by)
            values (gen_random_uuid(), current_date, now(), 1, %L, %L, %L)$q$, :'inc_cat', 'c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002'), '42501');
select public.add_expense('b0000000-0000-0000-0000-000000000002','e0000000-0000-0000-0000-000000000002',:dev_ok::uuid,
  public.local_today(), now(), 40000, :'exp_cat', :acct::uuid);
select t.expect_count('cashier cannot read expenses', 'select count(*) from public.expenses', 0);
select t.expect_count('cashier cannot read accounts', 'select count(*) from public.accounts', 0);
select t.expect_count('accounts_public visible without balances', 'select count(*) from public.accounts_public', 1);
select t.expect_count('cashier cannot read audit', 'select count(*) from public.audit_log', 0);
select t.expect_error('zero amount rejected',
  format($q$select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 0, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000001', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), '23514');
select t.expect_error('category kind mismatch rejected',
  format($q$select public.add_expense(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 10, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000001', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), 'P0001');
select t.expect_error('unauthorized device rejected',
  format($q$select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 10, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000002', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), '42501');
select t.expect_error('revoked device rejected',
  format($q$select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 10, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000005', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), '42501');
select t.expect_error('offline window exceeded rejected',
  format($q$select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 10, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000003', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), '42501');
-- لا رفع صلاحيات ذاتي
update public.profiles set role = 'owner' where id = :cashier::uuid;
select t.expect_error('cashier cannot grant self permission',
  $q$insert into public.user_permissions(user_id,permission_code,granted_by) values ('a0000000-0000-0000-0000-000000000002','reports.export','a0000000-0000-0000-0000-000000000002')$q$, '42501');
insert into public.devices(user_id, label, platform, authorized) values (:cashier::uuid, 'self-reg', 'android', true);
select t.expect_count('self-registered device forced unauthorized', $q$select count(*) from public.devices where label='self-reg' and authorized = false$q$, 1);
reset role;
select t.expect_count('self role escalation had no effect', $q$select count(*) from public.profiles where id='a0000000-0000-0000-0000-000000000002' and role='staff'$q$, 1);

-- منع التكرار (إعادة إرسال نفس op_id)
select t.login(:cashier::uuid);
select public.add_revenue('b0000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001',:dev_ok::uuid,
  public.local_today(), now(), 150000, :'inc_cat', :acct::uuid, 'بيع تجريبي');
reset role;
select t.expect_count('retry with same op_id creates no duplicate', $q$select count(*) from public.revenues where id='e0000000-0000-0000-0000-000000000001'$q$, 1);

-- ───────── القراءة حسب الصلاحية ─────────
insert into public.revenues(id, business_date, occurred_at, amount_iqd, category_id, account_id, created_by)
values ('e0000000-0000-0000-0000-000000000009', public.local_today() - 1, now() - interval '1 day', 90000, :'inc_cat', :acct::uuid, :cashier::uuid);
select t.login(:viewer::uuid);
select t.expect_count('viewer(view_today) sees only today', 'select count(*) from public.revenues', 1);
select t.expect_count('viewer cannot read expenses', 'select count(*) from public.expenses', 0);
select t.expect_error('viewer cannot create revenue',
  format($q$select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 10, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000004', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), '42501');
reset role;
select t.login(:manager::uuid);
select t.expect_count('manager(view_history) sees history', 'select count(*) from public.revenues', 2);
select t.expect_count('manager(expense.view) sees expenses', 'select count(*) from public.expenses', 1);
select t.expect_count('manager(balances.view) sees accounts', 'select count(*) from public.accounts', 1);
reset role;
select t.login(:owner::uuid);
select t.expect_count('owner reads audit', 'select (count(*) > 0)::int from public.audit_log', 1);
select t.expect_error('owner direct delete denied', 'delete from public.revenues', '42501');
reset role;
set role anon;
select t.expect_error('anon cannot read revenues', 'select count(*) from public.revenues', '42501');
reset role;

-- ───────── القفل والتدقيق (حتى لـ superuser) ─────────
select t.expect_error('superuser delete blocked by trigger', 'delete from public.revenues', 'P0001');
select t.expect_error('audit update blocked', 'update public.audit_log set action = ''x''', 'P0001');
select t.expect_error('audit delete blocked', 'delete from public.audit_log', 'P0001');
select t.expect_error('audit truncate blocked', 'truncate public.audit_log', 'P0001');
insert into public.daily_closings(id, business_date, account_id, status, opening_cash_iqd, cash_receipts_iqd, cash_payments_iqd, expected_cash_iqd, counted_cash_iqd, closed_by)
values ('f0000000-0000-0000-0000-000000000001', public.local_today(), :acct::uuid, 'final', 0, 0, 0, 0, 0, :owner::uuid);
select t.expect_error('closing formula check',
  format($q$insert into public.daily_closings(id,business_date,account_id,status,opening_cash_iqd,cash_receipts_iqd,cash_payments_iqd,expected_cash_iqd,counted_cash_iqd,closed_by)
            values (gen_random_uuid(), current_date - 5, %L, 'final', 100, 50, 10, 999, 0, %L)$q$, 'c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001'), '23514');
select t.expect_error('final closing immutable', $q$update public.daily_closings set counted_cash_iqd = 5 where id='f0000000-0000-0000-0000-000000000001'$q$, 'P0001');
select t.login(:cashier::uuid);
select t.expect_error('closed day rejects new revenue',
  format($q$select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 10, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000001', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), 'P0001');
reset role;
update public.daily_closings set status = 'reopened' where id = 'f0000000-0000-0000-0000-000000000001';
select t.login(:cashier::uuid);
select public.add_revenue(gen_random_uuid(), gen_random_uuid(), :dev_ok::uuid, public.local_today(), now(), 10, :'inc_cat', :acct::uuid);
reset role;

-- ───────── المرحلة 1 (v2): الرقم المرجعي، قفل الهوية، الإجماليات ─────────
select t.login(:cashier::uuid);
select t.expect_count('add_revenue returns reference number',
  format($q$select count(*) from (select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 5, %L, %L) as r) s where s.r ~ '^R-[0-9]{6}$'$q$,
         'd0000000-0000-0000-0000-000000000001', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), 1);
select t.expect_count('add_expense returns reference number',
  format($q$select count(*) from (select public.add_expense(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 5, %L, %L) as r) s where s.r ~ '^E-[0-9]{6}$'$q$,
         'd0000000-0000-0000-0000-000000000001', :'exp_cat', 'c0000000-0000-0000-0000-000000000001'), 1);
select t.expect_count('retry returns the same reference',
  format($q$select (public.add_revenue(%L, %L, %L, public.local_today(), now(), 150000, %L, %L) = public.add_revenue(%L, %L, %L, public.local_today(), now(), 150000, %L, %L))::int$q$,
         'b0000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001', :'inc_cat','c0000000-0000-0000-0000-000000000001',
         'b0000000-0000-0000-0000-000000000001','e0000000-0000-0000-0000-000000000001','d0000000-0000-0000-0000-000000000001', :'inc_cat','c0000000-0000-0000-0000-000000000001'), 1);
select t.expect_error('future business date rejected',
  format($q$select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today() + 2, now(), 10, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000001', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), 'P0001');
reset role;
select t.expect_error('creator identity locked',
  $q$update public.revenues set created_by = 'a0000000-0000-0000-0000-000000000003' where id = 'e0000000-0000-0000-0000-000000000001'$q$, 'P0001');
select t.expect_error('created_at locked',
  $q$update public.revenues set created_at = now() - interval '5 days' where id = 'e0000000-0000-0000-0000-000000000001'$q$, 'P0001');
select t.expect_error('reference number locked',
  $q$update public.revenues set reference_no = 'R-999999' where id = 'e0000000-0000-0000-0000-000000000001'$q$, 'P0001');
-- مجموع الإيرادات النشطة: 150000 + 10 + 5 اليوم، و90000 أمس
select t.login(:manager::uuid);
select t.expect_count('manager totals: revenue (history)', 'select revenue_iqd from public.period_totals(public.local_today() - 1, public.local_today())', 240015);
select t.expect_count('manager totals: expense', 'select expense_iqd from public.period_totals(public.local_today() - 1, public.local_today())', 40005);
select t.expect_count('manager without net.view gets null net', 'select (net_iqd is null)::int from public.period_totals(public.local_today(), public.local_today())', 1);
reset role;
select t.login(:viewer::uuid);
select t.expect_count('viewer(view_today) totals for today', 'select revenue_iqd from public.period_totals(public.local_today(), public.local_today())', 150015);
select t.expect_count('viewer(view_today) denied for wider range', 'select coalesce(revenue_iqd, -1) from public.period_totals(public.local_today() - 1, public.local_today())', -1);
select t.expect_count('viewer cannot see expense total', 'select coalesce(expense_iqd, -1) from public.period_totals(public.local_today(), public.local_today())', -1);
reset role;
update public.revenues set status = 'voided', voided_at = now(), voided_by = :owner::uuid, void_reason = 'اختبار الإلغاء'
 where id = 'e0000000-0000-0000-0000-000000000009';
select t.login(:manager::uuid);
select t.expect_count('voided entries excluded from totals', 'select revenue_iqd from public.period_totals(public.local_today() - 1, public.local_today())', 150015);
reset role;

-- ───────── تعطيل المستخدم يسري فوراً ─────────
select t.login(:owner::uuid);
update public.profiles set is_active = false where id = :cashier::uuid;
reset role;
select t.login(:cashier::uuid);
select t.expect_error('deactivated user cannot create',
  format($q$select public.add_revenue(gen_random_uuid(), gen_random_uuid(), %L, public.local_today(), now(), 10, %L, %L)$q$,
         'd0000000-0000-0000-0000-000000000001', :'inc_cat', 'c0000000-0000-0000-0000-000000000001'), '42501');
reset role;
select t.expect_count('every public table has RLS', $q$select count(*) from pg_tables where schemaname='public' and not rowsecurity$q$, 0);
\echo ALL DB TESTS PASSED
