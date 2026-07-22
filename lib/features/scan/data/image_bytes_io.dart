import 'dart:convert';
import 'dart:io';

/// Reads a local file path and returns base64 bytes (mobile/desktop).
Future<String?> imageToBase64(String path) async {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    return base64Encode(await file.readAsBytes());
  } catch (_) {
    return null;
  }
}
