import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../core/permissions.dart';

/// [key] مفتاح نص في Strings (err_login | err_network | err_inactive).
class LoginFailure implements Exception {
  LoginFailure(this.key);
  final String key;
}

abstract class AuthRepository {
  Future<UserSession?> currentSession();
  Future<UserSession> signIn(String email, String password);
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._c);
  final sb.SupabaseClient _c;

  @override
  Future<UserSession?> currentSession() async {
    final u = _c.auth.currentUser;
    if (u == null) return null;
    try {
      return await _load(u.id);
    } on LoginFailure {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<UserSession> signIn(String email, String password) async {
    try {
      final r = await _c.auth.signInWithPassword(email: email.trim(), password: password);
      final id = r.user?.id;
      if (id == null) throw LoginFailure('err_login');
      return await _load(id);
    } on LoginFailure {
      rethrow;
    } on sb.AuthException {
      throw LoginFailure('err_login');
    } catch (_) {
      throw LoginFailure('err_network');
    }
  }

  @override
  Future<void> signOut() => _c.auth.signOut();

  Future<UserSession> _load(String id) async {
    final p = await _c.from('profiles').select('full_name, role, is_active').eq('id', id).maybeSingle();
    if (p == null || p['is_active'] != true) {
      await _c.auth.signOut();
      throw LoginFailure('err_inactive');
    }
    final rows = await _c.from('user_permissions').select('permission_code').eq('user_id', id);
    final perms = <Perm>{};
    for (final r in rows) {
      final perm = Perm.fromCode(r['permission_code'] as String);
      if (perm != null) perms.add(perm);
    }
    return UserSession(
      userId: id,
      fullName: p['full_name'] as String,
      isOwner: p['role'] == 'owner',
      perms: perms,
    );
  }
}
