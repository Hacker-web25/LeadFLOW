import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/leads/data/mock_lead_repository.dart';
import '../../features/leads/data/supabase_lead_repository.dart';
import '../../features/leads/domain/lead_repository.dart';
import '../../features/auth/data/demo_auth_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/scan/data/gemini_card_extraction_service.dart';
import '../../features/scan/data/ml_kit_extraction_service.dart';
import '../../features/scan/data/nvidia_card_extraction_service.dart';
import '../../features/scan/data/ocr_space_extraction_service.dart';
import '../../features/scan/data/tesseract_card_extraction_service.dart';
import '../../features/scan/domain/card_extraction_service.dart';
import '../config/app_config.dart';

/// Riverpod is the DI container. Repositories resolve here and can be
/// overridden wholesale in tests (`ProviderScope(overrides: [...])`).

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  assert(!AppConfig.demoMode, 'Supabase client requested in demo mode');
  return Supabase.instance.client;
});

final _mockLeadRepo = MockLeadRepository();

final leadRepositoryProvider = Provider<LeadRepository>((ref) {
  if (AppConfig.demoMode) return _mockLeadRepo;
  return SupabaseLeadRepository(ref.watch(supabaseClientProvider));
});

final cardExtractionServiceProvider = Provider<CardExtractionService>((ref) {
  // Extraction chain, each tier falling back to the next:
  //   1. ML Kit         — on-device, mobile only (Android/iOS). No key,
  //                       no network, no cost. On web/desktop this tier
  //                       is a no-op (see ml_kit_extraction_service_stub).
  //   2. OCR.space      — hosted free API (500 req/day). Best web path.
  //                       Requires --dart-define=OCR_SPACE_API_KEY=...
  //   3. NVIDIA vision  — LLM safety net if you supply NVIDIA_API_KEY.
  //   4. Gemini vision  — LLM safety net if you supply GEMINI_API_KEY.
  //   5. tesseract.js   — on-device on web, last resort.
  //
  // Any tier failing / timing out / returning empty advances the chain.
  return const MlKitExtractionService(
    OcrSpaceExtractionService(
      NvidiaCardExtractionService(
        GeminiCardExtractionService(
          TesseractCardExtractionService(),
        ),
      ),
    ),
  );
});


final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (AppConfig.demoMode) return DemoAuthRepository();
  return SupabaseAuthRepository(ref.watch(supabaseClientProvider));
});

final authUserStreamProvider = StreamProvider<AppUser?>(
  (ref) => ref.watch(authRepositoryProvider).watchUser(),
);
