import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/widgets/lf_section_header.dart';
import '../data/exhibition_controller.dart';

/// Bottom sheet that lets the user pick an existing exhibition or type
/// a new one. Used from the Scan screen and from the Leads AppBar.
class ExhibitionPickerSheet extends ConsumerStatefulWidget {
  const ExhibitionPickerSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const ExhibitionPickerSheet(),
      );

  @override
  ConsumerState<ExhibitionPickerSheet> createState() =>
      _ExhibitionPickerSheetState();
}

class _ExhibitionPickerSheetState
    extends ConsumerState<ExhibitionPickerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply(String name) async {
    await ref.read(currentExhibitionProvider.notifier).set(name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final known = ref.watch(knownExhibitionsProvider);
    final current = ref.watch(currentExhibitionProvider).valueOrNull;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.screenH,
          right: AppSpacing.screenH,
          top: AppSpacing.x4,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.x4,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Exhibition folder', style: text.titleLarge),
              const SizedBox(height: AppSpacing.x2),
              Text(
                'New scans will land in this folder until you switch.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.x5),

              // Create new
              const LfSectionHeader('Create new'),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. IPPE Atlanta 2026',
                    ),
                    onSubmitted: _apply,
                  ),
                ),
                const SizedBox(width: AppSpacing.x2),
                FilledButton(
                  onPressed: () => _apply(_controller.text),
                  child: const Text('Use'),
                ),
              ]),
              const SizedBox(height: AppSpacing.x5),

              if (known.isNotEmpty) ...[
                const LfSectionHeader('Recent'),
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x2,
                  children: [
                    for (final name in known)
                      _ExhibitionChip(
                        label: name,
                        selected: current?.name == name,
                        onTap: () => _apply(name),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x4),
              ],

              if (current != null)
                TextButton.icon(
                  onPressed: () =>
                      ref.read(currentExhibitionProvider.notifier).clear().then(
                          (_) => mounted ? Navigator.of(context).pop() : null),
                  icon: const Icon(Icons.folder_off_outlined),
                  label: const Text('No exhibition (untag)'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExhibitionChip extends StatelessWidget {
  const _ExhibitionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    return Material(
      color: selected ? AppColors.iris.withValues(alpha: 0.18) : c.surfaceSunken,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.folder_outlined,
                size: 16, color: selected ? AppColors.iris : c.inkTertiary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: selected ? AppColors.iris : c.ink,
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}
