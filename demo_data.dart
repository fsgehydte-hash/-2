import 'dart:math';

import '../core/permissions.dart';
import 'auth_repository.dart';
import 'users_repository.dart';

/// بيانات وهمية بالكامل للعرض والاختبار فقط. لا تحتوي أي بيانات مالية حقيقية.
class DemoUser {
  DemoUser({
    required this.id,
    required this.email,
    required this.fullName,
    this.isOwner = false,
    this.isActive = true,
    Set<Perm>? perms,
  }) : perms = perms ?? <Perm>{};
  final String id;
  final String email;
  final String fullName;
  final bool isOwner;
  bool isActive;
  final Set<Perm> perms;
}

class DemoStore {
  DemoStore()
      : users = [
          DemoUser(id: 'u-owner', email: 'owner@demo.local', fullName: 'مالك تجريبي', isOwner: true),
          DemoUser(
            id: 'u-cashier',
            email: 'cashier@demo.local',
            fullName: 'أمين صندوق تجريبي',
            perms: {Perm.revenueCreate, Perm.expenseCreate},
          ),
          DemoUser(
            id: 'u-viewer',
            email: 'viewer@demo.local',
            fullName: 'مطّلع تجريبي',
            perms: {Perm.revenueViewToday},
          ),
        ];
  final List<DemoUser> users;
  String? currentId;
  /// كلمة مرور عشوائية تُولَّد عند كل تشغيل وتُعرض على شاشة الدخول للمجرِّب؛ ليست ثابتة في الكود.
  static final String sessionPassword = _random();
  static String _random() {
    const chars = 'abcdefghjkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
  }

  DemoUser? byId(String? id) {
    for (final u in users) {
      if (u.id == id) return u;
    }
    return null;
  }

  UserSession toSession(DemoUser u) =>
      UserSession(userId: u.id, fullName: u.fullName, isOwner: u.isOwner, perms: Set.of(u.perms));
}

class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository(this._s);
  final DemoStore _s;

  @override
  Future<UserSession?> currentSession() async {
    final u = _s.byId(_s.currentId);
    return (u == null || !u.isActive) ? null : _s.toSession(u);
  }

  @override
  Future<UserSession> signIn(String email, String password) async {
    DemoUser? found;
    for (final u in _s.users) {
      if (u.email == email.trim().toLowerCase()) found = u;
    }
    if (found == null || password != DemoStore.sessionPassword) throw LoginFailure('err_login');
    if (!found.isActive) throw LoginFailure('err_inactive');
    _s.currentId = found.id;
    return _s.toSession(found);
  }

  @override
  Future<void> signOut() async => _s.currentId = null;
}

class DemoUsersRepository implements UsersRepository {
  DemoUsersRepository(this._s);
  final DemoStore _s;

  @override
  Future<List<ManagedUser>> list() async => [
        for (final u in _s.users)
          ManagedUser(
            id: u.id,
            fullName: u.fullName,
            isOwner: u.isOwner,
            isActive: u.isActive,
            perms: Set.of(u.perms),
          ),
      ];

  @override
  Future<void> setPermission(String userId, Perm perm, bool granted, String grantedBy) async {
    final u = _s.byId(userId);
    if (u == null) return;
    granted ? u.perms.add(perm) : u.perms.remove(perm);
  }

  @override
  Future<void> setActive(String userId, bool active) async => _s.byId(userId)?.isActive = active;

  @override
  Future<List<ManagedDevice>> devices() async => const [];

  @override
  Future<void> setDeviceAuthorized(String deviceId, bool authorized, String ownerId) async {}
}
