import '../core/permissions.dart';
import '../core/time_util.dart';
import 'dashboard_repository.dart';
import 'entries_models.dart';
import 'entries_repository.dart';

/// تنفيذ وهمي في الذاكرة بنفس قواعد الخادم (الصلاحيات، منع التكرار، الرقم المرجعي، الإجماليات).
/// يبدأ فارغاً: لا أرقام جاهزة. للعرض والاختبار فقط.
class _Rec {
  _Rec(this.entry, this.kind, this.opId, this.creatorId);
  final Entry entry;
  final EntryKind kind;
  final String opId;
  final String creatorId;
}

class DemoEntriesRepository implements EntriesRepository {
  final List<_Rec> _recs = [];
  int _rev = 0;
  int _exp = 0;

  static const _revCats = [
    EntryCategory(id: 'c-sales', nameAr: 'مبيعات', nameEn: 'Sales'),
    EntryCategory(id: 'c-other-inc', nameAr: 'إيرادات أخرى', nameEn: 'Other income'),
  ];
  static const _expCats = [
    EntryCategory(id: 'c-goods', nameAr: 'شراء البضائع', nameEn: 'Goods purchase'),
    EntryCategory(id: 'c-transport', nameAr: 'النقل والتوصيل', nameEn: 'Transport'),
    EntryCategory(id: 'c-other-exp', nameAr: 'مصروفات أخرى', nameEn: 'Other expenses'),
  ];
  static const _accounts = [
    EntryAccount(id: 'a-cash', nameAr: 'نقداً', nameEn: 'Cash', kind: 'cash'),
    EntryAccount(id: 'a-electronic', nameAr: 'إلكتروني', nameEn: 'Electronic', kind: 'electronic'),
  ];

  @override
  Future<List<EntryCategory>> categories(EntryKind kind) async =>
      kind == EntryKind.revenue ? _revCats : _expCats;

  @override
  Future<List<EntryAccount>> accounts() async => _accounts;

  @override
  Future<String> add(EntryInput i, UserSession s) async {
    final perm = i.kind == EntryKind.revenue ? Perm.revenueCreate : Perm.expenseCreate;
    if (!s.can(perm)) throw EntryFailure('err_forbidden');
    for (final r in _recs) {
      if (r.opId == i.opId) return r.entry.referenceNo; // إعادة إرسال: لا تكرار
    }
    if (i.amountIqd <= 0) throw EntryFailure('err_amount');
    if (i.businessDate.compareTo(todayBusinessDate()) > 0) {
      throw EntryFailure('err_rejected', 'لا يجوز تسجيل عملية بتاريخ مستقبلي');
    }
    final ref = i.kind == EntryKind.revenue
        ? 'R-${(++_rev).toString().padLeft(6, '0')}'
        : 'E-${(++_exp).toString().padLeft(6, '0')}';
    _recs.add(_Rec(
      Entry(
        id: i.id,
        referenceNo: ref,
        amountIqd: i.amountIqd,
        occurredAt: i.occurredAt,
        businessDate: i.businessDate,
        categoryId: i.categoryId,
        accountId: i.accountId,
        description: i.description,
        receiptNo: i.receiptNo,
        createdByName: s.fullName,
      ),
      i.kind,
      i.opId,
      s.userId,
    ));
    return ref;
  }

  bool _canViewKind(EntryKind k, UserSession s, {required String from, required String to}) {
    if (k == EntryKind.expense) return s.can(Perm.expenseView);
    final today = todayBusinessDate();
    return s.can(Perm.revenueViewHistory) || (s.can(Perm.revenueViewToday) && from == today && to == today);
  }

  @override
  Future<List<Entry>> list(EntryKind kind, EntryFilter f, UserSession s) async {
    final today = todayBusinessDate();
    final out = <Entry>[];
    for (final r in _recs) {
      if (r.kind != kind) continue;
      final e = r.entry;
      // نفس سياسة RLS: مشاهدة اليوم فقط أو التاريخ كله
      final visible = kind == EntryKind.expense
          ? s.can(Perm.expenseView)
          : (s.can(Perm.revenueViewHistory) || (s.can(Perm.revenueViewToday) && e.businessDate == today));
      if (!visible) continue;
      if (f.from != null && e.businessDate.compareTo(f.from!) < 0) continue;
      if (f.to != null && e.businessDate.compareTo(f.to!) > 0) continue;
      if (f.categoryId != null && e.categoryId != f.categoryId) continue;
      if (f.accountId != null && e.accountId != f.accountId) continue;
      final q = f.query?.trim().toLowerCase();
      if (q != null && q.isNotEmpty) {
        final hay = '${e.description ?? ''} ${e.receiptNo ?? ''} ${e.referenceNo}'.toLowerCase();
        if (!hay.contains(q)) continue;
      }
      out.add(e);
    }
    out.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return out;
  }

  @override
  Future<PeriodTotals> totals(String from, String to, UserSession s) async {
    int? rev;
    int? exp;
    if (_canViewKind(EntryKind.revenue, s, from: from, to: to)) {
      rev = _sum(EntryKind.revenue, from, to);
    }
    if (_canViewKind(EntryKind.expense, s, from: from, to: to)) {
      exp = _sum(EntryKind.expense, from, to);
    }
    return PeriodTotals(revenue: rev, expense: exp, net: computeNet(s, rev, exp));
  }

  int _sum(EntryKind k, String from, String to) {
    var t = 0;
    for (final r in _recs) {
      if (r.kind == k && r.entry.businessDate.compareTo(from) >= 0 && r.entry.businessDate.compareTo(to) <= 0) {
        t += r.entry.amountIqd;
      }
    }
    return t;
  }
}

class DemoDeviceRepository implements DeviceRepository {
  @override
  Future<DeviceState> ensure(UserSession s) async => const DeviceState('demo-device', true);
}
