import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/lf_avatar.dart';
import '../../../core/widgets/lf_card.dart';
import '../../../core/widgets/lf_section_header.dart';
import '../../leads/domain/lead.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../../../core/theme/lf_colors.dart';

/// Profile: identity plus a personal pipeline summary.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final leads = ref.watch(leadsStreamProvider);
    final user = ref.watch(authUserStreamProvider).valueOrNull;
    final name = user?.fullName?.trim().isNotEmpty == true
        ? user!.fullName!
        : (user?.email.split('@').first ?? 'Your workspace');

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH, 0, AppSpacing.screenH, AppSpacing.x10),
        children: [
          Center(
            child: Column(
              children: [
                LfAvatar(name, size: 84),
                const SizedBox(height: AppSpacing.x4),
                Text(name, style: text.headlineSmall),
                const SizedBox(height: 2),
                Text(user?.email ?? 'Not signed in', style: text.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.x8),

          const LfSectionHeader('Your pipeline'),
          leads.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (all) {
              final hot =
                  all.where((l) => l.temperature == LeadTemperature.hot).length;
              final dms = all.where((l) => l.isDecisionMaker == true).length;
              return LfCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
                child: Column(
                  children: [
                    _StatRow('Leads captured', '${all.length}'),
                    const Divider(),
                    _StatRow('Hot leads', '$hot'),
                    const Divider(),
                    _StatRow('Decision makers met', '$dms'),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.x6),

          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Sign out?'),
                  content: const Text('You will need to sign back in to view your leads.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false),
                        child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(c, true),
                        child: const Text('Sign out')),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go(Routes.signIn);
              }
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: text.bodyMedium)),
          Text(value,
              style: AppTypography.stat
                  .copyWith(fontSize: 17, color: context.lf.ink)),
        ],
      ),
    );
  }
}
