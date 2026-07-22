// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:js_interop';
import 'dart:typed_data';

/// Bridges to the same `leadflowFetchBytes` JS helper used by the image
/// pipeline (see `web/tesseract_bridge.js`) — grabs the bytes of a
/// `blob:` URL that `record` returned on `stop()`.
@JS('leadflowFetchBytes')
external JSPromise<JSUint8Array?> _leadflowFetchBytes(JSString url);

Future<Uint8List?> readAudioBytes(String blobUrl) async {
  try {
    final result = await _leadflowFetchBytes(blobUrl.toJS).toDart;
    if (result == null) return null;
    return result.toDart;
  } catch (_) {
    return null;
  }
}
