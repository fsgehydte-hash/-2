"""اختبارات منطق النقد والمزامنة على نموذج SQLite (تُشغَّل فعلياً)."""
import sqlite3, unittest, uuid, pathlib

SCHEMA = (pathlib.Path(__file__).parent / "schema_sqlite.sql").read_text(encoding="utf-8")

def new_db():
    db = sqlite3.connect(":memory:"); db.executescript(SCHEMA)
    db.execute("insert into accounts values('cash','cash',100000)")
    db.execute("insert into accounts values('bank','bank',0)")
    return db

class Server:
    """يطبّق منطق RPC: مفتاح op_id لمنع التكرار، و base_version لاكتشاف التعارض."""
    def __init__(self, db): self.db = db; self.online = True
    def apply(self, op):
        if not self.online: raise ConnectionError("offline")
        d = self.db
        if d.execute("select 1 from sync_ops where op_id=?", (op["op_id"],)).fetchone():
            return "duplicate"
        try:
            if op["type"] == "add_revenue":
                d.execute("insert into revenues(id,business_date,amount_iqd,account_id,created_by) values(?,?,?,?,?)",
                          (op["id"], op["date"], op["amount"], op["account"], op["user"]))
            elif op["type"] == "edit_revenue":
                sv = d.execute("select version from revenues where id=?", (op["id"],)).fetchone()[0]
                if sv != op["base_version"]:        # الحكم بإصدار الخادم لا بساعة الجهاز
                    d.execute("insert into sync_conflicts(entity_id,base_version,server_version,reason) values(?,?,?,?)",
                              (op["id"], op["base_version"], sv, "version mismatch"))
                    d.execute("insert into sync_ops values(?,?,?)", (op["op_id"], op["id"], "conflict"))
                    return "conflict"
                d.execute("update revenues set amount_iqd=? where id=?", (op["amount"], op["id"]))
            d.execute("insert into sync_ops values(?,?,?)", (op["op_id"], op["id"], "applied"))
            return "applied"
        except sqlite3.IntegrityError as e:
            d.execute("insert or ignore into sync_ops values(?,?,?)", (op["op_id"], op["id"], "rejected"))
            return "rejected: " + str(e)

class Client:
    def __init__(self, server): self.server = server; self.queue = []; self.clock_skew_days = 0
    def add_revenue(self, amount, date="2026-10-16", account="cash"):
        op = dict(op_id=str(uuid.uuid4()), type="add_revenue", id=str(uuid.uuid4()), date=date,
                  amount=amount, account=account, user="staff1")
        self.queue.append(op); return op
    def sync(self):
        results = []
        for op in list(self.queue):
            try: results.append(self.server.apply(op)); self.queue.remove(op)
            except ConnectionError: break
        return results

def expected_cash(db, date, account="cash"):
    opening = db.execute("select opening_balance_iqd from accounts where id=?", (account,)).fetchone()[0]
    r = db.execute("select coalesce(sum(amount_iqd),0) from revenues where business_date=? and account_id=? and status='active'", (date, account)).fetchone()[0]
    e = db.execute("select coalesce(sum(amount_iqd),0) from expenses where business_date=? and account_id=? and status='active'", (date, account)).fetchone()[0]
    return opening + r - e   # التحويلات لا تدخل في الإيراد/المصروف

class TestMoney(unittest.TestCase):
    def setUp(self): self.db = new_db()
    def ins(self, amt):
        self.db.execute("insert into revenues(id,business_date,amount_iqd,account_id,created_by) values(?,?,?,?,?)",
                        (str(uuid.uuid4()), "2026-10-16", amt, "cash", "u"))
    def test_rejects_float(self):
        with self.assertRaises(sqlite3.IntegrityError): self.ins(1500.5)
    def test_rejects_zero_negative_and_text(self):
        for bad in (0, -5, "12abc"):  # ملاحظة: SQLite يحوّل النص الرقمي "1000" إلى عدد قبل الفحص، فنستخدم نصاً غير رقمي
            with self.assertRaises(sqlite3.IntegrityError): self.ins(bad)
    def test_large_iqd_exact(self):
        self.ins(9_007_199_254_740_993); self.assertEqual(self.db.execute("select sum(amount_iqd) from revenues").fetchone()[0], 9_007_199_254_740_993)

class TestCashFormula(unittest.TestCase):
    def test_expected_cash(self):
        db = new_db()
        db.execute("insert into revenues(id,business_date,amount_iqd,account_id,created_by) values('r1','2026-10-16',500000,'cash','u')")
        db.execute("insert into revenues(id,business_date,amount_iqd,account_id,created_by) values('r2','2026-10-16',300000,'bank','u')")
        db.execute("insert into expenses(id,business_date,amount_iqd,account_id,created_by) values('e1','2026-10-16',120000,'cash','u')")
        db.execute("insert into transfers(id,business_date,amount_iqd,from_account_id,to_account_id) values('t1','2026-10-16',50000,'bank','cash')")
        self.assertEqual(expected_cash(db, "2026-10-16"), 100000 + 500000 - 120000)  # البنك والتحويل لا يغيّران الإيراد/المصروف
        self.assertEqual(db.execute("select count(*) from revenues").fetchone()[0], 2)
    def test_closing_formula_constraint(self):
        db = new_db()
        with self.assertRaises(sqlite3.IntegrityError):
            db.execute("insert into daily_closings values('c1','2026-10-16','cash','final',100,50,10,0,999,140,0)")
        db.execute("insert into daily_closings values('c1','2026-10-16','cash','final',100,50,10,0,140,135,0)")
    def test_voided_excluded(self):
        db = new_db()
        db.execute("insert into revenues(id,business_date,amount_iqd,account_id,created_by,status) values('r','2026-10-16',999,'cash','u','voided')")
        self.assertEqual(expected_cash(db, "2026-10-16"), 100000)

class TestImmutability(unittest.TestCase):
    def setUp(self):
        self.db = new_db()
        self.db.execute("insert into revenues(id,business_date,amount_iqd,account_id,created_by) values('r1','2026-10-16',1000,'cash','u')")
    def test_no_delete(self):
        with self.assertRaises(sqlite3.DatabaseError): self.db.execute("delete from revenues")
    def test_audit_append_only_and_populated(self):
        self.assertEqual(self.db.execute("select count(*) from audit_log").fetchone()[0], 1)
        with self.assertRaises(sqlite3.DatabaseError): self.db.execute("update audit_log set action='x'")
        with self.assertRaises(sqlite3.DatabaseError): self.db.execute("delete from audit_log")
    def test_edit_is_audited_and_versioned(self):
        self.db.execute("update revenues set amount_iqd=2000 where id='r1'")
        self.assertEqual(self.db.execute("select version from revenues where id='r1'").fetchone()[0], 2)
        self.assertEqual(self.db.execute("select count(*) from audit_log where action='UPDATE'").fetchone()[0], 1)
    def test_final_close_locks_day(self):
        self.db.execute("insert into daily_closings values('c1','2026-10-16','cash','final',0,1000,0,0,1000,1000,0)")
        with self.assertRaises(sqlite3.DatabaseError):
            self.db.execute("insert into revenues(id,business_date,amount_iqd,account_id,created_by) values('r2','2026-10-16',5,'cash','u')")
        with self.assertRaises(sqlite3.DatabaseError):
            self.db.execute("update revenues set amount_iqd=1 where id='r1'")
        with self.assertRaises(sqlite3.DatabaseError):
            self.db.execute("update daily_closings set counted_cash_iqd=1 where id='c1'")
        self.db.execute("update daily_closings set status='reopened' where id='c1'")       # إعادة الفتح مسموحة فقط كحالة
        self.db.execute("update revenues set amount_iqd=1200 where id='r1'")              # ثم يصبح التصحيح ممكناً
    def test_single_active_closing_per_day(self):
        self.db.execute("insert into daily_closings values('c1','2026-10-16','cash','provisional',0,1,0,0,1,1,2)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("insert into daily_closings values('c2','2026-10-16','cash','final',0,1,0,0,1,1,0)")

class TestOfflineSync(unittest.TestCase):
    def setUp(self):
        self.db = new_db(); self.server = Server(self.db); self.client = Client(self.server)
    def count(self): return self.db.execute("select count(*) from revenues").fetchone()[0]
    def test_offline_queue_then_sync(self):
        self.server.online = False
        for a in (1000, 2000, 3000): self.client.add_revenue(a)
        self.assertEqual(self.client.sync(), []); self.assertEqual(len(self.client.queue), 3); self.assertEqual(self.count(), 0)
        self.server.online = True
        self.assertEqual(self.client.sync(), ["applied"] * 3); self.assertEqual(self.client.queue, []); self.assertEqual(self.count(), 3)
    def test_retry_after_lost_ack_no_duplicate(self):
        op = self.client.add_revenue(5000)
        self.assertEqual(self.server.apply(op), "applied")      # وصل للخادم لكن الجهاز لم يستلم التأكيد
        self.assertEqual(self.client.sync(), ["duplicate"])     # إعادة الإرسال
        self.assertEqual(self.count(), 1)
    def test_same_entity_new_opid_still_blocked_by_pk(self):
        op = self.client.add_revenue(5000); self.server.apply(op)
        op2 = dict(op, op_id=str(uuid.uuid4()))
        self.assertTrue(self.server.apply(op2).startswith("rejected")); self.assertEqual(self.count(), 1)
    def test_conflict_decided_by_version_not_device_clock(self):
        op = self.client.add_revenue(1000); self.server.apply(op)
        self.db.execute("update revenues set amount_iqd=1500 where id=?", (op["id"],))     # موظف آخر عدّل (الإصدار 2)
        edit = dict(op_id=str(uuid.uuid4()), type="edit_revenue", id=op["id"], base_version=1, amount=9999,
                    device_time="2030-01-01T00:00:00Z")                                    # ساعة جهاز متقدمة لا تمنح أفضلية
        self.assertEqual(self.server.apply(edit), "conflict")
        self.assertEqual(self.db.execute("select amount_iqd from revenues where id=?", (op["id"],)).fetchone()[0], 1500)
        self.assertEqual(self.db.execute("select count(*) from sync_conflicts").fetchone()[0], 1)
    def test_late_offline_op_into_finalized_day_rejected_not_silent(self):
        self.db.execute("insert into daily_closings values('c1','2026-10-16','cash','final',100000,0,0,0,100000,100000,0)")
        op = self.client.add_revenue(7000, date="2026-10-16")
        self.assertTrue(self.server.apply(op).startswith("rejected")); self.assertEqual(self.count(), 0)
        self.assertEqual(self.db.execute("select result from sync_ops where op_id=?", (op["op_id"],)).fetchone()[0], "rejected")
    def test_provisional_closing_marks_pending_ops(self):
        self.server.online = False
        for a in (1000, 2000): self.client.add_revenue(a)
        pending = len(self.client.queue)
        self.db.execute("insert into daily_closings values('c1','2026-10-16','cash','provisional',100000,0,0,0,100000,100000,?)", (pending,))
        self.server.online = True; self.client.sync()
        self.assertEqual(self.db.execute("select pending_ops_at_close from daily_closings").fetchone()[0], 2)
        self.assertEqual(expected_cash(self.db, "2026-10-16"), 103000)  # المطابقة بعد المزامنة تُظهر المتوقع الجديد

if __name__ == "__main__":
    unittest.main(verbosity=2)
