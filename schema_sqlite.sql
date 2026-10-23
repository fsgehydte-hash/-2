-- نموذج SQLite يعكس منطق المخطط لاختبار القواعد فعلياً (النقد، التكرار، القفل، التدقيق).
-- ليس بديلاً عن اختبار PostgreSQL/RLS الحقيقي.
create table accounts(id text primary key, kind text not null check(kind in('cash','bank','electronic')),
  opening_balance_iqd integer not null default 0 check(typeof(opening_balance_iqd)='integer' and opening_balance_iqd>=0));
create table revenues(id text primary key, business_date text not null,
  amount_iqd integer not null check(typeof(amount_iqd)='integer' and amount_iqd>0),
  account_id text not null references accounts(id), created_by text not null,
  status text not null default 'active' check(status in('active','voided')),
  version integer not null default 1);
create table expenses(id text primary key, business_date text not null,
  amount_iqd integer not null check(typeof(amount_iqd)='integer' and amount_iqd>0),
  account_id text not null references accounts(id), created_by text not null,
  status text not null default 'active' check(status in('active','voided')),
  version integer not null default 1);
create table transfers(id text primary key, business_date text not null,
  amount_iqd integer not null check(typeof(amount_iqd)='integer' and amount_iqd>0),
  from_account_id text not null references accounts(id), to_account_id text not null references accounts(id),
  status text not null default 'active', check(from_account_id<>to_account_id));
create table daily_closings(id text primary key, business_date text not null, account_id text not null,
  status text not null check(status in('provisional','final','reopened')),
  opening_cash_iqd integer not null, cash_receipts_iqd integer not null, cash_payments_iqd integer not null,
  transfers_net_iqd integer not null default 0, expected_cash_iqd integer not null,
  counted_cash_iqd integer not null, pending_ops_at_close integer not null default 0,
  check(expected_cash_iqd = opening_cash_iqd + cash_receipts_iqd - cash_payments_iqd + transfers_net_iqd));
create unique index one_open_closing on daily_closings(account_id,business_date) where status in('provisional','final');
create table audit_log(id integer primary key autoincrement, action text, table_name text, row_id text, old_data text, new_data text);
create table sync_ops(op_id text primary key, entity_id text not null, result text not null);
create table sync_conflicts(id integer primary key autoincrement, entity_id text, base_version integer, server_version integer, reason text);

-- لا حذف
create trigger rev_nodel before delete on revenues begin select raise(abort,'delete forbidden'); end;
create trigger exp_nodel before delete on expenses begin select raise(abort,'delete forbidden'); end;
create trigger clo_nodel before delete on daily_closings begin select raise(abort,'delete forbidden'); end;
-- سجل التدقيق للإضافة فقط
create trigger aud_noupd before update on audit_log begin select raise(abort,'audit append-only'); end;
create trigger aud_nodel before delete on audit_log begin select raise(abort,'audit append-only'); end;
-- قفل اليوم المغلق نهائياً
create trigger rev_lock_i before insert on revenues when exists(select 1 from daily_closings where business_date=new.business_date and status='final') begin select raise(abort,'day finalized'); end;
create trigger exp_lock_i before insert on expenses when exists(select 1 from daily_closings where business_date=new.business_date and status='final') begin select raise(abort,'day finalized'); end;
create trigger rev_lock_u before update on revenues when exists(select 1 from daily_closings where business_date in(old.business_date,new.business_date) and status='final') begin select raise(abort,'day finalized'); end;
create trigger exp_lock_u before update on expenses when exists(select 1 from daily_closings where business_date in(old.business_date,new.business_date) and status='final') begin select raise(abort,'day finalized'); end;
-- الإغلاق النهائي لا تتغير أرقامه
create trigger clo_protect before update on daily_closings when old.status='final' and
 (new.counted_cash_iqd<>old.counted_cash_iqd or new.expected_cash_iqd<>old.expected_cash_iqd or new.opening_cash_iqd<>old.opening_cash_iqd or new.status not in('final','reopened'))
 begin select raise(abort,'final closing immutable'); end;
-- إصدار + تدقيق (في SQLite لا يمكن تعديل NEW قبل الكتابة، فيُستثنى تحديث الإصدار الداخلي من التدقيق؛ في PostgreSQL مشغّل BEFORE يغني عن ذلك)
create trigger rev_ver after update on revenues begin update revenues set version=old.version+1 where id=new.id and version=old.version; end;
create trigger rev_aud_i after insert on revenues begin insert into audit_log(action,table_name,row_id,new_data) values('INSERT','revenues',new.id,new.amount_iqd); end;
create trigger rev_aud_u after update on revenues when new.version = old.version begin insert into audit_log(action,table_name,row_id,old_data,new_data) values('UPDATE','revenues',new.id,old.amount_iqd,new.amount_iqd); end;
