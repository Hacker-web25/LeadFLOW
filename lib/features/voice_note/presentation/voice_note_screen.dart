import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../../core/constants/app_radii.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/supabase/app_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/lf_colors.dart';
import '../../../core/widgets/lf_segmented.dart';
import '../../../core/widgets/lf_state_views.dart';
import '../../leads/domain/lead.dart';
import '../../leads/presentation/providers/leads_providers.dart';
import '../data/ai_voice_note_organizer.dart';
import '../data/audio_bytes.dart';
import '../data/groq_whisper_service.dart';
import 'voice_notes_section.dart';

/// Voice note capture: record → upload to Groq Whisper → AI-structure → save.
///
/// Reused from the post-scan screen and from Lead Detail. Multiple voice
/// notes per lead are allowed — each new one appends to notes and updates
/// qualification fields the AI could infer.
class VoiceNoteScreen extends ConsumerStatefulWidget {
  const VoiceNoteScreen({super.key, required this.leadId});

  final String leadId;

  @override
  ConsumerState<VoiceNoteScreen> createState() => _VoiceNoteScreenState();
}

enum _Lang { auto, en, hi }

extension on _Lang {
  String get label => switch (this) {
        _Lang.auto => 'Auto',
        _Lang.en => 'English',
        _Lang.hi => 'Hindi',
      };
  String? get code => switch (this) {
        _Lang.auto => null,
        _Lang.en => 'en',
        _Lang.hi => 'hi',
      };
}

enum _Phase { idle, recording, transcribing, transcribed, saving }

class _VoiceNoteScreenState extends ConsumerState<VoiceNoteScreen>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);
  Timer? _tick;

  _Phase _phase = _Phase.idle;
  _Lang _lang = _Lang.auto;
  Duration _elapsed = Duration.zero;
  String? _audioPath;
  String _transcript = '';
  String? _error;

  @override
  void dispose() {
    _pulse.dispose();
    _tick?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    setState(() {
      _error = null;
      _transcript = '';
      _audioPath = null;
      _elapsed = Duration.zero;
    });

    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        setState(() =>
            _error = 'Microphone permission is required to record voice notes.');
        return;
      }

      // Whisper resamples internally, so keep the browser's / OS's native
      // rate (48 kHz on Chrome, 44.1/48 on mobile). Requesting 16 kHz here
      // sometimes silently reverts to native anyway on Chrome. Bitrate
      // 64 kbps mono keeps a 30 s clip under 300 KB.
      const config = RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
        bitRate: 64000,
      );

      // On web, `path` is only a label; the recorder returns a blob URL.
      final target = 'leadflow-voice-note';
      await _recorder.start(config, path: target);

      // Mic warm-up: the first ~300 ms of a MediaRecorder stream is often
      // silence while the audio pipeline stabilises. If the user speaks
      // during that window Whisper receives an incomplete opening and
      // frequently returns hallucinated stock phrases ("Thank you.").
      // Delay the "recording" UI so users only start speaking once we're
      // actually capturing clean audio.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;

      final start = DateTime.now();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed = DateTime.now().difference(start));
      });
      setState(() => _phase = _Phase.recording);
    } catch (e) {
      setState(() => _error = 'Could not start recording: $e');
    }
  }

  Future<void> _stopAndTranscribe() async {
    _tick?.cancel();
    final recordedFor = _elapsed;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e) {
      setState(() {
        _phase = _Phase.idle;
        _error = 'Could not stop recording: $e';
      });
      return;
    }

    if (path == null) {
      setState(() {
        _phase = _Phase.idle;
        _error = 'Recording produced no audio. Try again.';
      });
      return;
    }

    // Whisper needs ~1.5+ s of speech to decode reliably. Anything shorter
    // is the leading cause of the "Thank you." hallucination — reject
    // client-side so we don't burn a quota call on garbage.
    if (recordedFor < const Duration(milliseconds: 1500)) {
      setState(() {
        _phase = _Phase.idle;
        _error = 'That was too short — record at least 2 seconds.';
      });
      return;
    }

    setState(() {
      _audioPath = path;
      _phase = _Phase.transcribing;
    });

    final text = await GroqWhisperService.transcribe(path, languageHint: _lang.code);
    if (!mounted) return;

    if (text == null || text.isEmpty) {
      setState(() {
        _phase = _Phase.idle;
        _error = 'Couldn\'t make out any speech. Try again — speak clearly, '
            'close to the mic, and for a couple of seconds.';
      });
      return;
    }

    setState(() {
      _transcript = text;
      _phase = _Phase.transcribed;
    });
  }

  Future<void> _save() async {
    final transcript = _transcript.trim();
    final path = _audioPath;
    if (transcript.isEmpty || path == null) return;
    setState(() {
      _phase = _Phase.saving;
      _error = null;
    });

    try {
      // 1. Read the audio bytes we recorded — needed to upload the raw
      // audio so the user can play it back later and verify accuracy.
      final bytes = await readAudioBytes(path);
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _phase = _Phase.transcribed;
          _error = 'Could not read the recorded audio.';
        });
        return;
      }
      final ext = _extFromBytes(bytes);

      // 2. Ask the LLM to structure the transcript into fields + summary.
      // If this fails (no key, rate limit), we still save the raw voice
      // note — the transcript alone is enough for the user to work from.
      final update = await AiVoiceNoteOrganizer.organize(transcript);

      final repo = ref.read(leadRepositoryProvider);

      // 3. Persist the voice note (audio + transcript + summary).
      final saved = await repo.saveVoiceNote(
        leadId: widget.leadId,
        audioBytes: bytes,
        fileExt: ext,
        transcript: transcript,
        summary: update?.summary,
        language: _lang.name,
        durationMs: _elapsed.inMilliseconds,
      );

      // 4. Merge AI-derived qualification fields into the lead (does not
      // touch the notes text — that lives in the discrete voice_notes row now).
      if (update != null && !update.isEmpty) {
        final loaded = await repo.getLead(widget.leadId);
        await loaded.when(
          ok: (lead) => repo.updateLead(_applyQualification(lead, update)),
          err: (_) async => loaded,
        );
      }

      if (!mounted) return;
      saved.when(
        ok: (_) {
          ref.invalidate(leadProvider(widget.leadId));
          ref.invalidate(leadsStreamProvider);
          ref.invalidate(voiceNotesProvider(widget.leadId));
          context.pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice note saved.')),
          );
        },
        err: (f) => setState(() {
          _phase = _Phase.transcribed;
          _error = f.message;
        }),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.transcribed;
        _error = 'Save failed: $e';
      });
    }
  }

  String _extFromBytes(List<int> b) {
    if (b.length >= 4 && b[0] == 0x1A && b[1] == 0x45 && b[2] == 0xDF && b[3] == 0xA3) {
      return 'webm';
    }
    if (b.length >= 8 && b[4] == 0x66 && b[5] == 0x74 && b[6] == 0x79 && b[7] == 0x70) {
      return 'm4a';
    }
    if (b.length >= 4 && b[0] == 0x52 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x46) {
      return 'wav';
    }
    if (b.length >= 4 && b[0] == 0x4F && b[1] == 0x67 && b[2] == 0x67 && b[3] == 0x53) {
      return 'ogg';
    }
    return 'm4a';
  }

  /// Apply only the qualification fields — never touch `additional_notes`
  /// (the audit trail now lives in the voice_notes table).
  Lead _applyQualification(Lead lead, VoiceNoteUpdate update) => lead.copyWith(
        temperature: update.temperature,
        timeline: update.timeline,
        customerType: update.customerType,
        isDecisionMaker: update.isDecisionMaker,
        exportRequirement: update.exportRequirement,
        salesTeamRequired: update.salesTeamRequired,
      );

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final hasTranscript = _transcript.trim().isNotEmpty;
    final busy = _phase == _Phase.transcribing || _phase == _Phase.saving;
    final canRecord = _phase == _Phase.idle;
    final isRecording = _phase == _Phase.recording;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice note'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: busy ? null : () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Speak everything worth remembering — what they need, budget, urgency, next steps. '
                'English or Hindi both work. AI structures it on save.',
                style: text.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.x4),
              AbsorbPointer(
                absorbing: !canRecord && !hasTranscript,
                child: LfSegmented<_Lang>(
                  options: _Lang.values,
                  labelOf: (l) => l.label,
                  value: _lang,
                  onChanged: (v) => setState(() => _lang = v),
                ),
              ),
              const SizedBox(height: AppSpacing.x5),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: context.lf.hairline),
                  ),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: Text(
                      _bodyText(),
                      style: text.bodyLarge?.copyWith(
                          color: hasTranscript ? context.lf.ink : context.lf.inkTertiary),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.x3),
                LfErrorState(message: _error!, onRetry: () => setState(() => _error = null)),
              ],
              const SizedBox(height: AppSpacing.x5),
              _MicButton(
                phase: _phase,
                elapsed: _elapsed,
                pulse: _pulse,
                onTap: () {
                  if (isRecording) {
                    _stopAndTranscribe();
                  } else if (canRecord) {
                    _startRecording();
                  }
                },
                fmt: _fmt,
              ),
              const SizedBox(height: AppSpacing.x5),
              if (hasTranscript && _phase != _Phase.recording)
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _startRecording,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Re-record'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : _save,
                      icon: _phase == _Phase.saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded),
                      label: Text(_phase == _Phase.saving ? 'Structuring…' : 'Save'),
                    ),
                  ),
                ]),
            ],
          ),
        ),
      ),
    );
  }

  String _bodyText() {
    return switch (_phase) {
      _Phase.idle when _transcript.isEmpty =>
        'Tap the mic to start.\n\nRecord however long you need — the whole clip is transcribed at once when you stop.',
      _Phase.recording => 'Recording… tap the mic again to stop.',
      _Phase.transcribing => 'Uploading and transcribing… (usually 1–3 seconds)',
      _ => _transcript,
    };
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.phase,
    required this.elapsed,
    required this.pulse,
    required this.onTap,
    required this.fmt,
  });

  final _Phase phase;
  final Duration elapsed;
  final AnimationController pulse;
  final VoidCallback? onTap;
  final String Function(Duration) fmt;

  @override
  Widget build(BuildContext context) {
    final recording = phase == _Phase.recording;
    final transcribing = phase == _Phase.transcribing;
    final disabled = phase == _Phase.saving || phase == _Phase.transcribing;

    return Column(children: [
      AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final glow = recording ? 0.4 + 0.4 * pulse.value : 0.0;
          return GestureDetector(
            onTap: disabled ? null : onTap,
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: recording
                    ? AppColors.hot
                    : (disabled
                        ? Colors.white.withValues(alpha: 0.08)
                        : AppColors.iris),
                boxShadow: recording
                    ? [
                        BoxShadow(
                            color: AppColors.hot.withValues(alpha: glow),
                            blurRadius: 30,
                            spreadRadius: 4)
                      ]
                    : null,
              ),
              child: transcribing
                  ? const Center(
                      child: SizedBox(
                        width: 26, height: 26,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      ),
                    )
                  : Icon(
                      recording ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 40, color: Colors.white),
            ),
          );
        },
      ),
      const SizedBox(height: AppSpacing.x2),
      Text(
        recording ? fmt(elapsed) : (phase == _Phase.transcribed ? 'Recorded' : ''),
        style: Theme.of(context).textTheme.labelLarge,
      ),
    ]);
  }
}
