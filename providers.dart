import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/permissions.dart';
import '../core/settings.dart';
import '../data/auth_repository.dart';
import '../core/time_util.dart';
import '../data/dashboard_repository.dart';
import '../data/entries_models.dart';
import '../data/entries_repository.dart';
import '../data/users_repository.dart';

// تُستبدل القيم في main.dart (Supabase أو العرض الوهمي) وفي الاختبارات.
final authRepositoryProvider = Provider<AuthRepository>((ref) => throw UnimplementedError('override in main'));
final entriesRepositoryProvider = Provider<EntriesRepository>((ref) => throw UnimplementedError('override in main'));
final deviceRepositoryProvider = Provider<DeviceRepository>((ref) => throw UnimplementedError('override in main'));
final usersRepositoryProvider = Provider<UsersRepository>((ref) => throw UnimplementedError('override in main'));

class SessionController extends StateNotifier<AsyncValue<UserSession?>> {
  SessionController(this._repo) : super(const AsyncValue.loading()) {
    _init();
  }
  final AuthRepository _repo;

  Future<void> _init() async {
    try {
      state = AsyncValue.data(await _repo.currentSession());
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  /// يرمي [LoginFailure] عند الفشل.
  Future<void> signIn(String email, String password) async {
    final s = await _repo.signIn(email, password);
    state = AsyncValue.data(s);
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }
}

final sessionProvider = StateNotifierProvider<SessionController, AsyncValue<UserSession?>>(
  (ref) => SessionController(ref.watch(authRepositoryProvider)),
);

final settingsProvider = StateNotifierProvider<SettingsController, AppSettings>((ref) => SettingsController());

final dashboardProvider = FutureProvider.autoDispose<DashboardData>((ref) async {
  final s = ref.watch(sessionProvider).valueOrNull;
  if (s == null) return const DashboardData();
  final today = todayBusinessDate();
  final t = await ref.watch(entriesRepositoryProvider).totals(today, today, s);
  return DashboardData(revenueToday: t.revenue, expenseToday: t.expense, netToday: t.net);
});

final categoriesProvider = FutureProvider.autoDispose.family<List<EntryCategory>, EntryKind>(
  (ref, kind) => ref.watch(entriesRepositoryProvider).categories(kind),
);

final accountsProvider = FutureProvider.autoDispose<List<EntryAccount>>(
  (ref) => ref.watch(entriesRepositoryProvider).accounts(),
);

final entriesProvider = FutureProvider.autoDispose.family<List<Entry>, EntriesQuery>((ref, q) {
  final s = ref.watch(sessionProvider).valueOrNull;
  if (s == null) return Future.value(const <Entry>[]);
  return ref.watch(entriesRepositoryProvider).list(q.kind, q.filter, s);
});

final totalsProvider = FutureProvider.autoDispose.family<PeriodTotals, DateRange>((ref, r) {
  final s = ref.watch(sessionProvider).valueOrNull;
  if (s == null) return Future.value(const PeriodTotals());
  return ref.watch(entriesRepositoryProvider).totals(r.from, r.to, s);
});

final devicesProvider = FutureProvider.autoDispose<List<ManagedDevice>>(
  (ref) => ref.watch(usersRepositoryProvider).devices(),
);

final managedUsersProvider = FutureProvider.autoDispose<List<ManagedUser>>(
  (ref) => ref.watch(usersRepositoryProvider).list(),
);
