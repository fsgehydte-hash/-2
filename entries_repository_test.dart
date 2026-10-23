import 'package:flutter_test/flutter_test.dart';
import 'package:rayhana_app/core/permissions.dart';
import 'package:rayhana_app/core/time_util.dart';
import 'package:rayhana_app/data/demo_entries.dart';
import 'package:rayhana_app/data/entries_models.dart';

const owner = UserSession(userId: 'o', fullName: 'Owner', isOwner: true);
const cashier = UserSession(userId: 'c', fullName: 'Cashier', isOwner: false, perms: {Perm.revenueCreate, Perm.expenseCreate});
const viewerToday = UserSession(userId: 'v', fullName: 'V', isOwner: false, perms: {Perm.revenueViewToday});
const manager = UserSession(
    userId: 'm',
    fullName: 'M',
    isOwner: false,
    perms: {Perm.revenueViewHistory, Perm.expenseView});

EntryInput _in(EntryKind k, int amount, {String op = 'op1', String id = 'id1', DateTime? at, String? desc}) => EntryInput(
      id: id,
      opId: op,
      deviceId: 'd',
      kind: k,
      amountIqd: amount,
      categoryId: k == EntryKind.revenue ? 'c-sales' : 'c-goods',
      accountId: 'a-cash',
      occurredAt: at ?? nowUtc(),
      description: desc,
    );

void main() {
  late DemoEntriesRepository repo;
  final today = todayBusinessDate();
  setUp(() => repo = DemoEntriesRepository());

  test('reference numbers are sequential and typed', () async {
    expect(await repo.add(_in(EntryKind.revenue, 100, op: 'a', id: '1'), cashier), 'R-000001');
    expect(await repo.add(_in(EntryKind.revenue, 100, op: 'b', id: '2'), cashier), 'R-000002');
    expect(await repo.add(_in(EntryKind.expense, 50, op: 'c', id: '3'), cashier), 'E-000001');
  });

  test('retry with the same opId does not duplicate or double-count', () async {
    final a = await repo.add(_in(EntryKind.revenue, 1000), cashier);
    final b = await repo.add(_in(EntryKind.revenue, 1000), cashier);
    expect(b, a);
    final t = await repo.totals(today, today, owner);
    expect(t.revenue, 1000);
    expect((await repo.list(EntryKind.revenue, const EntryFilter(), owner)).length, 1);
  });

  test('totals equal the exact sum of active entries, expenses kept separate', () async {
    await repo.add(_in(EntryKind.revenue, 500000, op: 'r1', id: 'r1'), cashier);
    await repo.add(_in(EntryKind.revenue, 250000, op: 'r2', id: 'r2'), cashier);
    await repo.add(_in(EntryKind.expense, 120000, op: 'e1', id: 'e1'), cashier);
    final t = await repo.totals(today, today, owner);
    expect(t.revenue, 750000);
    expect(t.expense, 120000);
    expect(t.net, 630000);
  });

  test('create permission is required and amount must be positive', () async {
    expect(() => repo.add(_in(EntryKind.revenue, 10), viewerToday), throwsA(isA<EntryFailure>()));
    expect(() => repo.add(_in(EntryKind.revenue, 0), cashier), throwsA(isA<EntryFailure>()));
    expect(() => repo.add(_in(EntryKind.revenue, -5), cashier), throwsA(isA<EntryFailure>()));
  });

  test('future business date is rejected', () async {
    final future = nowUtc().add(const Duration(days: 3));
    expect(() => repo.add(_in(EntryKind.revenue, 10, at: future), cashier), throwsA(isA<EntryFailure>()));
  });

  test('cashier cannot read lists or totals; viewer(today) limited; manager has no net', () async {
    await repo.add(_in(EntryKind.revenue, 100, op: 'r1', id: 'r1'), cashier);
    await repo.add(_in(EntryKind.expense, 40, op: 'e1', id: 'e1'), cashier);
    expect(await repo.list(EntryKind.revenue, const EntryFilter(), cashier), isEmpty);
    final tc = await repo.totals(today, today, cashier);
    expect(tc.revenue, isNull);
    expect(tc.expense, isNull);
    final tv = await repo.totals(today, today, viewerToday);
    expect(tv.revenue, 100);
    expect(tv.expense, isNull);
    final wide = await repo.totals(shiftBusinessDate(today, -1), today, viewerToday);
    expect(wide.revenue, isNull);
    final tm = await repo.totals(today, today, manager);
    expect(tm.revenue, 100);
    expect(tm.expense, 40);
    expect(tm.net, isNull);
  });

  test('search and category filters work and recorder name is kept', () async {
    await repo.add(_in(EntryKind.expense, 10, op: 'x1', id: 'x1', desc: 'وقود'), cashier);
    await repo.add(_in(EntryKind.expense, 20, op: 'x2', id: 'x2', desc: 'صيانة'), cashier);
    final r = await repo.list(EntryKind.expense, const EntryFilter(query: 'وقود'), owner);
    expect(r.length, 1);
    expect(r.first.createdByName, 'Cashier');
    expect((await repo.list(EntryKind.expense, const EntryFilter(categoryId: 'nope'), owner)), isEmpty);
  });

  test('original creation time is preserved', () async {
    final at = DateTime.utc(2026, 1, 1, 10, 30);
    // تاريخ قديم مسموح (تسجيل متأخر) ويبقى وقته الأصلي
    await repo.add(_in(EntryKind.revenue, 5, at: at), cashier);
    final e = (await repo.list(EntryKind.revenue, const EntryFilter(), owner)).first;
    expect(e.occurredAt, at);
    expect(e.businessDate, '2026-01-01');
  });
}
