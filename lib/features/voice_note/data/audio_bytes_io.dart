import 'dart:io';
import 'dart:typed_data';

/// Read a local file (mobile / desktop) written by the `record` package.
Future<Uint8List?> readAudioBytes(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
