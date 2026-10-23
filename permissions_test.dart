import 'package:flutter_test/flutter_test.dart';
import 'package:rayhana_app/core/format.dart';
import 'package:rayhana_app/core/permissions.dart';
import 'package:rayhana_app/data/dashboard_repository.dart';

void main() {
  test('owner has every permission', () {
    const s = UserSession(userId: 'o', fullName: 'o', isOwner: true);
    for (final p in Perm.values) {
      expect(s.can(p), isTrue);
    }
  });

  test('create permission does not imply view permission', () {
    const s = UserSession(userId: 'u', fullName: 'u', isOwner: false, perms: {Perm.revenueCreate, Perm.expenseCreate});
    expect(s.can(Perm.revenueCreate), isTrue);
    expect(canSeeRevenueToday(s), isFalse);
    expect(s.can(Perm.expenseView), isFalse);
    expect(s.can(Perm.balancesView), isFalse);
  });

  test('net is hidden without net.view even when both totals are visible', () {
    const s = UserSession(
        userId: 'u', fullName: 'u', isOwner: false, perms: {Perm.revenueViewToday, Perm.expenseView});
    expect(computeNet(s, 100, 40), isNull);
    const s2 = UserSession(
        userId: 'u',
        fullName: 'u',
        isOwner: false,
        perms: {Perm.revenueViewToday, Perm.expenseView, Perm.netView});
    expect(computeNet(s2, 100, 40), 60);
    expect(computeNet(s2, null, 40), isNull);
  });

  test('permission codes match the database catalog', () {
    expect(Perm.fromCode('revenue.view_today'), Perm.revenueViewToday);
    expect(Perm.fromCode('unknown.code'), isNull);
    expect(Perm.values.length, 12);
  });

  test('IQD formatting is integer-only with thousands separators', () {
    expect(formatIqd(0, arabic: false), '0 IQD');
    expect(formatIqd(1250000, arabic: false), '1,250,000 IQD');
    expect(formatIqd(-4300, arabic: true), '-4,300 د.ع');
  });
}
