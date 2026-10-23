# 02 — قاعدة البيانات
الملفات: `supabase/migrations/20261016000001_schema.sql` (الجداول) و`…0002_security.sql` (الأمان).

## الجداول وعلاقاتها
- `profiles` (id → auth.users، role: owner|staff، is_active)
- `permission_catalog` ← `user_permissions` (user_id, permission_code) — 12 صلاحية مستقلة
- `devices` (user_id، authorized، revoked_at، last_sync_at)
- `accounts` (cash|bank|electronic)، `categories` (income|expense)
- `revenues`, `expenses` (id يولَّد على الجهاز، amount_iqd bigint > 0، status active|voided، version)
- `transfers` (بين حسابين، لا تُحتسب إيراداً/مصروفاً)، `attachments`
- `daily_closings` (provisional|final|reopened) + `closing_reopens` (سبب + معتمِد)
- `audit_log` (إضافة فقط)، `sync_ops` (op_id = مفتاح منع التكرار)، `sync_conflicts`، `app_settings`

## القيود الأهم
- `CHECK amount_iqd > 0` ولا أنواع عشرية.
- `CHECK expected = opening + receipts - payments + transfers_net` في الإغلاق؛ `difference_iqd` عمود مولَّد.
- فهرس فريد: إغلاق واحد فعّال لكل (حساب، يوم).
- مشغّلات: منع الحذف، تدقيق تلقائي، رفع `version`، قفل اليوم المغلق نهائياً، تطابق نوع الفئة، حماية الإغلاق النهائي، منع رفع الدور ذاتياً، منع تعديل التدقيق.

## الاستعادة
النسخ الاحتياطي واستعادته يُنفَّذان ويُختبران في المرحلة 7؛ المقترح: نسخ يومي مجدول (pg_dump مشفّر خارج المنصة) + PITR إن توفر في الخطة. لم يُنفَّذ بعد.
