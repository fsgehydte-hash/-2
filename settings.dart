import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppSettings {
  const AppSettings({this.locale = const Locale('ar'), this.themeMode = ThemeMode.system});
  final Locale locale;
  final ThemeMode themeMode;
  AppSettings copyWith({Locale? locale, ThemeMode? themeMode}) =>
      AppSettings(locale: locale ?? this.locale, themeMode: themeMode ?? this.themeMode);
}

/// الحفظ الدائم للإعدادات (على الجهاز) يُضاف لاحقاً؛ حالياً تبقى طوال الجلسة.
class SettingsController extends StateNotifier<AppSettings> {
  SettingsController() : super(const AppSettings());
  void setLocale(Locale l) => state = state.copyWith(locale: l);
  void setThemeMode(ThemeMode m) => state = state.copyWith(themeMode: m);
}
