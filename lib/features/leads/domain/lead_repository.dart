import 'dart:typed_data';

import '../../../core/utils/result.dart';
import '../../follow_ups/domain/follow_up.dart';
import '../../voice_note/domain/voice_note.dart';
import 'lead.dart';

/// Contract for lead persistence. Presentation depends only on this;
/// implementations: [SupabaseLeadRepository] (production) and
/// [MockLeadRepository] (demo mode & tests).
abstract interface class LeadRepository {
  /// Reactive stream of all leads for the signed-in user.
  Stream<List<Lead>> watchLeads();

  Future<Result<Lead>> getLead(String id);
  Future<Result<Lead>> saveLead(Lead lead);
  Future<Result<Lead>> updateLead(Lead lead);
  Future<Result<String?>> cardImageUrl(Lead lead);
  Future<Result<void>> deleteLead(String id);

  /// Move a lead to a different folder (or null to untag it). Used when
  /// the user forgot to pick a folder while scanning and wants to
  /// reassign an existing lead from Lead Detail.
  Future<Result<void>> setLeadFolder({
    required String leadId,
    required String? folderName,
  });

  Future<Result<List<Activity>>> recentActivity({int limit = 10});
  Future<Result<List<Activity>>> activityForLead(String leadId);

  Stream<List<FollowUp>> watchFollowUps();
  Future<Result<void>> completeFollowUp(String id);

  /// Upload the audio bytes and persist a voice-note row. Returns the
  /// stored [VoiceNote] with signed [VoiceNote.audioUrl] populated for
  /// immediate playback.
  Future<Result<VoiceNote>> saveVoiceNote({
    required String leadId,
    required Uint8List audioBytes,
    required String fileExt,
    String? transcript,
    String? summary,
    String? language,
    int? durationMs,
  });

  /// Voice notes for one lead, newest first. `audioUrl` on each entry is
  /// a fresh signed URL.
  Future<Result<List<VoiceNote>>> voiceNotesForLead(String leadId);

  Future<Result<void>> deleteVoiceNote(String id);
}
