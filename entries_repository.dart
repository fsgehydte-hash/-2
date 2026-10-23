import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/idgen.dart';
import '../core/permissions.dart';
import 'entries_models.dart';

abstract class EntriesRepository {
  Future<List<EntryCategory>> categories(EntryKind kind);
  Future<List<EntryAccount>> accounts();

  /// يرجع الرقم المرجعي الصادر من الخادم. إعادة الاستدعاء بنفس opId لا تنشئ عملية ثانية.
  Future<String> add(EntryInput input, UserSession s);
  Future<List<Entry>> list(EntryKind kind, EntryFilter filter, UserSession s);
  Future<PeriodTotals> totals(String from, String to, UserSession s);
}

abstract class DeviceRepository {
  Future<DeviceState> ensure(UserSession s);
}

EntryFailure _map(Object e) {
  if (e is EntryFailure) return e;
  if (e is sb.PostgrestException) {
    switch (e.code) {
      case '42501':
        return EntryFailure('err_forbidden');
      case '23514':
      case '23502':
      case '22P02':
        return EntryFailure('err_amount');
      case 'P0001':
        return EntryFailure('err_rejected', e.message);
    }
    return EntryFailure('err_server');
  }
  return EntryFailure('err_network');
}

int? _int(dynamic v) => v == null ? null : (v as num).toInt();

class SupabaseEntriesRepository implements EntriesRepository {
  SupabaseEntriesRepository(this._c);
  final sb.SupabaseClient _c;

  @override
  Future<List<EntryCategory>> categories(EntryKind kind) async {
    try {
      final rows = await _c
          .from('categories')
          .select('id, name_ar, name_en')
          .eq('kind', kind.categoryKind)
          .eq('is_active', true)
          .order('sort_order');
      return [
        for (final r in rows)
          EntryCategory(id: r['id'] as String, nameAr: r['name_ar'] as String, nameEn: r['name_en'] as String?),
      ];
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<List<EntryAccount>> accounts() async {
    try {
      final rows = await _c.from('accounts_public').select('id, name_ar, name_en, kind');
      return [
        for (final r in rows)
          EntryAccount(
              id: r['id'] as String,
              nameAr: r['name_ar'] as String,
              nameEn: r['name_en'] as String?,
              kind: r['kind'] as String),
      ];
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<String> add(EntryInput i, UserSession s) async {
    try {
      final ref = await _c.rpc(i.kind.rpc, params: {
        'p_op_id': i.opId,
        'p_id': i.id,
        'p_device': i.deviceId,
        'p_business_date': i.businessDate,
        'p_occurred_at': i.occurredAt.toUtc().toIso8601String(),
        'p_amount_iqd': i.amountIqd,
        'p_category': i.categoryId,
        'p_account': i.accountId,
        'p_description': i.description,
        'p_receipt_no': i.receiptNo,
        'p_notes': i.notes,
      });
      return ref as String;
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<List<Entry>> list(EntryKind kind, EntryFilter f, UserSession s) async {
    try {
      var q = _c.from(kind.table).select(
          'id, reference_no, amount_iqd, occurred_at, business_date, category_id, account_id, description, receipt_no, profiles!created_by(full_name)');
      q = q.eq('status', 'active');
      if (f.from != null) q = q.gte('business_date', f.from!);
      if (f.to != null) q = q.lte('business_date', f.to!);
      if (f.categoryId != null) q = q.eq('category_id', f.categoryId!);
      if (f.accountId != null) q = q.eq('account_id', f.accountId!);
      final text = f.query?.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();
      if (text != null && text.isNotEmpty) {
        q = q.or('description.ilike.%$text%,receipt_no.ilike.%$text%,reference_no.ilike.%$text%');
      }
      final rows = await q.order('occurred_at', ascending: false).limit(200);
      return [
        for (final r in rows)
          Entry(
            id: r['id'] as String,
            referenceNo: r['reference_no'] as String,
            amountIqd: (r['amount_iqd'] as num).toInt(),
            occurredAt: DateTime.parse(r['occurred_at'] as String).toUtc(),
            businessDate: r['business_date'] as String,
            categoryId: r['category_id'] as String,
            accountId: r['account_id'] as String,
            description: r['description'] as String?,
            receiptNo: r['receipt_no'] as String?,
            createdByName: (r['profiles'] as Map<String, dynamic>?)?['full_name'] as String?,
          ),
      ];
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<PeriodTotals> totals(String from, String to, UserSession s) async {
    try {
      final rows = await _c.rpc('period_totals', params: {'p_from': from, 'p_to': to});
      final r = (rows as List).first as Map<String, dynamic>;
      return PeriodTotals(revenue: _int(r['revenue_iqd']), expense: _int(r['expense_iqd']), net: _int(r['net_iqd']));
    } catch (e) {
      throw _map(e);
    }
  }
}

class SupabaseDeviceRepository implements DeviceRepository {
  SupabaseDeviceRepository(this._c);
  final sb.SupabaseClient _c;

  static String _platform() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return 'web';
    }
  }

  /// معرّف الجهاز محلي لكل مستخدم. الجهاز الجديد غير معتمد حتى يعتمده المالك (المالك يُعتمد جهازه تلقائياً).
  @override
  Future<DeviceState> ensure(UserSession s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'rayhana_device_id_${s.userId}';
      var id = prefs.getString(key);
      if (id == null) {
        id = uuidV4();
        await prefs.setString(key, id);
      }
      final row = await _c.from('devices').select('id, authorized').eq('id', id).maybeSingle();
      if (row == null) {
        await _c.from('devices').insert({
          'id': id,
          'user_id': s.userId,
          'label': 'جهاز ${_platform()}',
          'platform': _platform(),
          'authorized': s.isOwner,
          if (s.isOwner) 'authorized_by': s.userId,
        });
        return DeviceState(id, s.isOwner);
      }
      return DeviceState(id, row['authorized'] == true);
    } catch (e) {
      throw _map(e);
    }
  }
}
