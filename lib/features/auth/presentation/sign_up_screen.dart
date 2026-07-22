import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import 'auth_validators.dart';
import 'widgets/auth_scaffold.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPass = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final r = await ref.read(authRepositoryProvider).signUp(
        email: _email.text, password: _password.text, fullName: _name.text);
    if (!mounted) return;
    r.when(
      ok: (_) => context.go(Routes.dashboard),
      err: (f) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(f.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AuthScaffold(
      title: 'Create your workspace',
      subtitle: 'Start capturing leads in seconds.',
      showBack: true,
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Full name', hint: 'Jane Doe', controller: _name,
                keyboardType: TextInputType.name,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.name,
              ),
              AuthField(
                label: 'Work email', hint: 'you@company.com', controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
              ),
              AuthField(
                label: 'Password', controller: _password, obscure: !_showPass,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                validator: AuthValidators.password,
                onFieldSubmitted: (_) => _submit(),
                suffix: IconButton(
                  icon: Icon(_showPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      size: 20, color: context.lf.inkTertiary),
                  onPressed: () => setState(() => _showPass = !_showPass),
                ),
              ),
              Text('At least 8 characters.',
                  style: text.labelSmall?.copyWith(color: context.lf.inkTertiary)),
              const SizedBox(height: AppSpacing.x5),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Create account'),
              ),
              const SizedBox(height: AppSpacing.x5),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Already have an account?', style: text.bodyMedium),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Sign in',
                      style: TextStyle(color: AppColors.iris)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
