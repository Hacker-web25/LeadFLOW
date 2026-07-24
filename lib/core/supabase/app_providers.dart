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
  //   1. Groq vision (Llama-4 Scout) — free tier via GROQ_API_KEY. Sees
  //      the image directly; industry-leading throughput. Best-quality
  //      output for real-world exhibition cards. This is the ONE that
  //      fixes the "address is cut off / double-comma" bugs.
  //   2. Gemini vision — second AI-vision safety net.
  //   3. NVIDIA vision — third AI safety net if you set NVIDIA_API_KEY.
  //   4. ML Kit — on-device fallback for mobile (no network needed).
  //   5. OCR.space — hosted OCR (works on web).
  //   6. tesseract.js — last-resort on-device on web.
  //
  // Rationale: the two heavyweight vision LLMs run FIRST because their
  // output is already structured and cleaner than any parser-over-OCR
  // pipeline can produce. The classic OCR tiers stay as a safety net
  // for offline / quota-exhausted situations.
  return const GroqVisionExtractionService(
    GeminiCardExtractionService(
      NvidiaCardExtractionService(
        MlKitExtractionService(
          OcrSpaceExtractionService(
            TesseractCardExtractionService(),
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
