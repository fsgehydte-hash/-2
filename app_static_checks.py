"""فحوص ساكنة على كود Flutter: لا أزرار «قريباً» للمزايا المنفذة، ولا جمع مالي في الواجهة، ولا أسرار."""
import pathlib, re, unittest
APP = pathlib.Path(__file__).resolve().parent.parent / "app" / "lib"
def read(rel): return (APP / rel).read_text(encoding="utf-8")

class TestNoFakeFeatures(unittest.TestCase):
    def test_revenue_and_expense_pages_are_real(self):
        shell = read("features/home/home_shell.dart")
        for key in ("nav_revenues", "nav_expenses"):
            line = next(l for l in shell.splitlines() if key in l)
            self.assertNotIn("PlaceholderPage", line, key)
            self.assertIn("EntriesPage", line, key)
    def test_dashboard_buttons_open_the_form(self):
        dash = read("features/dashboard/dashboard_page.dart")
        self.assertNotIn("_soon", dash)
        self.assertIn("onAdd(EntryKind.revenue)", dash)
        self.assertIn("onAdd(EntryKind.expense)", dash)
    def test_no_client_side_money_summation(self):
        for f in APP.rglob("*.dart"):
            if "demo_entries" in f.name: continue   # المحاكي الوهمي يعكس منطق الخادم عمداً
            txt = f.read_text(encoding="utf-8")
            self.assertIsNone(re.search(r"fold<int>|\+= *r\[|\.reduce\(", txt), f.name)
    def test_entries_use_server_rpc(self):
        repo = read("data/entries_repository.dart")
        self.assertIn("period_totals", repo); self.assertIn("kind.rpc", repo)
        self.assertNotIn(".insert(", repo.split("class SupabaseDeviceRepository")[0])   # لا إدخال مباشر للعمليات المالية
    def test_demo_is_gated(self):
        cfg = read("core/config.dart")
        self.assertIn("kReleaseMode", cfg); self.assertIn("ALLOW_DEMO_IN_RELEASE", cfg)
    def test_no_hardcoded_passwords_or_keys(self):
        for f in APP.rglob("*.dart"):
            txt = "\n".join(l for l in f.read_text(encoding="utf-8").splitlines() if not l.lstrip().startswith("//"))  # التعليقات مستثناة
            self.assertNotRegex(txt, r"password\s*[:=]\s*'[^']{3,}'", f.name)
            self.assertNotIn("service_role", txt, f.name)
if __name__ == "__main__": unittest.main(verbosity=2)
