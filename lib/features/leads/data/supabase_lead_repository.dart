import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';

import '../../../core/utils/result.dart';
import '../../follow_ups/domain/follow_up.dart';
import '../../scan/data/image_bytes.dart';
import '../../voice_note/domain/voice_note.dart';
import '../domain/lead.dart';
import '../domain/lead_repository.dart';
import 'lead_dto.dart';

const _leadSelect = '*, contacts(*), companies(*)';

/// Production implementation backed by Supabase (PostgREST + realtime).
class SupabaseLeadRepository implements LeadRepository {
  SupabaseLeadRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  @override
  Stream<List<Lead>> watchLeads() async* {
    // Poll instead of Realtime. Rationale: Supabase Realtime requires the
    // table to be enabled in the project's Replication settings; when it
    // isn't, `.stream(...)` throws on subscription and the whole stream
    // dies (that's the "Something went wrong" the user hit). Polling every
    // few seconds is boring and unconditionally correct.
    //
    // Manual refresh: any writer (scan save, bulk edit, xlsx import) can
    // still call `ref.invalidate(leadsStreamProvider)` to force an
    // immediate re-fetch instead of waiting for the next tick.
    yield const [];

    // Wait briefly for auth to restore on cold start.
    for (var i = 0; i < 20 && _client.auth.currentUser == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (_client.auth.currentUser == null) return;

    // Immediate fetch so the UI sees data on first frame.
    try {
      yield await _fetchAll();
    } catch (_) {
      // Keep the empty emission — the poll loop below will retry.
    }

    while (true) {
      await Future<void>.delayed(const Duration(seconds: 6));
      try {
        yield await _fetchAll();
      } catch (_) {
        // Swallow transient errors; try again on the next tick.
      }
    }
  }

  Future<List<Lead>> _fetchAll() async {
    final rows = await _client
        .from('leads')
        .select(_leadSelect)
        .order('captured_at', ascending: false);
    return rows.map(LeadDto.fromJoinedRow).toList();
  }

  @override
  Future<Result<Lead>> getLead(String id) async {
    try {
      final row = await _client.from('leads').select(_leadSelect).eq('id', id).single();
      return Ok(LeadDto.fromJoinedRow(row));
    } catch (e) {
      return Err(AppFailure('Could not load this lead. Check your connection.', cause: e));
    }
  }

  @override
  Future<Result<Lead>> saveLead(Lead lead) async {
    try {
      // 1. Company: reuse an existing row with the same (owner_id, name)
      // to satisfy the unique constraint. Multiple cards from the same
      // company all point at one row — the intended behaviour.
      String? companyId;
      if (lead.company != null) {
        companyId = await _resolveCompanyId(lead.company!);
      }
      // 2. Contact.
      await _client.from('contacts').upsert({
        'id': lead.contact.id,
        'owner_id': _uid,
        'company_id': companyId,
        'full_name': lead.contact.fullName,
        'designation': lead.contact.designation,
        'email': lead.contact.email,
        'phone': lead.contact.phone,
        'alt_phone': lead.contact.altPhone,
        'address': lead.contact.address,
      }, onConflict: 'id');
      // 3. Lead — use the resolved company id.
      final leadRow = LeadDto.toRow(lead, ownerId: _uid);
      if (companyId != null) leadRow['company_id'] = companyId;
      await _client.from('leads').upsert(leadRow, onConflict: 'id');
      await _uploadCardImage(lead);
      await _client.from('activities').insert({
        'owner_id': _uid,
        'lead_id': lead.id,
        'type': 'scan',
        'summary': 'Lead captured from business card',
      });
      return Ok(lead);
    } catch (e) {
      return Err(AppFailure('Could not save the lead. It is kept locally — retry when online.', cause: e));
    }
  }

  /// Look up a company by (owner_id, name) — reuse if it exists, insert
  /// otherwise. Returns the actual DB id (which may differ from the
  /// client-generated id when the company already existed).
  Future<String> _resolveCompanyId(Company c) async {
    // Try to find an existing row for this owner + name first.
    final existing = await _client
        .from('companies')
        .select('id')
        .eq('owner_id', _uid)
        .eq('name', c.name)
        .maybeSingle();
    if (existing != null && existing['id'] != null) {
      final id = existing['id'] as String;
      // Merge new non-null fields into the existing row — never destroy
      // data that was already there.
      final patch = <String, dynamic>{};
      if ((c.website ?? '').isNotEmpty) patch['website'] = c.website;
      if ((c.city ?? '').isNotEmpty) patch['city'] = c.city;
      if ((c.country ?? '').isNotEmpty) patch['country'] = c.country;
      if (patch.isNotEmpty) {
        await _client.from('companies').update(patch).eq('id', id);
      }
      return id;
    }
    // No match — insert with the client-side id.
    await _client.from('companies').insert({
      'id': c.id,
      'owner_id': _uid,
      'name': c.name,
      'website': c.website,
      'city': c.city,
      'country': c.country,
    });
    return c.id;
  }

  /// Uploads the scanned card to the private bucket and records it.
  /// Non-fatal: a failed upload never blocks saving the lead. Works on
  /// mobile (file path) and web (blob URL via imageToBase64).
  ///
  /// Errors are logged in debug mode so silent upload failures don't
  /// mysteriously leave leads without thumbnails.
  Future<void> _uploadCardImage(Lead lead) async {
    final path = lead.cardImagePath;
    if (path == null || path.isEmpty) {
      if (kDebugMode) debugPrint('[card image] no path on lead ${lead.id}');
      return;
    }
    try {
      final bytes = await _readImageBytes(path);
      if (bytes == null || bytes.isEmpty) {
        if (kDebugMode) {
          debugPrint('[card image] could not read bytes for ${lead.id} '
              '(path prefix: ${path.length > 24 ? path.substring(0, 24) : path})');
        }
        return;
      }
      final storagePath = '$_uid/${lead.id}/front.jpg';
      await _client.storage.from(AppConfig.cardBucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: const FileOptions(
                upsert: true, contentType: 'image/jpeg'),
          );
      await _client.from('business_card_images').upsert({
        'owner_id': _uid,
        'lead_id': lead.id,
        'storage_path': storagePath,
        'side': 'front',
      }, onConflict: 'lead_id,side', ignoreDuplicates: false);
      if (kDebugMode) debugPrint('[card image] uploaded $storagePath');
    } catch (e, st) {
      // Keep the lead save successful even when the image fails, but log
      // loudly so the user can act on RLS / bucket / policy misconfig.
      if (kDebugMode) {
        debugPrint('[card image] upload failed for ${lead.id}: $e\n$st');
      }
    }
  }

  /// Unified byte-reader across mobile file paths and web blob URLs.
  Future<Uint8List?> _readImageBytes(String pathOrUrl) async {
    try {
      if (!kIsWeb && pathOrUrl.startsWith('/')) {
        final file = File(pathOrUrl);
        if (!file.existsSync()) return null;
        return await file.readAsBytes();
      }
      // Web (blob URL) OR anything else that isn't a local file path.
      final b64 = await imageToBase64(pathOrUrl);
      if (b64 == null || b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Result<Lead>> updateLead(Lead lead) async {
    try {
      String? companyId;
      if (lead.company != null) {
        companyId = await _resolveCompanyId(lead.company!);
      }
      await _client.from('contacts').upsert({
        'id': lead.contact.id, 'owner_id': _uid,
        'company_id': companyId,
        'full_name': lead.contact.fullName,
        'designation': lead.contact.designation,
        'email': lead.contact.email, 'phone': lead.contact.phone,
        'alt_phone': lead.contact.altPhone, 'address': lead.contact.address,
      }, onConflict: 'id');
      final leadRow = LeadDto.toRow(lead, ownerId: _uid);
      if (companyId != null) leadRow['company_id'] = companyId;
      await _client.from('leads').upsert(leadRow, onConflict: 'id');
      await _client.from('activities').insert({
        'owner_id': _uid, 'lead_id': lead.id,
        'type': 'status_change', 'summary': 'Lead details updated',
      });
      return Ok(lead);
    } catch (e) {
      return Err(AppFailure('Could not update the lead.', cause: e));
    }
  }

  @override
  Future<Result<String?>> cardImageUrl(Lead lead) async {
    try {
      final row = await _client
          .from('business_card_images')
          .select('storage_path')
          .eq('lead_id', lead.id)
          .maybeSingle();
      if (row == null) return const Ok(null);
      final url = await _client.storage
          .from(AppConfig.cardBucket)
          .createSignedUrl(row['storage_path'] as String, 3600);
      return Ok(url);
    } catch (e) {
      return const Ok(null);
    }
  }

  @override
  Future<Result<void>> deleteLead(String id) async {
    try {
      await _client.from('leads').delete().eq('id', id);
      return const Ok(null);
    } catch (e) {
      return Err(AppFailure('Could not delete the lead.', cause: e));
    }
  }

  @override
  Future<Result<List<Activity>>> recentActivity({int limit = 10}) async {
    try {
      final rows = await _client
          .from('activities')
          .select()
          .order('occurred_at', ascending: false)
          .limit(limit);
      return Ok(rows.map(_activityFromRow).toList());
    } catch (e) {
      return Err(AppFailure('Could not load activity.', cause: e));
    }
  }

  @override
  Future<Result<List<Activity>>> activityForLead(String leadId) async {
    try {
      final rows = await _client
          .from('activities')
          .select()
          .eq('lead_id', leadId)
          .order('occurred_at', ascending: false);
      return Ok(rows.map(_activityFromRow).toList());
    } catch (e) {
      return Err(AppFailure('Could not load activity.', cause: e));
    }
  }

  Activity _activityFromRow(Map<String, dynamic> row) => Activity(
        id: row['id'] as String,
        leadId: row['lead_id'] as String,
        summary: row['summary'] as String,
        type: switch (row['type'] as String) {
          'note' => ActivityType.note,
          'call' => ActivityType.call,
          'email' => ActivityType.email,
          'meeting' => ActivityType.meeting,
          'status_change' => ActivityType.statusChange,
          'follow_up_done' => ActivityType.followUpDone,
          _ => ActivityType.scan,
        },
        occurredAt: DateTime.parse(row['occurred_at'] as String).toLocal(),
      );

  @override
  Stream<List<FollowUp>> watchFollowUps() {
    return _client
        .from('follow_ups')
        .stream(primaryKey: ['id'])
        .eq('owner_id', _uid)
        .asyncMap((_) async {
          final rows = await _client
              .from('follow_ups')
              .select('*, leads(contacts(full_name), companies(name))')
              .eq('status', 'pending')
              .order('due_at');
          return rows.map(LeadDto.followUpFromRow).toList();
        });
  }

  @override
  Future<Result<void>> completeFollowUp(String id) async {
    try {
      await _client.from('follow_ups').update({
        'status': 'done',
        'completed_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);
      return const Ok(null);
    } catch (e) {
      return Err(AppFailure('Could not update the follow-up.', cause: e));
    }
  }

  static const _voiceBucket = 'voice-notes';

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
    try {
      // 1. Upload the raw audio into the private bucket first — if this
      // fails we don't want a dangling DB row.
      final id = const Uuid().v4();
      final path = '$_uid/$leadId/$id.$fileExt';
      await _client.storage.from(_voiceBucket).uploadBinary(
            path,
            audioBytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _contentTypeFor(fileExt),
            ),
          );
      // 2. Persist the row. Storage upload succeeded.
      final row = await _client.from('voice_notes').insert({
        'id': id,
        'owner_id': _uid,
        'lead_id': leadId,
        'storage_path': path,
        'transcript': transcript,
        'summary': summary,
        'language': language,
        'duration_ms': durationMs,
        'file_ext': fileExt,
      }).select().single();
      // 3. Signed URL so the caller can play immediately.
      final url = await _client.storage
          .from(_voiceBucket)
          .createSignedUrl(path, 3600);
      return Ok(_voiceNoteFromRow(row).copyWith(audioUrl: url));
    } catch (e) {
      return Err(AppFailure(
          "Couldn't save this voice note. It's still on your device — retry.",
          cause: e));
    }
  }

  @override
  Future<Result<List<VoiceNote>>> voiceNotesForLead(String leadId) async {
    try {
      final rows = await _client
          .from('voice_notes')
          .select()
          .eq('lead_id', leadId)
          .order('created_at', ascending: false);
      final notes = <VoiceNote>[];
      for (final row in rows) {
        final note = _voiceNoteFromRow(row as Map<String, dynamic>);
        try {
          final url = await _client.storage
              .from(_voiceBucket)
              .createSignedUrl(note.storagePath, 3600);
          notes.add(note.copyWith(audioUrl: url));
        } catch (_) {
          notes.add(note);
        }
      }
      return Ok(notes);
    } catch (e) {
      return Err(AppFailure("Couldn't load voice notes.", cause: e));
    }
  }

  @override
  Future<Result<void>> deleteVoiceNote(String id) async {
    try {
      // Read the storage path so we can remove the blob too.
      final row = await _client
          .from('voice_notes')
          .select('storage_path')
          .eq('id', id)
          .maybeSingle();
      await _client.from('voice_notes').delete().eq('id', id);
      if (row != null && row['storage_path'] != null) {
        try {
          await _client.storage
              .from(_voiceBucket)
              .remove([row['storage_path'] as String]);
        } catch (_) {/* row is gone; orphan blob is harmless */}
      }
      return const Ok(null);
    } catch (e) {
      return Err(AppFailure("Couldn't delete this voice note.", cause: e));
    }
  }

  static String _contentTypeFor(String ext) => switch (ext.toLowerCase()) {
        'webm' => 'audio/webm',
        'wav' => 'audio/wav',
        'ogg' => 'audio/ogg',
        _ => 'audio/mp4',
      };

  VoiceNote _voiceNoteFromRow(Map<String, dynamic> r) => VoiceNote(
        id: r['id'] as String,
        leadId: r['lead_id'] as String,
        storagePath: r['storage_path'] as String,
        createdAt: DateTime.parse(r['created_at'] as String).toLocal(),
        transcript: r['transcript'] as String?,
        summary: r['summary'] as String?,
        language: r['language'] as String?,
        durationMs: r['duration_ms'] as int?,
        fileExt: r['file_ext'] as String?,
      );
}
