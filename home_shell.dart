import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config.dart';
import '../../core/permissions.dart';
import '../../core/strings.dart';
import '../../widgets/brand_logo.dart';
import '../../data/entries_models.dart';
import '../dashboard/dashboard_page.dart';
import '../entries/entries_page.dart';
import '../settings/settings_page.dart';
import '../users/users_page.dart';
import 'placeholder_page.dart';

class _Dest {
  const _Dest(this.key, this.icon, this.page);
  final String key;
  final IconData icon;
  final Widget page;
}

List<_Dest> _destinationsFor(UserSession s) => [
      const _Dest('nav_dashboard', Icons.dashboard_outlined, DashboardPage()),
      if (s.canAny([Perm.revenueCreate, Perm.revenueViewToday, Perm.revenueViewHistory]))
        const _Dest('nav_revenues', Icons.trending_up, EntriesPage(kind: EntryKind.revenue)),
      if (s.canAny([Perm.expenseCreate, Perm.expenseView]))
        const _Dest('nav_expenses', Icons.trending_down, EntriesPage(kind: EntryKind.expense)),
      if (s.canAny([Perm.closingPerform, Perm.balancesView]))
        const _Dest('nav_closing', Icons.point_of_sale, PlaceholderPage(phaseKey: 'later_phase4')),
      if (s.canAny([Perm.reportsView, Perm.reportsExport]))
        const _Dest('nav_reports', Icons.bar_chart, PlaceholderPage(phaseKey: 'later_phase6')),
      if (s.isOwner) const _Dest('nav_users', Icons.manage_accounts_outlined, UsersPage()),
      const _Dest('nav_settings', Icons.settings_outlined, SettingsPage()),
    ];

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider).valueOrNull;
    if (s == null) return const SizedBox.shrink();
    final dests = _destinationsFor(s);
    if (_index >= dests.length) _index = 0;
    final current = dests[_index];
    final wide = MediaQuery.of(context).size.width >= 900;

    final appBar = AppBar(title: Text(context.t(current.key)));
    final page = KeyedSubtree(key: ValueKey(current.key), child: current.page);
    final body = AppConfig.demo
        ? Column(children: [
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.tertiaryContainer,
              padding: const EdgeInsets.all(8),
              child: Text(context.t('demo_banner'), textAlign: TextAlign.center),
            ),
            Expanded(child: page),
          ])
        : page;

    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            extended: true,
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [const BrandLogo(size: 56), const SizedBox(height: 8), Text(s.fullName)]),
            ),
            destinations: [
              for (final d in dests)
                NavigationRailDestination(icon: Icon(d.icon), label: Text(context.t(d.key))),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: Scaffold(appBar: appBar, body: body)),
        ]),
      );
    }
    return Scaffold(
      appBar: appBar,
      drawer: Drawer(
        child: SafeArea(
          child: ListView(children: [
            DrawerHeader(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const BrandLogo(size: 56),
                const SizedBox(height: 8),
                Text(s.fullName),
                Text(context.t(s.isOwner ? 'owner' : 'staff'), style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            for (var i = 0; i < dests.length; i++)
              ListTile(
                leading: Icon(dests[i].icon),
                title: Text(context.t(dests[i].key)),
                selected: i == _index,
                onTap: () {
                  setState(() => _index = i);
                  Navigator.of(context).pop();
                },
              ),
          ]),
        ),
      ),
      body: body,
    );
  }
}
