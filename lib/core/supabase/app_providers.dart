import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/actions/data/mock_action_repository.dart';
import '../../features/actions/data/supabase_action_repository.dart';
import '../../features/actions/domain/action_repository.dart';
import '../../features/leads/data/mock_lead_repository.dart';
import '../../features/leads/data/supabase_lead_repository.dart';
import '../../features/leads/domain/lead_repository.dart';
import '../../features/auth/data/demo_auth_repository.dart';
import '../../features/auth/data/supabase_auth_repository.dart';
import '../../features/auth/domain/auth_repository.dart';
import '../../features/scan/data/gemini_card_extraction_service.dart';
import '../../features/scan/data/google_vision_extraction_service.dart';
import '../../features/scan/data/groq_vision_extraction_service.dart';
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

final _mockActionRepo = MockActionRepository();

final actionRepositoryProvider = Provider<ActionRepository>((ref) {
  if (AppConfig.demoMode) return _mockActionRepo;
  return SupabaseActionRepository(ref.watch(supabaseClientProvider));
});

final cardExtractionServiceProvider = Provider<CardExtractionService>((ref) {
  // Extraction chain, each tier falling back to the next when it fails,
  // times out, or returns nothing useful:
  //
  //   1. Google Cloud Vision + Groq organizer — highest-accuracy OCR
  //      on the market, then LLM structures the fields. Free tier
  //      covers 1000 cards/month. THIS is the tier that turns real
  //      exhibition cards into clean structured data.
  //   2. Groq vision (Llama-4 Scout) — direct image-to-JSON. Fast.
  //   3. Gemini vision — vision-LLM safety net.
  //   4. NVIDIA vision — extra safety net if NVIDIA_API_KEY is set.
  //   5. ML Kit — on-device fallback for mobile (no network).
  //   6. OCR.space — hosted OCR (works on web).
  //   7. tesseract.js — last-resort on-device on web.
  //
  // Any tier failing / timing out / returning empty advances the chain.
  return const GoogleVisionExtractionService(
    GroqVisionExtractionService(
      GeminiCardExtractionService(
        NvidiaCardExtractionService(
          MlKitExtractionService(
            OcrSpaceExtractionService(
              TesseractCardExtractionService(),
            ),
          ),
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
