# ريحانة للتسوق المنزلي — المرحلة 2 (قاعدة البيانات الحقيقية + واجهة Flutter)

## الحالة بصراحة
- **اختُبر فعلياً:** منطق النموذج على SQLite (17) + فحوص ساكنة SQL (10) + فحص بدائي لأقواس Dart واستيراداتها (23 ملفاً).
- **كُتب ولم يُشغَّل (البيئة بلا PostgreSQL/Docker/Flutter/إنترنت):** اختبارات RLS على PostgreSQL (`tests/db/rls_test.sql`) وكود Flutter واختباراته. **لا يُعدّ أي منها ناجحاً حتى يُشغَّل على جهازك.**

## الخطة المحدّثة
المرحلة 1 (v2): `docs/08-v2-phase1.md`.

## معاينة من الآيفون
انظر `docs/07-iphone-preview.md` (GitHub Actions + Pages، بلا حاسبة).

## التشغيل
### 1) اختبار قاعدة البيانات (الأهم أولاً)
```bash
# أ) Docker فقط:
./scripts/run_db_tests.sh docker
# ب) Supabase CLI:
supabase start && ./scripts/run_db_tests.sh supabase
```
النجاح = ظهور `ALL DB TESTS PASSED`. أي `FAIL:` يعني خللاً حقيقياً يجب إصلاحه قبل متابعة الواجهة.

### 2) Flutter
```bash
cd app
flutter create --platforms=android,ios,windows,web --project-name rayhana_app .   # يولّد مجلدات المنصات (لا يمسّ lib/ ولا pubspec)
flutter pub get
flutter analyze && flutter test
flutter run -d windows --dart-define=DEMO=true          # عرض ببيانات وهمية (owner/cashier/viewer@demo.local، وكلمة المرور العشوائية تظهر على شاشة الدخول)
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
```
> بعد `flutter create` قد يُنشئ `test/widget_test.dart` افتراضياً؛ إن سأل عن الاستبدال فأبقِ ملفنا.

### 3) اختبارات بايثون (متاحة دائماً)
`./tests/run_tests.sh` و`python3 tests/dart_sanity.py`

النسخة الأصلية للمرحلة 1 محفوظة في `rayhana-phase1.zip`.
