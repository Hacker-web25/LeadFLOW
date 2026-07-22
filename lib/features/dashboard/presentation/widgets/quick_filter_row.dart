import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/lf_chip.dart';
import '../../../../core/widgets/temperature_badge.dart';
import '../../../leads/domain/lead.dart';
import '../../../leads/presentation/providers/leads_providers.dart';

/// One-tap temperature filters that jump straight into the Leads tab.
class QuickFilterRow extends ConsumerWidget {
  const QuickFilterRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(leadFiltersProvider);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final t in LeadTemperature.values) ...[
            LfChoiceChip(
              label: t.label,
              selected: filters.temperatures.contains(t),
              leading: TemperatureBadge(t, dense: true),
              onTap: () {
                ref.read(leadFiltersProvider.notifier)
                  ..clear()
                  ..toggleTemperature(t);
                context.go(Routes.leads);
              },
            ),
            const SizedBox(width: 8),
          ],
          LfChoiceChip(
            label: 'All leads',
            selected: false,
            onTap: () {
              ref.read(leadFiltersProvider.notifier).clear();
              context.go(Routes.leads);
            },
          ),
        ],
      ),
    );
  }
}
