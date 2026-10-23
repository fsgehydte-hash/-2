import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/format.dart';
import '../../core/permissions.dart';
import '../../core/strings.dart';
import '../../core/time_util.dart';
import '../../data/entries_models.dart';
import 'entry_actions.dart';

/// سجل الإيرادات أو المصروفات: الأرقام والقوائم من الخادم وبحسب الصلاحيات (RLS).
class EntriesPage extends ConsumerStatefulWidget {
  const EntriesPage({super.key, required this.kind});
  final EntryKind kind;
  @override
  ConsumerState<EntriesPage> createState() => _EntriesPageState();
}

class _EntriesPageState extends ConsumerState<EntriesPage> {
  String _period = 'today';
  String? _categoryId;
  String _q = '';
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  DateRange _range() {
    final today = todayBusinessDate();
    switch (_period) {
      case 'week':
        return DateRange(shiftBusinessDate(today, -6), today);
      case 'month':
        return DateRange(monthStart(today), today);
      default:
        return DateRange(today, today);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider).valueOrNull;
    if (s == null) return const SizedBox.shrink();
    final isRev = widget.kind == EntryKind.revenue;
    final canView = isRev ? canSeeRevenue(s) : s.can(Perm.expenseView);
    final canHistory = isRev ? s.can(Perm.revenueViewHistory) : s.can(Perm.expenseView);
    final canCreate = s.can(isRev ? Perm.revenueCreate : Perm.expenseCreate);
    final fab = canCreate
        ? FloatingActionButton.extended(
            key: const Key('add-entry'),
            onPressed: () => openEntryForm(context, ref, widget.kind),
            icon: const Icon(Icons.add),
            label: Text(context.t(isRev ? 'add_revenue' : 'add_expense')),
          )
        : null;

    if (!canView) {
      return Scaffold(
        floatingActionButton: fab,
        body: Center(
            child: Padding(padding: const EdgeInsets.all(24), child: Text(context.t('view_not_allowed')))),
      );
    }

    if (!canHistory && _period != 'today') _period = 'today';
    final range = _range();
    final filter = EntryFilter(from: range.from, to: range.to, categoryId: _categoryId, query: _q);
    final entries = ref.watch(entriesProvider(EntriesQuery(widget.kind, filter)));
    final totals = ref.watch(totalsProvider(range));
    final cats = ref.watch(categoriesProvider(widget.kind)).valueOrNull ?? const <EntryCategory>[];
    final catNames = {for (final c in cats) c.id: c.name(context.isAr)};
    final total = totals.valueOrNull == null ? null : (isRev ? totals.value!.revenue : totals.value!.expense);

    return Scaffold(
      floatingActionButton: fab,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 96), children: [
        Wrap(spacing: 8, children: [
          for (final p in [
            ('today', 'period_today'),
            if (canHistory) ('week', 'period_week'),
            if (canHistory) ('month', 'period_month'),
          ])
            ChoiceChip(
              label: Text(context.t(p.$2)),
              selected: _period == p.$1,
              onSelected: (_) => setState(() => _period = p.$1),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('search'),
              controller: _search,
              decoration: InputDecoration(
                labelText: context.t('search'),
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (v) => setState(() => _q = v.trim()),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          value: _categoryId,
          decoration: InputDecoration(labelText: context.t('category')),
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(context.t('all_categories'))),
            for (final c in cats) DropdownMenuItem<String?>(value: c.id, child: Text(c.name(context.isAr))),
          ],
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: Text(context.t('period_total')),
            trailing: Text(total == null ? '—' : formatIqd(total, arabic: context.isAr),
                key: const Key('period-total'),
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        const SizedBox(height: 8),
        entries.when(
          loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          error: (_, __) => Center(
              child: OutlinedButton(
                  onPressed: () => ref.invalidate(entriesProvider), child: Text(context.t('retry')))),
          data: (list) => list.isEmpty
              ? Padding(padding: const EdgeInsets.all(24), child: Center(child: Text(context.t('no_entries'))))
              : Column(children: [
                  for (final e in list)
                    Card(
                      child: ListTile(
                        title: Text(formatIqd(e.amountIqd, arabic: context.isAr), textDirection: TextDirection.ltr),
                        subtitle: Text([
                          catNames[e.categoryId] ?? '',
                          formatBaghdad(e.occurredAt),
                          '${context.t('ref_no')}: ${e.referenceNo}',
                          if (e.createdByName != null) '${context.t('recorded_by')}: ${e.createdByName}',
                          if (e.description != null) e.description!,
                        ].where((x) => x.isNotEmpty).join(' • ')),
                        isThreeLine: true,
                      ),
                    ),
                ]),
        ),
      ]),
    );
  }
}

bool canSeeRevenue(UserSession s) => s.canAny([Perm.revenueViewToday, Perm.revenueViewHistory]);
