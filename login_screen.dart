import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/config.dart';
import '../../core/strings.dart';
import '../../data/auth_repository.dart';
import '../../data/demo_data.dart';
import '../../widgets/brand_logo.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _errorKey;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      await ref.read(sessionProvider.notifier).signIn(_email.text, _password.text);
    } on LoginFailure catch (e) {
      if (mounted) setState(() => _errorKey = e.key);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Form(
                  key: _form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandLogo(size: 88)),
                      const SizedBox(height: 16),
                      Text(context.t('app_name'),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(context.t('app_subtitle'), textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      TextFormField(
                        key: const Key('email'),
                        controller: _email,
                        textDirection: TextDirection.ltr,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.username],
                        decoration: InputDecoration(labelText: context.t('email')),
                        validator: (v) => (v == null || v.trim().isEmpty) ? context.t('err_required') : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('password'),
                        controller: _password,
                        textDirection: TextDirection.ltr,
                        obscureText: _hide,
                        autofillHints: const [AutofillHints.password],
                        decoration: InputDecoration(
                          labelText: context.t('password'),
                          suffixIcon: IconButton(
                            icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? context.t('err_required') : null,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      if (_errorKey != null) ...[
                        const SizedBox(height: 12),
                        Text(context.t(_errorKey!), style: TextStyle(color: cs.error), textAlign: TextAlign.center),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        key: const Key('signin'),
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                            : Text(context.t('sign_in')),
                      ),
                      if (AppConfig.demo) ...[
                        const SizedBox(height: 16),
                        SelectableText(context.t('demo_hint').replaceAll('{pw}', DemoStore.sessionPassword),
            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
