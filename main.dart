import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'core/config.dart';
import 'data/auth_repository.dart';
import 'data/demo_data.dart';
import 'data/demo_entries.dart';
import 'data/entries_repository.dart';
import 'data/users_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AuthRepository auth;
  final EntriesRepository entries;
  final DeviceRepository devices;
  final UsersRepository users;
  if (AppConfig.demo) {
    final store = DemoStore();
    auth = DemoAuthRepository(store);
    entries = DemoEntriesRepository();
    devices = DemoDeviceRepository();
    users = DemoUsersRepository(store);
  } else if (AppConfig.hasBackend) {
    await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
    final c = Supabase.instance.client;
    auth = SupabaseAuthRepository(c);
    entries = SupabaseEntriesRepository(c);
    devices = SupabaseDeviceRepository(c);
    users = SupabaseUsersRepository(c);
  } else {
    runApp(const ConfigMissingApp());
    return;
  }
  runApp(ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(auth),
      entriesRepositoryProvider.overrideWithValue(entries),
      deviceRepositoryProvider.overrideWithValue(devices),
      usersRepositoryProvider.overrideWithValue(users),
    ],
    child: const RayhanaApp(),
  ));
}
