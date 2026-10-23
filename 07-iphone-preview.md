# 07 — معاينة الويب من الآيفون (بدون حاسبة)

الفكرة: ترفع ملف الحزمة إلى GitHub من Safari، وخادم GitHub (Actions) يبني تطبيق Flutter للويب ويستضيفه على رابط تفتحه في Safari. لا تحتاج أي أمر.

> هذه الطريقة **لم تُجرَّب** من بيئتي (لا Flutter هنا). أول بناء قد يفشل بخطأ ترجمة؛ أرسل لي نص الخطأ وأصلحه.

## الخطوات
1. **حمّل الحزمة:** من المحادثة افتح `rayhana-web-preview.zip` واحفظها في تطبيق «الملفات». لا تضغط عليها لفك الضغط (إن فُكّت تلقائياً: اضغط على المجلد مطولاً ← ضغط).
2. **حساب GitHub:** من Safari افتح github.com ← Sign up، وأكّد بريدك.
3. **مستودع جديد:** زر + ← New repository ← الاسم `rayhana-preview` ← اختر **Public** (صفحات GitHub المجانية تتطلب مستودعاً عاماً؛ المستودع يحوي الكود وبيانات وهمية فقط، بلا أسرار) ← فعّل Add a README ← Create.
4. **ارفع الحزمة:** داخل المستودع: Add file ← Upload files ← اختر `rayhana-web-preview.zip` من «الملفات» ← Commit changes.
5. **أنشئ ملف البناء:** Add file ← Create new file ← في خانة الاسم اكتب بالضبط `.github/workflows/web-preview.yml` (الشرطة المائلة تُنشئ المجلدات) ← الصق محتوى `web-preview.yml` (مرفق، ومنسوخ في المحادثة) ← Commit.
6. **فعّل Pages:** Settings (قد تكون تحت قائمة ⋯) ← Pages ← Source: **GitHub Actions**.
7. **شغّل البناء:** تبويب Actions ← web-preview ← Run workflow (يبدأ تلقائياً أيضاً بعد الخطوة 5). ينتهي خلال ~5–10 دقائق.
8. **افتح الرابط:** `https://اسم_حسابك.github.io/rayhana-preview/` في Safari. للحفظ كتطبيق: زر المشاركة ← Add to Home Screen.

## بعد الفتح
- ستظهر شاشة دخول عربية RTL ولافتة «نسخة تجريبية ببيانات وهمية».
- الحسابات: `owner@demo.local`، `cashier@demo.local`، `viewer@demo.local`. كلمة المرور **عشوائية لكل تحميل للصفحة** وتظهر أسفل نموذج الدخول (ليست ثابتة في الكود). تحديث الصفحة يغيّرها.
- كل الأرقام وهمية. لا تُعرض أرقام حقيقية قبل ضبط Supabase والمصادقة وتشغيل اختبارات RLS.

## قراءة نتيجة البناء
- ✅ أخضر كامل: الاختبارات والتحليل نجحت والبناء نجح.
- 🟠 خطوة Analyze أو Test برتقالية/فيها ✗ مع نجاح Build: التطبيق يُبنى لكن هناك ملاحظات أو اختبارات فاشلة؛ افتح الخطوة وأرسل لي نصها.
- ❌ فشل Build: أرسل نص الخطأ.

## بديل خاص: GitHub Codespaces
إن لم ترد مستودعاً عاماً: مستودع Private ← Code ← Codespaces ← Create. في الطرفية ثبّت Flutter (`git clone https://github.com/flutter/flutter.git -b stable ~/flutter`) ثم داخل `rayhana/app`: `flutter create --platforms=web .` ثم `flutter run -d web-server --web-port 8080 --dart-define=DEMO=true`، وافتح المنفذ 8080 من تبويب Ports. الطرفية على شاشة الآيفون غير مريحة، وحدود الاستخدام المجاني تحقق منها في حسابك.

## التحول للبيانات الحقيقية لاحقاً
بعد نجاح اختبارات القاعدة على Supabase سحابي: أنشئ مشروعاً، طبّق الهجرتين، ثم نبني نسخة بـ `SUPABASE_URL` و`SUPABASE_ANON_KEY` (مفتاح عام فقط) وبلا `DEMO`.
