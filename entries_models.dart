import '../core/time_util.dart';

enum EntryKind { revenue, expense }

extension EntryKindX on EntryKind {
  String get table => this == EntryKind.revenue ? 'revenues' : 'expenses';
  String get rpc => this == EntryKind.revenue ? 'add_revenue' : 'add_expense';
  String get categoryKind => this == EntryKind.revenue ? 'income' : 'expense';
}

class EntryCategory {
  const EntryCategory({required this.id, required this.nameAr, this.nameEn});
  final String id;
  final String nameAr;
  final String? nameEn;
  String name(bool arabic) => (arabic || nameEn == null) ? nameAr : nameEn!;
}

class EntryAccount {
  const EntryAccount({required this.id, required this.nameAr, this.nameEn, required this.kind});
  final String id;
  final String nameAr;
  final String? nameEn;
  final String kind; // cash | bank | electronic
  String name(bool arabic) => (arabic || nameEn == null) ? nameAr : nameEn!;
}

class EntryInput {
  const EntryInput({
    required this.id,
    required this.opId,
    required this.deviceId,
    required this.kind,
    required this.amountIqd,
    required this.categoryId,
    required this.accountId,
    required this.occurredAt,
    this.description,
    this.receiptNo,
    this.notes,
  });
  final String id;
  final String opId;
  final String deviceId;
  final EntryKind kind;
  final int amountIqd;
  final String categoryId;
  final String accountId;
  final DateTime occurredAt; // UTC
  final String? description;
  final String? receiptNo;
  final String? notes;
  String get businessDate => businessDateOf(occurredAt);
}

class Entry {
  const Entry({
    required this.id,
    required this.referenceNo,
    required this.amountIqd,
    required this.occurredAt,
    required this.businessDate,
    required this.categoryId,
    required this.accountId,
    this.description,
    this.receiptNo,
    this.createdByName,
  });
  final String id;
  final String referenceNo;
  final int amountIqd;
  final DateTime occurredAt;
  final String businessDate;
  final String categoryId;
  final String accountId;
  final String? description;
  final String? receiptNo;
  final String? createdByName;
}

class EntryFilter {
  const EntryFilter({this.from, this.to, this.categoryId, this.accountId, this.query});
  final String? from;
  final String? to;
  final String? categoryId;
  final String? accountId;
  final String? query;

  @override
  bool operator ==(Object other) =>
      other is EntryFilter &&
      other.from == from &&
      other.to == to &&
      other.categoryId == categoryId &&
      other.accountId == accountId &&
      other.query == query;

  @override
  int get hashCode => Object.hash(from, to, categoryId, accountId, query);
}

class EntriesQuery {
  const EntriesQuery(this.kind, this.filter);
  final EntryKind kind;
  final EntryFilter filter;
  @override
  bool operator ==(Object other) => other is EntriesQuery && other.kind == kind && other.filter == filter;
  @override
  int get hashCode => Object.hash(kind, filter);
}

class DateRange {
  const DateRange(this.from, this.to);
  final String from;
  final String to;
  @override
  bool operator ==(Object other) => other is DateRange && other.from == from && other.to == to;
  @override
  int get hashCode => Object.hash(from, to);
}

/// null = غير مسموح للمستخدم (يحدده الخادم).
class PeriodTotals {
  const PeriodTotals({this.revenue, this.expense, this.net});
  final int? revenue;
  final int? expense;
  final int? net;
}

class DeviceState {
  const DeviceState(this.id, this.authorized);
  final String id;
  final bool authorized;
}

/// [key] مفتاح نص: err_forbidden | err_amount | err_rejected | err_server | err_network | err_device_pending
class EntryFailure implements Exception {
  EntryFailure(this.key, [this.detail]);
  final String key;
  final String? detail;
}
