import 'package:uuid/uuid.dart';

import '../../../core/utils/result.dart';
import '../domain/exhibition.dart';
import '../domain/exhibition_repository.dart';

/// In-memory implementation used in demo mode.
class MockExhibitionRepository implements ExhibitionRepository {
  static const _uuid = Uuid();
  final Map<String, Exhibition> _byId = {};

  @override
  Future<Result<List<Exhibition>>> listAll() async {
    final list = _byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Ok(list);
  }

  @override
  Future<Result<Exhibition>> create(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return const Err(AppFailure('Give the folder a name.'));
    final existing = _byId.values
        .where((e) => e.name.toLowerCase() == trimmed.toLowerCase())
        .firstOrNull;
    if (existing != null) return Ok(existing);
    final e = Exhibition(
        id: _uuid.v4(), name: trimmed, createdAt: DateTime.now());
    _byId[e.id] = e;
    return Ok(e);
  }

  @override
  Future<Result<Exhibition>> rename({
    required String id,
    required String newName,
  }) async {
    final trimmed = newName.trim();
    final existing = _byId[id];
    if (existing == null) return const Err(AppFailure('Folder not found.'));
    if (trimmed.isEmpty) return const Err(AppFailure('Give the folder a name.'));
    if (_byId.values.any((e) =>
        e.id != id && e.name.toLowerCase() == trimmed.toLowerCase())) {
      return const Err(AppFailure('A folder with that name already exists.'));
    }
    _byId[id] = existing.copyWith(name: trimmed);
    return Ok(_byId[id]!);
  }

  @override
  Future<Result<void>> delete(String id) async {
    _byId.remove(id);
    return const Ok(null);
  }
}
