import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_durations.dart';
import '../../../core/constants/app_radii.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/platform_image.dart';
import '../../exhibitions/data/exhibition_controller.dart';
import '../../exhibitions/presentation/folder_dialogs.dart';
import '../domain/scan_flow_controller.dart';

class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen>
    with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source, {bool back = false}) async {
    // Cap the long side at 1600px — cards don't need more, and it keeps
    // upload + OCR fast on flaky exhibition wifi.
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (image == null) return;
    final ctl = ref.read(scanFlowProvider.notifier);
    if (back) {
      ctl.setBackImage(image.path);
    } else {
      ctl.setImage(image.path);
    }
  }

  Future<void> _addBack() async {
    // Match the primary capture affordance: prefer camera on mobile.
    await _pick(ImageSource.camera, back: true);
  }

  Future<void> _use() async {
    // Exhibition speed: extract → save → straight to the "what next?" screen.
    // Anything wrong on the card can be edited from Lead Detail later.
    final id = await ref.read(scanFlowProvider.notifier).processAndSave();
    if (!mounted) return;
    if (id != null) {
      context.pushReplacement('${Routes.scanPost}?leadId=$id');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
            ref.read(scanFlowProvider).error ?? "Couldn't save this card.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(scanFlowProvider);
    final text = Theme.of(context).textTheme;
    final extracting = flow.step == ScanStep.extracting;
    final hasImage = flow.imagePath != null;
    final exhibition = ref.watch(currentExhibitionProvider).valueOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF101014),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101014),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(scanFlowProvider.notifier).reset();
            context.pop();
          },
        ),
        title: Text('Scan card', style: text.titleLarge?.copyWith(color: Colors.white)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(children: [
            // Folder / exhibition chip — the scan is tagged with whichever
            // exhibition is active. Tap to change / create.
            _ExhibitionChip(
              label: exhibition?.name ?? 'No folder — tap to pick',
              onTap: () => FolderDialogs.showPickForScan(context, ref),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final glow = extracting ? 0.35 + 0.45 * _pulse.value : 0.0;
                return AspectRatio(
                  aspectRatio: 85.6 / 54,
                  child: AnimatedContainer(
                    duration: AppMotion.slow,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      border: Border.all(
                          color: extracting
                              ? AppColors.iris
                              : Colors.white.withValues(alpha: hasImage ? 0.6 : 0.35),
                          width: 2),
                      color: Colors.white.withValues(alpha: 0.04),
                      boxShadow: extracting
                          ? [BoxShadow(
                              color: AppColors.iris.withValues(alpha: glow),
                              blurRadius: 34)]
                          : null,
                    ),
                    child: child,
                  ),
                );
              },
              child: hasImage
                  ? Stack(fit: StackFit.expand, children: [
                      PlatformImage(path: flow.imagePath!),
                      if (extracting)
                        Container(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: const _ProcessingOverlay(),
                        ),
                    ])
                  : Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.badge_outlined, size: 40,
                            color: Colors.white.withValues(alpha: 0.5)),
                        const SizedBox(height: AppSpacing.x3),
                        Text('Align the card inside the frame',
                            style: text.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7))),
                      ]),
                    ),
            ),
            const Spacer(),
            if (!hasImage) ...[
              FilledButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: const Color(0xFF16161D)),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Capture'),
              ),
              const SizedBox(height: AppSpacing.x3),
              TextButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Choose from gallery'),
              ),
            ] else if (!extracting) ...[
              // Small strip: front thumb + back-side slot. Keeps the exhibition
              // flow fast — one tap to add the back, one tap to remove.
              _SidesStrip(
                frontPath: flow.imagePath!,
                backPath: flow.backImagePath,
                onAddBack: _addBack,
                onRemoveBack: () =>
                    ref.read(scanFlowProvider.notifier).removeBackImage(),
              ),
              const SizedBox(height: AppSpacing.x4),
              FilledButton.icon(
                onPressed: _use,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.iris, foregroundColor: Colors.white),
                icon: const Icon(Icons.auto_awesome_rounded, size: 19),
                label: Text(flow.backImagePath == null
                    ? 'Use photo'
                    : 'Use photos'),
              ),
              const SizedBox(height: AppSpacing.x3),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => ref.read(scanFlowProvider.notifier).retake(),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24)),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retake'),
                  ),
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24)),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('Replace'),
                  ),
                ),
              ]),
            ] else
              const SizedBox(height: 104),
          ]),
        ),
      ),
    );
  }
}

/// Two thumbnails side by side: the captured front, and an optional back.
/// Tap the back slot to add; tap the × to remove it.
class _SidesStrip extends StatelessWidget {
  const _SidesStrip({
    required this.frontPath,
    required this.backPath,
    required this.onAddBack,
    required this.onRemoveBack,
  });

  final String frontPath;
  final String? backPath;
  final VoidCallback onAddBack;
  final VoidCallback onRemoveBack;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SideThumb(
          label: 'Front',
          child: PlatformImage(path: frontPath),
          onTap: null,
          onRemove: null,
        ),
        const SizedBox(width: AppSpacing.x3),
        if (backPath == null)
          _SideThumb(
            label: 'Add back',
            onTap: onAddBack,
            onRemove: null,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_rounded, color: Colors.white.withValues(alpha: 0.7)),
                const SizedBox(height: 2),
                Text(
                  'Optional',
                  style: text.bodySmall
                      ?.copyWith(color: Colors.white.withValues(alpha: 0.55)),
                ),
              ]),
            ),
          )
        else
          _SideThumb(
            label: 'Back',
            onTap: null,
            onRemove: onRemoveBack,
            child: PlatformImage(path: backPath!),
          ),
      ],
    );
  }
}

class _SideThumb extends StatelessWidget {
  const _SideThumb({
    required this.label,
    required this.child,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 96,
        height: 62,
        // Clip.none is required because the close (×) button is positioned
        // slightly outside the Stack's bounds (top: -6, right: -6). Without
        // it, Flutter's default clipping hides the button visually but the
        // hit-test system still assertion-spams every pointer event.
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: onTap,
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: onTap == null ? 0.35 : 0.6),
                      width: 1,
                    ),
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                  child: child,
                ),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: -6,
                right: -6,
                child: Material(
                  color: Colors.black87,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(height: 4),
      Text(label,
          style: text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.7))),
    ]);
  }
}

/// The little chip at the top of the scan screen showing the active
/// exhibition folder. Tap to open the picker.
class _ExhibitionChip extends StatelessWidget {
  const _ExhibitionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.folder_outlined,
                  size: 15, color: Colors.white70),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 12.5)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: Colors.white70),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Two-phase processing feedback: upload, then extraction.
class _ProcessingOverlay extends StatefulWidget {
  const _ProcessingOverlay();

  @override
  State<_ProcessingOverlay> createState() => _ProcessingOverlayState();
}

class _ProcessingOverlayState extends State<_ProcessingOverlay> {
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    unawaited(Future.delayed(const Duration(milliseconds: 650),
        () => mounted ? setState(() => _reading = true) : null));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(width: 28, height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.iris)),
        const SizedBox(height: AppSpacing.x4),
        AnimatedSwitcher(
          duration: AppMotion.base,
          child: Text(_reading ? 'Reading details…' : 'Uploading card…',
              key: ValueKey(_reading),
              style: text.bodyMedium?.copyWith(color: Colors.white)),
        ),
      ]),
    );
  }
}
