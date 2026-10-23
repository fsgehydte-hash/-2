import '../core/permissions.dart';

/// null = غير مسموح للمستخدم أو لا بيانات. الأرقام تأتي من إجماليات الخادم (period_totals)، لا من الواجهة.
class DashboardData {
  const DashboardData({this.revenueToday, this.expenseToday, this.netToday});
  final int? revenueToday;
  final int? expenseToday;
  final int? netToday;
}

int? computeNet(UserSession s, int? revenue, int? expense) =>
    (s.can(Perm.netView) && revenue != null && expense != null) ? revenue - expense : null;

bool canSeeRevenueToday(UserSession s) => s.canAny([Perm.revenueViewToday, Perm.revenueViewHistory]);
