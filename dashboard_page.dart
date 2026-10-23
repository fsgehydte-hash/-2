import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/dashboard_repository.dart';
import '../../data/entries_models.dart';
import '../entries/entry_actions.dart';
import '../../widgets/metric_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider).valueOrNull;
    if (s == null) return const SizedBox.shrink();
    final data = ref.watch(dashboardProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(context.t('load_error')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => ref.invalidate(dashboardProvider), child: Text(context.t('retry'))),
        ]),
      ),
      data: (d) => _Body(session: s, data: d, onAdd: (k) => openEntryForm(context, ref, k)),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.session, required this.data, required this.onAdd});
  final UserSession session;
  final DashboardData data;
  final void Function(EntryKind) onAdd;

  String _money(BuildContext c, int? v) => v == null ? '—' : formatIqd(v, arabic: c.isAr);

  List<Widget> _cards(BuildContext c) {
    final s = session;
    return [
      if (canSeeRevenueToday(s))
        MetricCard(
            title: c.t('today_revenue'),
            value: _money(c, data.revenueToday),
            icon: Icons.trending_up,
            color: Brand.green),
      if (s.can(Perm.expenseView))
        MetricCard(
            title: c.t('today_expense'),
            value: _money(c, data.expenseToday),
            icon: Icons.trending_down,
            color: Brand.expense),
      if (s.can(Perm.netView) && data.netToday != null)
        MetricCard(
            title: c.t('net_revenue'),
            value: _money(c, data.netToday),
            icon: Icons.account_balance_wallet_outlined,
            color: Brand.ink),
      if (s.can(Perm.balancesView)) ...[
        for (final k in ['opening_cash', 'expected_cash', 'counted_cash', 'cash_difference'])
          MetricCard(title: c.t(k), value: '—', icon: Icons.savings_outlined, color: Brand.ink, note: c.t('later_phase4')),
      ],
      if (s.canAny([Perm.reportsView]))
        MetricCard(
            title: c.t('period_summary'),
            value: '—',
            icon: Icons.bar_chart,
            color: Brand.ink,
            note: c.t('later_phase6')),
      MetricCard(
          title: c.t('sync_status'),
          value: '—',
          icon: Icons.sync,
          color: Brand.ink,
          note: c.t('sync_not_ready')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    final hasFinancial = canSeeRevenueToday(s) || s.canAny([Perm.expenseView, Perm.balancesView, Perm.reportsView]);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      final cols = w >= 900 ? 3 : (w >= 560 ? 2 : 1);
      const gap = 12.0;
      final cardW = (w - 32 - gap * (cols - 1)) / cols;
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (s.canAny([Perm.revenueCreate, Perm.expenseCreate])) ...[
          Wrap(spacing: gap, runSpacing: gap, children: [
            if (s.can(Perm.revenueCreate))
              SizedBox(
                width: cardW,
                child: FilledButton.icon(
                  key: const Key('dash-add-revenue'),
                  onPressed: () => onAdd(EntryKind.revenue),
                  icon: const Icon(Icons.add),
                  label: Text(context.t('add_revenue')),
                ),
              ),
            if (s.can(Perm.expenseCreate))
              SizedBox(
                width: cardW,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Brand.expense),
                  key: const Key('dash-add-expense'),
                  onPressed: () => onAdd(EntryKind.expense),
                  icon: const Icon(Icons.remove),
                  label: Text(context.t('add_expense')),
                ),
              ),
          ]),
          const SizedBox(height: 16),
        ],
        if (!hasFinancial)
          Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(context.t('no_dashboard_perm'))),
        Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final card in _cards(context)) SizedBox(width: cardW, child: card)],
        ),
      ]);
    });
  }
}
