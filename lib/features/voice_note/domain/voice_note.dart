import 'package:flutter/foundation.dart';

/// Persistent record of a single voice-note recording.
///
/// The audio itself lives in the Supabase `voice-notes` bucket; [audioUrl]
/// is a short-lived signed URL for playback (regenerated on load — never
/// stored). [transcript] is what Whisper heard, [summary] is the AI-clean
/// paragraph derived from it.
@immutable
class VoiceNote {
  const VoiceNote({
    required this.id,
    required this.leadId,
    required this.storagePath,
    required this.createdAt,
    this.transcript,
    this.summary,
    this.language,
    this.durationMs,
    this.fileExt,
    this.audioUrl,
  });

  final String id;
  final String leadId;
  final String storagePath;
  final DateTime createdAt;
  final String? transcript;
  final String? summary;
  final String? language;
  final int? durationMs;
  final String? fileExt;

  /// Signed, short-lived download URL. Populated lazily when the list is
  /// loaded; never persisted.
  final String? audioUrl;

  VoiceNote copyWith({String? audioUrl}) => VoiceNote(
        id: id,
        leadId: leadId,
        storagePath: storagePath,
        createdAt: createdAt,
        transcript: transcript,
        summary: summary,
        language: language,
        durationMs: durationMs,
        fileExt: fileExt,
        audioUrl: audioUrl ?? this.audioUrl,
      );
}
