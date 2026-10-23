"""فحوص ساكنة على ملفات PostgreSQL (لا تغني عن تشغيلها على قاعدة حقيقية)."""
import pathlib, re, unittest
ROOT = pathlib.Path(__file__).resolve().parent.parent
SQL = "\n".join(p.read_text(encoding="utf-8") for p in sorted((ROOT/"supabase/migrations").glob("*.sql")))
TABLES = re.findall(r"create table public\.(\w+)", SQL)

class TestStaticSQL(unittest.TestCase):
    def test_tables_found(self): self.assertGreaterEqual(len(TABLES), 15)
    def test_rls_enabled_on_every_table(self):
        for t in TABLES:
            self.assertRegex(SQL, rf"alter table public\.{t}\s+enable row level security", f"RLS مفقود على {t}")
    def test_no_float_or_money_types(self):
        self.assertIsNone(re.search(r"\b(real|double precision|float\d*|money|numeric\(\d+,\s*[1-9])\b", SQL, re.I))
    def test_money_columns_are_bigint_iqd(self):
        for col, typ in re.findall(r"(\w+_iqd)\s+(\w+)", SQL):
            self.assertEqual(typ, "bigint", col)
    def test_security_definer_sets_search_path(self):
        for m in re.finditer(r"create function[^;]*?security definer[^;]*?\$\$", SQL, re.S):
            self.assertIn("search_path", m.group(0))
    def test_no_direct_write_policies_on_financial_tables(self):
        for t in ("revenues","expenses","transfers","daily_closings","audit_log"):
            self.assertIsNone(re.search(rf"create policy \w+ on public\.{t} for (insert|update|delete|all)", SQL), t)
            self.assertNotRegex(SQL, rf"grant\s+(insert|update|delete)[^;]*public\.{t}\b[^;]*to authenticated")
    def test_no_delete_and_audit_triggers_present(self):
        for t in ("revenues","expenses","transfers","daily_closings"):
            self.assertIn("block_delete", SQL); self.assertIn("audit_row", SQL)
        self.assertIn("audit_no_update", SQL); self.assertIn("audit_no_truncate", SQL)
    def test_rpc_checks_permission_and_idempotency(self):
        for fn, perm in (("add_revenue","revenue.create"),("add_expense","expense.create")):
            body = re.search(rf"create function public\.{fn}\(.*?\$\$;?\s*(?=create|revoke)", SQL, re.S).group(0)
            self.assertIn(f"has_perm('{perm}')", body); self.assertIn("sync_ops", body); self.assertIn("assert_device_ok", body)
    def test_no_secrets_in_repo(self):
        for p in ROOT.rglob("*"):
            if p.is_file() and p.suffix in {".dart",".yaml",".toml",".sql",".example",".md",".py"} and p.name != "static_sql_checks.py":
                self.assertIsNone(re.search(r"service_role\s*[:=]\s*['\"]?eyJ|SUPABASE_SERVICE_ROLE_KEY\s*=\s*\S+", p.read_text(encoding="utf-8", errors="ignore")), str(p))
    def test_guc_bypass_not_used(self):
        self.assertNotIn("set_config", SQL); self.assertNotIn("correction_mode", SQL)

if __name__ == "__main__": unittest.main(verbosity=2)
