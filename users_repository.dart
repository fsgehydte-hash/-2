import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/permissions.dart';

class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.fullName,
    required this.isOwner,
    required this.isActive,
    required this.perms,
  });
  final String id;
  final String fullName;
  final bool isOwner;
  final bool isActive;
  final Set<Perm> perms;
}

class ManagedDevice {
  const ManagedDevice({
    required this.id,
    required this.label,
    required this.platform,
    required this.userName,
    required this.authorized,
    required this.revoked,
  });
  final String id;
  final String label;
  final String platform;
  final String userName;
  final bool authorized;
  final bool revoked;
}

/// إدارة صلاحيات الحسابات الموجودة (للمالك). الخادم يمنع غير المالك عبر RLS.
abstract class UsersRepository {
  Future<List<ManagedUser>> list();
  Future<void> setPermission(String userId, Perm perm, bool granted, String grantedBy);
  Future<void> setActive(String userId, bool active);
  Future<List<ManagedDevice>> devices();
  Future<void> setDeviceAuthorized(String deviceId, bool authorized, String ownerId);
}

class SupabaseUsersRepository implements UsersRepository {
  SupabaseUsersRepository(this._c);
  final sb.SupabaseClient _c;

  @override
  Future<List<ManagedUser>> list() async {
    final profiles = await _c.from('profiles').select('id, full_name, role, is_active').order('full_name');
    final perms = await _c.from('user_permissions').select('user_id, permission_code');
    final byUser = <String, Set<Perm>>{};
    for (final r in perms) {
      final p = Perm.fromCode(r['permission_code'] as String);
      if (p != null) (byUser[r['user_id'] as String] ??= <Perm>{}).add(p);
    }
    return [
      for (final p in profiles)
        ManagedUser(
          id: p['id'] as String,
          fullName: p['full_name'] as String,
          isOwner: p['role'] == 'owner',
          isActive: p['is_active'] == true,
          perms: byUser[p['id'] as String] ?? <Perm>{},
        ),
    ];
  }

  @override
  Future<void> setPermission(String userId, Perm perm, bool granted, String grantedBy) async {
    if (granted) {
      await _c.from('user_permissions').upsert({
        'user_id': userId,
        'permission_code': perm.code,
        'granted_by': grantedBy,
      });
    } else {
      await _c.from('user_permissions').delete().eq('user_id', userId).eq('permission_code', perm.code);
    }
  }

  @override
  Future<void> setActive(String userId, bool active) async {
    await _c.from('profiles').update({'is_active': active}).eq('id', userId);
  }

  @override
  Future<List<ManagedDevice>> devices() async {
    final rows = await _c
        .from('devices')
        .select('id, label, platform, authorized, revoked_at, profiles!user_id(full_name)')
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        ManagedDevice(
          id: r['id'] as String,
          label: r['label'] as String,
          platform: r['platform'] as String,
          userName: ((r['profiles'] as Map<String, dynamic>?)?['full_name'] as String?) ?? '—',
          authorized: r['authorized'] == true,
          revoked: r['revoked_at'] != null,
        ),
    ];
  }

  @override
  Future<void> setDeviceAuthorized(String deviceId, bool authorized, String ownerId) async {
    if (authorized) {
      await _c
          .from('devices')
          .update({'authorized': true, 'authorized_by': ownerId, 'revoked_at': null}).eq('id', deviceId);
    } else {
      await _c
          .from('devices')
          .update({'authorized': false, 'revoked_at': DateTime.now().toUtc().toIso8601String()}).eq('id', deviceId);
    }
  }
}
