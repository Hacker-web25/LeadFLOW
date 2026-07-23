import '../../../core/utils/result.dart';
import 'exhibition.dart';

/// Contract for exhibition (folder) persistence.
abstract interface class ExhibitionRepository {
  /// All folders the signed-in user has ever created, newest first.
  Future<Result<List<Exhibition>>> listAll();

  /// Create a new folder. Returns the persisted [Exhibition] (with server
  /// id + creation timestamp). If a folder with the same trimmed name
  /// already exists, returns that one instead of erroring — the picker
  /// treats "create" as idempotent for a nicer UX.
  Future<Result<Exhibition>> create(String name);

  /// Rename a folder. Also rewrites `leads.event_name` on every lead
  /// tagged with the old name so the folder membership stays consistent.
  Future<Result<Exhibition>> rename({
    required String id,
    required String newName,
  });

  /// Delete a folder. Leads tagged with it are not deleted — their
  /// `event_name` is cleared so they show up under "Untagged".
  Future<Result<void>> delete(String id);
}
