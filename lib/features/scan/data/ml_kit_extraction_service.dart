// Conditional export: real ML Kit impl on mobile, no-op stub on web/desktop.
// google_mlkit_text_recognition only ships iOS + Android native code, so it
// must not be imported at all on web (would fail to compile the JS bundle).
export 'ml_kit_extraction_service_stub.dart'
    if (dart.library.io) 'ml_kit_extraction_service_io.dart';
