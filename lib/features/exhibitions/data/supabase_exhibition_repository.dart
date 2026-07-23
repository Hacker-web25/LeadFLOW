import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/result.dart';
import '../domain/exhibition.dart';
import '../domain/exhibition_repository.dart';

class SupabaseExhibitionRepository implements ExhibitionRepository {
  SupabaseExhibitionRepository(this._client);

  final SupabaseClient _client;

  String get _uid => _client.auth.currentUser!.id;

  Exhibition _fromRow(Map<String, dynamic> row) => Exhibition(
        id: row['id'] as String,
        name: row['name'] as String,
        createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      );

  @override
  Future<Result<List<Exhibition>>> listAll() async {
    try {
      final rows = await _client
          .from('exhibitions')
          .select()
          .eq('owner_id', _uid)
          .order('created_at', ascending: false);
      return Ok(rows.map((r) => _fromRow(r as Map<String, dynamic>)).toList());
    } catch (e) {
      return Err(AppFailure("Couldn't load folders.", cause: e));
    }
  }

  @override
  Future<Result<Exhibition>> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return const Err(AppFailure('Give the folder a name.'));
    }
    try {
      // Idempotent: if it already exists, hand back the existing row.
      final existing = await _client
          .from('exhibitions')
          .select()
          .eq('owner_id', _uid)
          .eq('name', trimmed)
          .maybeSingle();
      if (existing != null) return Ok(_fromRow(existing));

      final row = await _client
          .from('exhibitions')
          .insert({'owner_id': _uid, 'name': trimmed})
          .select()
          .single();
      return Ok(_fromRow(row));
    } catch (e) {
      return Err(AppFailure("Couldn't create the folder.", cause: e));
    }
  }

  @override
  Future<Result<Exhibition>> rename({
    required String id,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      return const Err(AppFailure('Give the folder a name.'));
    }
    try {
      // Read the current name so we know what to rewrite on leads.
      final current = await _client
          .from('exhibitions')
          .select()
          .eq('id', id)
          .single();
      final oldName = current['name'] as String;

      // If a folder with the target name already exists, refuse — the
      // (owner_id, name) unique constraint would blow up anyway.
      if (trimmed.toLowerCase() != oldName.toLowerCase()) {
        final clash = await _client
            .from('exhibitions')
            .select('id')
            .eq('owner_id', _uid)
            .eq('name', trimmed)
            .maybeSingle();
        if (clash != null) {
          return const Err(AppFailure(
              'A folder with that name already exists.'));
        }
      }

      // Update the exhibition row.
      final updatedRow = await _client
          .from('exhibitions')
          .update({'name': trimmed})
          .eq('id', id)
          .select()
          .single();

      // Bulk-update every lead tagged with the old name.
      await _client
          .from('leads')
          .update({'event_name': trimmed})
          .eq('owner_id', _uid)
          .eq('event_name', oldName);

      return Ok(_fromRow(updatedRow));
    } catch (e) {
      return Err(AppFailure("Couldn't rename the folder.", cause: e));
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      // Read the name so we can untag every lead pointing at it.
      final row = await _client
          .from('exhibitions')
          .select('name')
          .eq('id', id)
          .maybeSingle();
      if (row != null) {
        final name = row['name'] as String;
        await _client
            .from('leads')
            .update({'event_name': null})
            .eq('owner_id', _uid)
            .eq('event_name', name);
      }
      await _client.from('exhibitions').delete().eq('id', id);
      return const Ok(null);
    } catch (e) {
      return Err(AppFailure("Couldn't delete the folder.", cause: e));
    }
  }
}
