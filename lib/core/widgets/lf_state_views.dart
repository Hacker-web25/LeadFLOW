import 'package:flutter/material.dart';

import '../constants/app_spacing.dart';
import '../theme/app_colors.dart';
import '../theme/lf_colors.dart';

/// Empty state: an invitation to act, never a dead end.
class LfEmptyState extends StatelessWidget {
  const LfEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: AppColors.iris.withValues(alpha: 0.14), shape: BoxShape.circle),
              child: Icon(icon, color: AppColors.iris, size: 28),
            ),
            const SizedBox(height: AppSpacing.x5),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.x2),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: AppSpacing.x6),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state: says what happened and how to recover.
class LfErrorState extends StatelessWidget {
  const LfErrorState({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: context.lf.soft(AppColors.hot, AppColors.hotSoft), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded, color: AppColors.hot, size: 28),
            ),
            const SizedBox(height: AppSpacing.x5),
            Text('Something went wrong', style: text.titleLarge),
            const SizedBox(height: AppSpacing.x2),
            Text(message, style: text.bodyMedium, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.x6),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(minimumSize: const Size(160, 48)),
                child: const Text('Try again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
