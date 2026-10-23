import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/permissions.dart';
import '../../core/strings.dart';

/// للمالك فقط: منح/سحب صلاحيات الأشخاص الذين يختارهم. الحماية الفعلية في RLS.
class UsersPage extends ConsumerWidget {
  const UsersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).valueOrNull;
    final users = ref.watch(managedUsersProvider);
    return users.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Center(
        child: OutlinedButton(onPressed: () => ref.invalidate(managedUsersProvider), child: Text(context.t('retry'))),
      ),
      data: (list) => ListView(padding: const EdgeInsets.all(16), children: [
        Text(context.t('users_note'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        const _DevicesSection(),
        const SizedBox(height: 12),
        for (final u in list)
          Card(
            child: ExpansionTile(
              title: Text(u.fullName),
              subtitle: Text(context.t(u.isOwner ? 'owner' : 'staff')),
              children: u.isOwner
                  ? [ListTile(title: Text(context.t('owner_all_perms')))]
                  : [
                      SwitchListTile(
                        title: Text(context.t('account_active')),
                        value: u.isActive,
                        onChanged: (v) => _run(context, ref, () => ref.read(usersRepositoryProvider).setActive(u.id, v)),
                      ),
                      for (final p in Perm.values)
                        SwitchListTile(
                          title: Text(context.t('perm.${p.code}')),
                          value: u.perms.contains(p),
                          onChanged: (v) => _run(
                            context,
                            ref,
                            () => ref.read(usersRepositoryProvider).setPermission(u.id, p, v, me?.userId ?? ''),
                          ),
                        ),
                    ],
            ),
          ),
      ]),
    );
  }

  Future<void> _run(BuildContext context, WidgetRef ref, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    final failText = context.t('load_error');
    try {
      await action();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failText)));
    }
    ref.invalidate(managedUsersProvider);
  }
}

/// أجهزة المستخدمين: الجهاز الجديد لا يسجّل عمليات حتى يعتمده المالك.
class _DevicesSection extends ConsumerWidget {
  const _DevicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(sessionProvider).valueOrNull;
    final devices = ref.watch(devicesProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.t('devices_title'), style: Theme.of(context).textTheme.titleMedium),
          devices.when(
            loading: () => const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()),
            error: (_, __) => Text(context.t('load_error')),
            data: (list) => Column(children: [
              for (final d in list)
                ListTile(
                  dense: true,
                  title: Text('${d.userName} — ${d.label}'),
                  subtitle: Text(context.t(d.authorized ? 'device_ok' : (d.revoked ? 'device_revoked' : 'device_pending'))),
                  trailing: d.authorized
                      ? TextButton(
                          onPressed: () async {
                            await ref.read(usersRepositoryProvider).setDeviceAuthorized(d.id, false, me?.userId ?? '');
                            ref.invalidate(devicesProvider);
                          },
                          child: Text(context.t('device_revoke')),
                        )
                      : FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                          onPressed: () async {
                            await ref.read(usersRepositoryProvider).setDeviceAuthorized(d.id, true, me?.userId ?? '');
                            ref.invalidate(devicesProvider);
                          },
                          child: Text(context.t('device_authorize')),
                        ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
