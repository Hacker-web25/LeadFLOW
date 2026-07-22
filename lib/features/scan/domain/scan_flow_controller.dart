import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/supabase/app_providers.dart';
import '../../../core/utils/result.dart';
import '../../exhibitions/data/exhibition_controller.dart';
import '../../leads/domain/lead.dart';
import 'card_extraction_service.dart';

enum ScanStep { idle, preview, extracting, review, questionnaire, saving, done, failed }

@immutable
class ScanFlowState {
  const ScanFlowState({this.step = ScanStep.idle, this.imagePath,
      this.backImagePath, this.extracted, this.draft, this.error});

  final ScanStep step;
  /// Front side of the card. Required to start the flow.
  final String? imagePath;
  /// Optional back side. If present, OCR runs on both and results are merged.
  final String? backImagePath;
  final ExtractedCard? extracted;
  final Lead? draft;
  final String? error;

  ScanFlowState copyWith({ScanStep? step, String? imagePath,
      Object? backImagePath = _sentinel,
      ExtractedCard? extracted, Lead? draft, String? error}) =>
      ScanFlowState(
        step: step ?? this.step,
        imagePath: imagePath ?? this.imagePath,
        backImagePath: backImagePath is _Sentinel
            ? this.backImagePath
            : backImagePath as String?,
        extracted: extracted ?? this.extracted,
        draft: draft ?? this.draft,
        error: error,
      );
}

// Sentinel that lets copyWith distinguish "not passed" from "explicitly null".
class _Sentinel { const _Sentinel(); }
const _sentinel = _Sentinel();

class ScanFlowController extends Notifier<ScanFlowState> {
  static const _uuid = Uuid();

  @override
  ScanFlowState build() => const ScanFlowState();

  /// Front image picked → show preview with Retake / Replace / Use photo.
  void setImage(String path) =>
      state = ScanFlowState(step: ScanStep.preview, imagePath: path);

  /// Optional back image picked. Front must already exist.
  void setBackImage(String path) =>
      state = state.copyWith(backImagePath: path);

  /// Remove the back image without losing the front.
  void removeBackImage() =>
      state = state.copyWith(backImagePath: null);

  void retake() => state = const ScanFlowState();

  /// Use photo(s) → AI extraction on front (and back if present) → draft lead.
  /// Fields from front win; back only fills gaps.
  Future<bool> processImage() async {
    final front = state.imagePath;
    if (front == null) return false;
    state = state.copyWith(step: ScanStep.extracting);

    final extractor = ref.read(cardExtractionServiceProvider);
    final frontResult = await extractor.extract(front);

    ExtractedCard? backCard;
    final back = state.backImagePath;
    if (back != null) {
      final backResult = await extractor.extract(back);
      backCard = backResult.valueOrNull;
    }

    return frontResult.when(
      ok: (frontCard) {
        final merged = _mergeCards(frontCard, backCard);
        state = state.copyWith(
            step: ScanStep.review,
            extracted: merged,
            draft: _draftFrom(merged, front));
        return true;
      },
      err: (f) {
        // Front failed but back may still have something usable.
        if (backCard != null && backCard.confidence > 0) {
          state = state.copyWith(
              step: ScanStep.review,
              extracted: backCard,
              draft: _draftFrom(backCard, front));
          return true;
        }
        state = state.copyWith(step: ScanStep.failed, error: f.message);
        return false;
      },
    );
  }

  /// Extract → save immediately. Skips the review screen entirely.
  /// Returns the saved lead's id (for navigation) or null on failure.
  /// The user can always edit any field later from Lead Detail.
  Future<String?> processAndSave() async {
    final ok = await processImage();
    if (!ok) return null;
    final draft = state.draft;
    if (draft == null) return null;
    state = state.copyWith(step: ScanStep.saving);
    final result = await ref.read(leadRepositoryProvider).saveLead(draft);
    return result.when(
      ok: (lead) {
        state = state.copyWith(step: ScanStep.done);
        return lead.id;
      },
      err: (f) {
        state = state.copyWith(step: ScanStep.failed, error: f.message);
        return null;
      },
    );
  }

  /// Merge two extracted cards: front wins for non-empty fields, back fills
  /// gaps. Confidence is the higher of the two.
  static ExtractedCard _mergeCards(ExtractedCard front, ExtractedCard? back) {
    if (back == null) return front;
    String? pick(String? a, String? b) =>
        (a != null && a.trim().isNotEmpty) ? a : b;
    return ExtractedCard(
      fullName: pick(front.fullName, back.fullName),
      designation: pick(front.designation, back.designation),
      companyName: pick(front.companyName, back.companyName),
      email: pick(front.email, back.email),
      phone: pick(front.phone, back.phone),
      altPhone: pick(front.altPhone, back.altPhone),
      website: pick(front.website, back.website),
      address: pick(front.address, back.address),
      city: pick(front.city, back.city),
      country: pick(front.country, back.country),
      confidence: front.confidence >= back.confidence
          ? front.confidence
          : back.confidence,
    );
  }

  Lead _draftFrom(ExtractedCard card, String imagePath) {
    // Auto-tag with the current exhibition folder, if any.
    final currentEvent =
        ref.read(currentExhibitionProvider).valueOrNull?.name;
    return Lead(
      id: _uuid.v4(),
      contact: Contact(
        id: _uuid.v4(),
        fullName: card.fullName ?? '',
        designation: card.designation,
        email: card.email,
        phone: card.phone,
        altPhone: card.altPhone,
        address: card.address,
      ),
      company: card.companyName == null
          ? null
          : Company(id: _uuid.v4(), name: card.companyName!,
              website: card.website, city: card.city, country: card.country),
      eventName: currentEvent,
      capturedAt: DateTime.now(),
      cardImagePath: imagePath,
    );
  }

  void updateContact(Contact contact) {
    final d = state.draft;
    if (d != null) state = state.copyWith(draft: d.withContact(contact));
  }

  void updateCompany({required String name, String? website, String? city, String? country}) {
    final d = state.draft;
    if (d == null) return;
    final n = name.trim();
    final company = n.isEmpty
        ? null
        : Company(id: d.company?.id ?? _uuid.v4(), name: n,
            website: website?.trim().isEmpty ?? true ? null : website!.trim(),
            city: city?.trim().isEmpty ?? true ? null : city!.trim(),
            country: country?.trim().isEmpty ?? true ? null : country!.trim());
    state = state.copyWith(draft: d.withCompany(company));
  }

  void confirmReview() => state = state.copyWith(step: ScanStep.questionnaire);
  void updateDraft(Lead draft) => state = state.copyWith(draft: draft);

  Future<Result<Lead>> save() async {
    final draft = state.draft;
    if (draft == null) return const Err(AppFailure('Nothing to save.'));
    state = state.copyWith(step: ScanStep.saving);
    final result = await ref.read(leadRepositoryProvider).saveLead(draft);
    result.when(
      ok: (_) => state = state.copyWith(step: ScanStep.done),
      err: (f) => state = state.copyWith(step: ScanStep.failed, error: f.message),
    );
    return result;
  }

  void reset() => state = const ScanFlowState();
}

final scanFlowProvider =
    NotifierProvider<ScanFlowController, ScanFlowState>(ScanFlowController.new);
