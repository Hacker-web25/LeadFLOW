import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/widgets/lf_card.dart';
import '../../../core/widgets/lf_section_header.dart';
import '../../../core/widgets/lf_skeleton.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../domain/voice_note.dart';

/// One-shot fetch of voice notes for a lead. Invalidate to refresh (e.g.
/// after saving a new note or deleting one).
final voiceNotesProvider =
    FutureProvider.family.autoDispose<List<VoiceNote>, String>((ref, leadId) async {
  final result = await ref.watch(leadRepositoryProvider).voiceNotesForLead(leadId);
  return result.when(ok: (n) => n, err: (f) => throw f);
});

/// Voice-notes section on Lead Detail. Each note: date, duration, transcript,
/// play/pause button, delete button.
class VoiceNotesSection extends ConsumerWidget {
  const VoiceNotesSection({super.key, required this.leadId});

  final String leadId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = ref.watch(voiceNotesProvider(leadId));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const LfSectionHeader('Voice notes'),
      notes.when(
        loading: () => const LfSkeleton(height: 88, radius: 20),
        error: (e, _) => LfCard(
          child: Text('Could not load voice notes.',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        data: (list) {
          if (list.isEmpty) {
            return LfCard(
              child: Text('No voice notes yet. Tap the mic to add one.',
                  style: Theme.of(context).textTheme.bodyMedium),
            );
          }
          return Column(children: [
            for (final note in list)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                child: _VoiceNoteTile(
                  note: note,
                  onDelete: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete voice note?'),
                        content: const Text(
                            'The audio and transcript will be permanently removed.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete',
                                style: TextStyle(color: AppColors.hot)),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await ref
                        .read(leadRepositoryProvider)
                        .deleteVoiceNote(note.id);
                    ref.invalidate(voiceNotesProvider(leadId));
                  },
                ),
              ),
          ]);
        },
      ),
    ]);
  }
}

class _VoiceNoteTile extends StatefulWidget {
  const _VoiceNoteTile({required this.note, required this.onDelete});

  final VoiceNote note;
  final Future<void> Function() onDelete;

  @override
  State<_VoiceNoteTile> createState() => _VoiceNoteTileState();
}

class _VoiceNoteTileState extends State<_VoiceNoteTile> {
  final _player = AudioPlayer();
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _playing = s.playing;
        _loading = s.processingState == ProcessingState.loading ||
            s.processingState == ProcessingState.buffering;
      });
      if (s.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
    _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    // Lazy-load the source only when the user actually presses play.
    if (_player.audioSource == null) {
      final url = widget.note.audioUrl;
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Audio isn't available offline.")),
        );
        return;
      }
      await _player.setUrl(url);
    }
    await _player.play();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = context.lf;
    final total = _duration == Duration.zero
        ? Duration(milliseconds: widget.note.durationMs ?? 0)
        : _duration;
    final progress = total.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return LfCard(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _PlayButton(playing: _playing, loading: _loading, onTap: _toggle),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                DateFormat('d MMM · h:mm a').format(widget.note.createdAt),
                style: text.labelLarge?.copyWith(color: c.ink),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: c.hairline,
                  valueColor: const AlwaysStoppedAnimation(AppColors.iris),
                ),
              ),
              const SizedBox(height: 4),
              Text('${_fmt(_position)} / ${_fmt(total)}',
                  style: text.labelSmall?.copyWith(color: c.inkTertiary)),
            ]),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline_rounded, color: c.inkTertiary),
            onPressed: widget.onDelete,
            tooltip: 'Delete voice note',
          ),
        ]),
        if ((widget.note.summary ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x3),
          Text('Summary',
              style: text.labelSmall?.copyWith(color: c.inkTertiary)),
          const SizedBox(height: 4),
          Text(widget.note.summary!, style: text.bodyMedium),
        ],
        if ((widget.note.transcript ?? '').isNotEmpty) ...[
          const SizedBox(height: AppSpacing.x3),
          Text('Transcript',
              style: text.labelSmall?.copyWith(color: c.inkTertiary)),
          const SizedBox(height: 4),
          Text(widget.note.transcript!,
              style: text.bodySmall?.copyWith(color: c.inkSecondary)),
        ],
      ]),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton(
      {required this.playing, required this.loading, required this.onTap});

  final bool playing;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.iris,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: loading ? null : onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: loading
              ? const Center(
                  child: SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                )
              : Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.white, size: 26,
                ),
        ),
      ),
    );
  }
}
