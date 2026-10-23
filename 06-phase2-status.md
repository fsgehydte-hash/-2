# 06 — حالة المرحلة 2

## الملفات المعدّلة/المضافة
- معدَّل: `supabase/migrations/…0002_security.sql` (إضافة revoke لـ `assert_device_ok` و`accounts_public`)، `app/pubspec.yaml` (اعتماديات المرحلة 2 فقط)، `README.md`.
- جديد (قاعدة): `tests/db/00_supabase_shim.sql`، `tests/db/rls_test.sql` (35 تأكيداً)، `scripts/run_db_tests.sh`.
- جديد (Flutter، 23 ملف dart): `lib/main.dart`، `app/` (app, providers)، `core/` (config, permissions, theme, strings ar/en, format, settings)، `data/` (Supabase + وضع عرض وهمي)، `features/` (auth, home, dashboard, settings, users)، `widgets/`، و`test/` (5 اختبارات وحدة + 7 اختبارات واجهة).
- جديد: `tests/dart_sanity.py`.

## ما تغطيه واجهة المرحلة 2
شاشة دخول RTL، قائمة رئيسية (درج للهاتف/شريط جانبي للحاسوب) تُبنى حسب الصلاحيات، لوحة تحكم تعرض إيرادات/مصروفات اليوم والصافي بحسب الصلاحية فقط، إعدادات (عربي/إنجليزي، نهاري/ليلي)، وصفحة المالك لمنح/سحب الصلاحيات وتعطيل الحسابات.
بطاقات الأرصدة والتقارير والمزامنة تظهر بـ«—» وملاحظة المرحلة؛ لا أرقام وهمية.

## قيود معروفة
- إنشاء مستخدم جديد يحتاج Edge Function بمفتاح خادم (مؤجل).
- جلسة supabase_flutter مخزّنة افتراضياً بتخزين عادي؛ التخزين الآمن في المرحلة 7.
- خط عربي مخصص (Cairo/Tajawal) والشعار الرسمي لم يُضافا (لا إنترنت).
- التعارض بين `flutter create` وملفات الاختبار: انظر README.
