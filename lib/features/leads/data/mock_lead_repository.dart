import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../core/utils/result.dart';
import '../../follow_ups/domain/follow_up.dart';
import '../../voice_note/domain/voice_note.dart';
import '../domain/lead.dart';
import '../domain/lead_repository.dart';

/// In-memory repository used only when Supabase credentials are absent.
/// Starts empty — no hardcoded content; everything comes from user actions.
class MockLeadRepository implements LeadRepository {
  MockLeadRepository() {
    _leadsCtrl = StreamController<List<Lead>>.broadcast(
        onListen: () => _leadsCtrl.add(List.of(_leads)));
    _fuCtrl = StreamController<List<FollowUp>>.broadcast(
        onListen: () => _fuCtrl.add(const []));
  }

  static const _uuid = Uuid();
  final List<Lead> _leads = [];
  final List<FollowUp> _followUps = [];
  final List<Activity> _activities = [];
  late final StreamController<List<Lead>> _leadsCtrl;
  late final StreamController<List<FollowUp>> _fuCtrl;

  void _emit() {
    _leadsCtrl.add(List.of(_leads));
    _fuCtrl.add(_followUps.where((f) => f.status == FollowUpStatus.pending).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt)));
  }

  @override
  Stream<List<Lead>> watchLeads() => _leadsCtrl.stream;

  @override
  Future<Result<Lead>> getLead(String id) async {
    final lead = _leads.where((l) => l.id == id).firstOrNull;
    return lead == null
        ? const Err(AppFailure('This lead no longer exists.'))
        : Ok(lead);
  }

  @override
  Future<Result<Lead>> saveLead(Lead lead) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _leads.removeWhere((l) => l.id == lead.id);
    _leads.insert(0, lead);
    _activities.insert(0, Activity(
        id: _uuid.v4(), leadId: lead.id,
        summary: 'Captured ${lead.contact.fullName} · ${lead.companyName}',
        type: ActivityType.scan, occurredAt: DateTime.now()));
    _emit();
    return Ok(lead);
  }

  @override
  Future<Result<Lead>> updateLead(Lead lead) async {
    _leads.removeWhere((l) => l.id == lead.id);
    _leads.insert(0, lead);
    _activities.insert(0, Activity(
        id: _uuid.v4(), leadId: lead.id, summary: 'Lead details updated',
        type: ActivityType.statusChange, occurredAt: DateTime.now()));
    _emit();
    return Ok(lead);
  }

  @override
  Future<Result<String?>> cardImageUrl(Lead lead) async {
    final p = lead.cardImagePath;
    return Ok(p != null && p.startsWith('/') ? p : null);
  }

  @override
  Future<Result<void>> deleteLead(String id) async {
    _leads.removeWhere((l) => l.id == id);
    _followUps.removeWhere((f) => f.leadId == id);
    _emit();
    return const Ok(null);
  }

  @override
  Future<Result<void>> setLeadFolder({
    required String leadId,
    required String? folderName,
  }) async {
    final i = _leads.indexWhere((l) => l.id == leadId);
    if (i == -1) return const Err(AppFailure('Lead not found.'));
    final trimmed = folderName?.trim();
    final value = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final old = _leads[i];
    _leads[i] = Lead(
      id: old.id,
      contact: old.contact,
      company: old.company,
      eventName: value,
      status: old.status,
      temperature: old.temperature,
      timeline: old.timeline,
      customerType: old.customerType,
      isDecisionMaker: old.isDecisionMaker,
      exportRequirement: old.exportRequirement,
      salesTeamRequired: old.salesTeamRequired,
      additionalNotes: old.additionalNotes,
      capturedAt: old.capturedAt,
      cardImagePath: old.cardImagePath,
    );
    _emit();
    return const Ok(null);
  }

  @override
  Future<Result<List<Activity>>> recentActivity({int limit = 10}) async =>
      Ok(_activities.take(limit).toList());

  @override
  Future<Result<List<Activity>>> activityForLead(String leadId) async =>
      Ok(_activities.where((a) => a.leadId == leadId).toList());

  @override
  Stream<List<FollowUp>> watchFollowUps() => _fuCtrl.stream;

  @override
  Future<Result<void>> completeFollowUp(String id) async {
    final i = _followUps.indexWhere((f) => f.id == id);
    if (i == -1) return const Err(AppFailure('Follow-up not found.'));
    _followUps[i] = _followUps[i].copyWith(status: FollowUpStatus.done);
    _emit();
    return const Ok(null);
  }

  final List<VoiceNote> _voiceNotes = [];
  final Map<String, Uint8List> _voiceAudio = {}; // id → bytes for playback

  @override
  Future<Result<VoiceNote>> saveVoiceNote({
    required String leadId,
    required Uint8List audioBytes,
    required String fileExt,
    String? transcript,
    String? summary,
    String? language,
    int? durationMs,
  }) async {
    final id = _uuid.v4();
    final note = VoiceNote(
      id: id,
      leadId: leadId,
      storagePath: 'mock/$leadId/$id.$fileExt',
      createdAt: DateTime.now(),
      transcript: transcript,
      summary: summary,
      language: language,
      durationMs: durationMs,
      fileExt: fileExt,
      // Serve back as a data URL so the audio player can play it in demo mode.
      audioUrl: 'data:audio/$fileExt;base64,${base64Encode(audioBytes)}',
    );
    _voiceAudio[id] = audioBytes;
    _voiceNotes.insert(0, note);
    return Ok(note);
  }

  @override
  Future<Result<List<VoiceNote>>> voiceNotesForLead(String leadId) async {
    final list = _voiceNotes.where((n) => n.leadId == leadId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Ok(list);
  }

  @override
  Future<Result<void>> deleteVoiceNote(String id) async {
    _voiceNotes.removeWhere((n) => n.id == id);
    _voiceAudio.remove(id);
    return const Ok(null);
  }
}
