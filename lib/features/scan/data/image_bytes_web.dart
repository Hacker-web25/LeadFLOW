// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

/// Bridges to a small JS helper in tesseract_bridge.js that fetches a
/// blob:/data: URL and returns a Uint8Array. Simpler and more compatible
/// across package:web versions than doing arrayBuffer() from Dart.
@JS('leadflowFetchBytes')
external JSPromise<JSUint8Array?> _leadflowFetchBytes(JSString url);

Future<String?> imageToBase64(String url) async {
  try {
    final result = await _leadflowFetchBytes(url.toJS).toDart;
    if (result == null) return null;
    final Uint8List bytes = result.toDart;
    return base64Encode(bytes);
  } catch (_) {
    return null;
  }
}
