import 'package:flutter/foundation.dart';

import '../../../core/utils/result.dart';

/// Structured output of AI extraction from a business card image.
/// Every field is optional — the review screen fills gaps.
@immutable
class ExtractedCard {
  const ExtractedCard({
    this.fullName,
    this.designation,
    this.companyName,
    this.email,
    this.phone,
    this.altPhone,
    this.website,
    this.address,
    this.city,
    this.country,
    this.confidence = 0,
  });

  final String? fullName;
  final String? designation;
  final String? companyName;
  final String? email;
  final String? phone;
  final String? altPhone;
  final String? website;
  final String? address;
  final String? city;
  final String? country;

  /// 0–1 aggregate extraction confidence, surfaced on the review screen.
  final double confidence;
}

/// Contract for the OCR/AI extraction step of the scan pipeline.
///
/// Scan → **extract(imagePath)** → Review → Questionnaire → Save
///
/// Implementations to come: on-device ML Kit for offline exhibition halls,
/// LLM vision for higher accuracy when online. The pipeline and all UI
/// depend only on this interface.
abstract interface class CardExtractionService {
  Future<Result<ExtractedCard>> extract(String imagePath);
}

/// Placeholder until the OCR milestone: returns a plausible card after a
/// short delay so the full flow is demoable today.
class StubCardExtractionService implements CardExtractionService {
  @override
  Future<Result<ExtractedCard>> extract(String imagePath) async {
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    return const Ok(ExtractedCard(
      fullName: 'Arjun Mehta',
      designation: 'Head of Sourcing',
      companyName: 'Northbridge Industrial',
      email: 'arjun.mehta@northbridge.in',
      phone: '+91 98110 23456',
      website: 'northbridge.in',
      city: 'Noida',
      country: 'India',
      confidence: 0.94,
    ));
  }
}
