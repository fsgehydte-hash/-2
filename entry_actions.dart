import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/strings.dart';
import '../../data/entries_models.dart';
import 'entry_form_page.dart';

/// يفتح نموذج التسجيل؛ عند النجاح يعرض الرقم المرجعي ويحدّث الإجماليات والقوائم من الخادم.
Future<void> openEntryForm(BuildContext context, WidgetRef ref, EntryKind kind) async {
  final refNo = await Navigator.of(context).push<String>(
    MaterialPageRoute(builder: (_) => EntryFormPage(kind: kind)),
  );
  if (refNo == null) return;
  ref.invalidate(dashboardProvider);
  ref.invalidate(entriesProvider);
  ref.invalidate(totalsProvider);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${context.t('saved_ref')}$refNo')));
  }
}
