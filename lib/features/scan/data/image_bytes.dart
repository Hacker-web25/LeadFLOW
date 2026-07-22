export 'image_bytes_stub.dart'
    if (dart.library.js_interop) 'image_bytes_web.dart'
    if (dart.library.io) 'image_bytes_io.dart';
