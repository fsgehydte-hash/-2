/// رموز الصلاحيات مطابقة لجدول permission_catalog في قاعدة البيانات.
enum Perm {
  revenueViewToday('revenue.view_today'),
  revenueViewHistory('revenue.view_history'),
  expenseView('expense.view'),
  balancesView('balances.view'),
  netView('net.view'),
  reportsView('reports.view'),
  revenueCreate('revenue.create'),
  expenseCreate('expense.create'),
  entryEdit('entry.edit'),
  adjustmentApprove('adjustment.approve'),
  closingPerform('closing.perform'),
  reportsExport('reports.export');

  const Perm(this.code);
  final String code;

  static Perm? fromCode(String code) {
    for (final p in Perm.values) {
      if (p.code == code) return p;
    }
    return null;
  }
}

/// جلسة المستخدم. الواجهة تستعملها لإخفاء ما لا يحق له فقط؛ الحماية الفعلية في الخادم (RLS).
class UserSession {
  const UserSession({
    required this.userId,
    required this.fullName,
    required this.isOwner,
    this.perms = const {},
  });

  final String userId;
  final String fullName;
  final bool isOwner;
  final Set<Perm> perms;

  bool can(Perm p) => isOwner || perms.contains(p);
  bool canAny(Iterable<Perm> ps) => ps.any(can);
}
