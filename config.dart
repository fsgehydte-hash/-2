import 'package:flutter/foundation.dart' show kReleaseMode;

/// القيم تُمرَّر عند التشغيل: --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// لا تضع مفتاح service_role هنا أبداً.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const _demoFlag = bool.fromEnvironment('DEMO');
  // علامة صريحة لمعاينة الويب العامة ببيانات وهمية (لا تُستعمل في أي بناء حقيقي).
  static const _allowDemoInRelease = bool.fromEnvironment('ALLOW_DEMO_IN_RELEASE');

  /// وضع العرض ببيانات وهمية؛ يُرفض في بناء الإصدار ما لم تُمرَّر علامة المعاينة الصريحة.
  static bool get demo => _demoFlag && (!kReleaseMode || _allowDemoInRelease);
  static bool get hasBackend => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
