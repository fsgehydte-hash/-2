import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/strings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final ctl = ref.read(settingsProvider.notifier);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text(context.t('language'), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: 'ar', label: Text('العربية')),
          ButtonSegment(value: 'en', label: Text('English')),
        ],
        selected: {settings.locale.languageCode},
        onSelectionChanged: (v) => ctl.setLocale(Locale(v.first)),
      ),
      const SizedBox(height: 24),
      Text(context.t('theme'), style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      SegmentedButton<ThemeMode>(
        segments: [
          ButtonSegment(value: ThemeMode.system, label: Text(context.t('theme_system'))),
          ButtonSegment(value: ThemeMode.light, label: Text(context.t('theme_light'))),
          ButtonSegment(value: ThemeMode.dark, label: Text(context.t('theme_dark'))),
        ],
        selected: {settings.themeMode},
        onSelectionChanged: (v) => ctl.setThemeMode(v.first),
      ),
      const SizedBox(height: 32),
      OutlinedButton.icon(
        key: const Key('signout'),
        onPressed: () => ref.read(sessionProvider.notifier).signOut(),
        icon: const Icon(Icons.logout),
        label: Text(context.t('sign_out')),
      ),
    ]);
  }
}
