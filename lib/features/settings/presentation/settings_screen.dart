import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/widgets/lf_segmented.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/lf_avatar.dart';
import '../../../core/widgets/lf_card.dart';
import '../../../core/widgets/lf_section_header.dart';
import '../../../core/theme/lf_colors.dart';

/// Settings hub. Rows that lead to future milestones say so honestly.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authUserStreamProvider).valueOrNull;
    final name = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!
        : (user?.email.split('@').first ?? 'Your workspace');
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x10),
        children: [
          // Profile card
          LfCard(
            onTap: () => context.push(Routes.profile),
            child: Row(
              children: [
                LfAvatar(name, size: 52),
                const SizedBox(width: AppSpacing.x4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: text.titleLarge),
                      const SizedBox(height: 2),
                      Text(user?.email ?? 'Not signed in',
                          style: text.bodyMedium),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: context.lf.inkTertiary),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          const LfSectionHeader('Appearance'),
          LfCard(
            child: LfSegmented<ThemeMode>(
              options: const [ThemeMode.system, ThemeMode.light, ThemeMode.dark],
              labelOf: (m) => switch (m) {
                ThemeMode.system => 'System',
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
              },
              value: ref.watch(themeModeProvider),
              onChanged: (m) => ref.read(themeModeProvider.notifier).state = m,
            ),
          ),
          const SizedBox(height: AppSpacing.x6),

          const LfSectionHeader('Capture'),
          const _SettingsGroup(rows: [
            _SettingsRow(Icons.event_outlined, 'Default event name',
                'Applied to every new scan'),
            _SettingsRow(Icons.quiz_outlined, 'Questionnaire',
                'Reorder or hide questions'),
            _SettingsRow(Icons.alarm_outlined, 'Follow-up defaults',
                'Auto-schedule after each scan'),
          ]),
          const SizedBox(height: AppSpacing.x6),

          const LfSectionHeader('Data'),
          const _SettingsGroup(rows: [
            _SettingsRow(Icons.file_download_outlined, 'Export leads',
                'CSV and Excel'),
            _SettingsRow(Icons.cloud_sync_outlined, 'Sync',
                'Supabase connection & backups'),
          ]),
          const SizedBox(height: AppSpacing.x6),

          const LfSectionHeader('About'),
          const _SettingsGroup(rows: [
            _SettingsRow(Icons.workspace_premium_outlined, 'Plan',
                'Free during early access'),
            _SettingsRow(Icons.privacy_tip_outlined, 'Privacy policy', null),
            _SettingsRow(Icons.info_outline_rounded, 'Version', '0.1.0'),
          ]),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.rows});

  final List<_SettingsRow> rows;

  @override
  Widget build(BuildContext context) {
    return LfCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final row in rows) ...[
            row,
            if (row != rows.last)
              const Padding(
                padding: EdgeInsets.only(left: 56),
                child: Divider(),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title — coming in the next milestone'))),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4, vertical: AppSpacing.x3),
        child: Row(
          children: [
            Icon(icon, size: 21, color: context.lf.inkSecondary),
            const SizedBox(width: AppSpacing.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!, style: text.bodyMedium),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: context.lf.inkTertiary),
          ],
        ),
      ),
    );
  }
}
