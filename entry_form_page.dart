import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/idgen.dart';
import '../../core/iqd_input.dart';
import '../../core/strings.dart';
import '../../core/time_util.dart';
import '../../data/entries_models.dart';

/// نموذج واحد للإيراد والمصروف. المعرّفان (id/opId) يُولَّدان مرة واحدة ويبقيان عند إعادة المحاولة،
/// فلا تتكرر العملية إن وصلت للخادم ولم يصل التأكيد.
class EntryFormPage extends ConsumerStatefulWidget {
  const EntryFormPage({super.key, required this.kind});
  final EntryKind kind;
  @override
  ConsumerState<EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends ConsumerState<EntryFormPage> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  final _receipt = TextEditingController();
  final _notes = TextEditingController();
  final String _id = uuidV4();
  final String _opId = uuidV4();
  DateTime? _occurredAt;
  String? _cat;
  String? _acct;
  bool _busy = false;
  EntryFailure? _error;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    _receipt.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _clean(String v) => v.trim().isEmpty ? null : v.trim();

  Future<void> _save(String fallbackCat, String fallbackAcct) async {
    if (!_form.currentState!.validate()) return;
    final s = ref.read(sessionProvider).valueOrNull;
    if (s == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dev = await ref.read(deviceRepositoryProvider).ensure(s);
      if (!dev.authorized) throw EntryFailure('err_device_pending');
      _occurredAt ??= nowUtc();
      final input = EntryInput(
        id: _id,
        opId: _opId,
        deviceId: dev.id,
        kind: widget.kind,
        amountIqd: parseIqd(_amount.text)!,
        categoryId: _cat ?? fallbackCat,
        accountId: _acct ?? fallbackAcct,
        occurredAt: _occurredAt!,
        description: _clean(_desc.text),
        receiptNo: _clean(_receipt.text),
        notes: _clean(_notes.text),
      );
      final refNo = await ref.read(entriesRepositoryProvider).add(input, s);
      if (!mounted) return;
      Navigator.of(context).pop(refNo);
    } on EntryFailure catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) setState(() => _error = EntryFailure('err_network'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRev = widget.kind == EntryKind.revenue;
    final cats = ref.watch(categoriesProvider(widget.kind));
    final accts = ref.watch(accountsProvider);
    final color = isRev ? Theme.of(context).colorScheme.primary : Colors.deepOrange.shade700;

    Widget body;
    if (cats.isLoading || accts.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (cats.hasError || accts.hasError || cats.value == null || accts.value == null) {
      body = Center(child: Text(context.t('load_error')));
    } else {
      final cl = cats.value!;
      final al = accts.value!;
      if (cl.isEmpty || al.isEmpty) {
        body = Center(child: Text(context.t('load_error')));
      } else {
        final catValue = _cat ?? cl.first.id;
        final acctValue = _acct ?? al.first.id;
        body = Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              key: const Key('amount'),
              controller: _amount,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.t('amount_iqd')),
              validator: (v) => parseIqd(v ?? '') == null ? context.t('err_amount') : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('category'),
              value: catValue,
              decoration: InputDecoration(labelText: context.t('category')),
              items: [for (final c in cl) DropdownMenuItem(value: c.id, child: Text(c.name(context.isAr)))],
              onChanged: (v) => setState(() => _cat = v),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('account'),
              value: acctValue,
              decoration: InputDecoration(labelText: context.t('payment_method')),
              items: [for (final a in al) DropdownMenuItem(value: a.id, child: Text(a.name(context.isAr)))],
              onChanged: (v) => setState(() => _acct = v),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('description'),
              controller: _desc,
              decoration: InputDecoration(labelText: context.t('description')),
              maxLength: 300,
            ),
            TextFormField(
              key: const Key('receipt'),
              controller: _receipt,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(labelText: context.t('receipt_no')),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('notes'),
              controller: _notes,
              maxLines: 2,
              decoration: InputDecoration(labelText: context.t('notes')),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!.detail == null ? context.t(_error!.key) : '${context.t(_error!.key)}: ${_error!.detail}',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              key: const Key('save'),
              style: FilledButton.styleFrom(backgroundColor: color),
              onPressed: _busy ? null : () => _save(cl.first.id, al.first.id),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(context.t('save')),
            ),
          ]),
        );
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.t(isRev ? 'new_revenue' : 'new_expense'))),
      body: body,
    );
  }
}
