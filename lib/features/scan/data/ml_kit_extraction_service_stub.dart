import '../../../core/utils/result.dart';
import '../domain/card_extraction_service.dart';

/// Web/desktop stub: ML Kit ships mobile-only native code, so on other
/// platforms we transparently defer to the fallback tier.
class MlKitExtractionService implements CardExtractionService {
  const MlKitExtractionService(this.fallback);

  final CardExtractionService fallback;

  @override
  Future<Result<ExtractedCard>> extract(String imagePath) =>
      fallback.extract(imagePath);
}
