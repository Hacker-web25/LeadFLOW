import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_durations.dart';
import '../theme/app_colors.dart';
import '../theme/lf_colors.dart';
import '../widgets/lf_pressable.dart';
import 'app_router.dart';

/// Frosted bottom navigation with the scan action integrated as a
/// center FAB — always one thumb away, no banner needed.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.78),
              border: Border(top: BorderSide(color: c.hairline)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(children: [
                  _Dest(icon: Icons.home_outlined, active: Icons.home_rounded,
                      label: 'Home', index: 0, shell: shell),
                  _Dest(icon: Icons.people_alt_outlined, active: Icons.people_alt_rounded,
                      label: 'Leads', index: 1, shell: shell),
                  const _ScanFab(),
                  _Dest(icon: Icons.search_rounded, active: Icons.search_rounded,
                      label: 'Search', index: 2, shell: shell),
                  _Dest(icon: Icons.settings_outlined, active: Icons.settings_rounded,
                      label: 'Settings', index: 3, shell: shell),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Dest extends StatelessWidget {
  const _Dest({required this.icon, required this.active, required this.label,
      required this.index, required this.shell});

  final IconData icon, active;
  final String label;
  final int index;
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final c = context.lf;
    final selected = shell.currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => shell.goBranch(index, initialLocation: index == shell.currentIndex),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          AnimatedSwitcher(
            duration: AppMotion.base,
            child: Icon(selected ? active : icon,
                key: ValueKey(selected), size: 23,
                color: selected ? AppColors.iris : c.inkTertiary),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10.5, letterSpacing: 0.2,
                  color: selected ? AppColors.iris : c.inkTertiary)),
        ]),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  const _ScanFab();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Center(
        child: LfPressable(
          onTap: () => context.push(Routes.scan),
          child: Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              color: AppColors.iris,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                  color: AppColors.iris.withValues(alpha: 0.4),
                  blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.document_scanner_outlined,
                color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
