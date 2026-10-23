import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_shell.dart';
import 'providers.dart';

class RayhanaApp extends ConsumerWidget {
  const RayhanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final session = ref.watch(sessionProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (c) => c.t('app_name'),
      locale: settings.locale,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      home: session.when(
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (_, __) => const LoginScreen(),
        data: (s) => s == null ? const LoginScreen() : const HomeShell(),
      ),
    );
  }
}

/// تُعرض عند عدم ضبط الخادم وخارج وضع العرض.
class ConfigMissingApp extends StatelessWidget {
  const ConfigMissingApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'لم يتم ضبط الاتصال بالخادم.\nشغّل التطبيق مع --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...\nأو للعرض الوهمي: --dart-define=DEMO=true',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
}
