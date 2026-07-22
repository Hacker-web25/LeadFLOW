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

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _showPass = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final r = await ref.read(authRepositoryProvider).signIn(
        email: _email.text, password: _password.text);
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
      title: 'Welcome back',
      subtitle: 'Sign in to keep organizing your leads.',
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AuthField(
                label: 'Email', hint: 'you@company.com', controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                validator: AuthValidators.email,
              ),
              AuthField(
                label: 'Password', controller: _password, obscure: !_showPass,
                autofillHints: const [AutofillHints.password],
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
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(Routes.forgotPassword),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.x4),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Sign in'),
              ),
              const SizedBox(height: AppSpacing.x5),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text("No account yet?",
                    style: text.bodyMedium),
                TextButton(
                  onPressed: () => context.push(Routes.signUp),
                  child: const Text('Create one',
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
