/// Environment configuration.
///
/// Values are injected at build time:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
///
/// When credentials are absent the app boots in [demoMode] with an in-memory
/// repository seeded with realistic exhibition data, so the product can be
/// experienced end-to-end before a backend exists.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Google Gemini API key for AI-powered card extraction.
  /// Pass with --dart-define=GEMINI_API_KEY=...  When absent, extraction
  /// falls back to on-device OCR (tesseract.js on web).
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
  static bool get hasGemini => geminiApiKey.isNotEmpty;

  /// NVIDIA NIM API key (nvapi-...) for AI card extraction via a vision model.
  /// Pass with --dart-define=NVIDIA_API_KEY=...
  static const nvidiaApiKey = String.fromEnvironment('NVIDIA_API_KEY');
  static bool get hasNvidia => nvidiaApiKey.isNotEmpty;

  /// OCR.space free API key — the primary OCR path on WEB builds.
  /// 500 requests/day free, no credit card. Sign up at
  /// <https://ocr.space/ocrapi> (email only).
  /// Pass with --dart-define=OCR_SPACE_API_KEY=K12345...
  ///
  /// On mobile the app prefers on-device Google ML Kit (no key needed),
  /// so this is only strictly required for the Chrome/web build.
  static const ocrSpaceApiKey = String.fromEnvironment('OCR_SPACE_API_KEY');
  static bool get hasOcrSpace => ocrSpaceApiKey.isNotEmpty;

  /// Groq API key (gsk_...) — powers the voice-note transcription
  /// via Whisper large-v3. Free tier: ~14k requests/day, email signup at
  /// <https://console.groq.com/keys>. No credit card required.
  /// Pass with --dart-define=GROQ_API_KEY=gsk_...
  static const groqApiKey = String.fromEnvironment('GROQ_API_KEY');
  static bool get hasGroq => groqApiKey.isNotEmpty;

  /// Google Cloud Vision API key (AIza…) — the highest-accuracy OCR
  /// tier. First 1000 requests/month are free. Enable the "Cloud Vision
  /// API" in Google Cloud Console, create an API key, and restrict it
  /// to the Vision API only.
  /// Pass with --dart-define=GCV_API_KEY=AIza...
  static const googleCloudVisionKey =
      String.fromEnvironment('GCV_API_KEY');
  static bool get hasGoogleCloudVision => googleCloudVisionKey.isNotEmpty;

  static bool get demoMode => supabaseUrl.isEmpty || supabaseAnonKey.isEmpty;

  static const appName = 'LeadFlow AI';
  static const tagline = 'Scan once. Organize forever.';
  static const cardBucket = 'business-cards';
}
