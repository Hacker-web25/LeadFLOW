// Cross-platform helper: reads audio bytes from whatever `record`'s
// `stop()` returned. On web that's a `blob:` URL; on mobile a file path.
export 'audio_bytes_stub.dart'
    if (dart.library.js_interop) 'audio_bytes_web.dart'
    if (dart.library.io) 'audio_bytes_io.dart';
