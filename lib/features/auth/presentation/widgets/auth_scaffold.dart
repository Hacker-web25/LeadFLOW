import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/lf_colors.dart';

/// Shared premium auth chrome: iris mark, hero copy, form card.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;

    return Scaffold(
      appBar: showBack
          ? AppBar(elevation: 0, backgroundColor: c.canvas)
          : null,
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenH),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: constraints.maxHeight, maxWidth: 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.x6),
                  Center(
                    child: Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.iris,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [BoxShadow(
                            color: AppColors.iris.withValues(alpha: 0.35),
                            blurRadius: 24, offset: const Offset(0, 10))],
                      ),
                      child: const Icon(Icons.document_scanner_rounded,
                          color: Colors.white, size: 28),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x5),
                  Text(AppConfig.appName,
                      textAlign: TextAlign.center, style: text.headlineSmall),
                  const SizedBox(height: 2),
                  Text(AppConfig.tagline,
                      textAlign: TextAlign.center, style: text.bodyMedium),
                  const SizedBox(height: AppSpacing.x10),
                  Text(title, style: text.displaySmall),
                  const SizedBox(height: AppSpacing.x2),
                  Text(subtitle,
                      style: text.bodyLarge?.copyWith(color: c.inkSecondary)),
                  const SizedBox(height: AppSpacing.x8),
                  child,
                  const SizedBox(height: AppSpacing.x8),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Labeled text field used across auth screens.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.obscure = false,
    this.validator,
    this.autofillHints,
    this.onFieldSubmitted,
    this.textInputAction,
    this.suffix,
  });

  final String label;
  final String? hint;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscure;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall),
          const SizedBox(height: AppSpacing.x2),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscure,
            validator: validator,
            autofillHints: autofillHints,
            onFieldSubmitted: onFieldSubmitted,
            textInputAction: textInputAction,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(hintText: hint, suffixIcon: suffix),
          ),
        ],
      ),
    );
  }
}
