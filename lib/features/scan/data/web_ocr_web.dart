// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:js_interop';

@JS('leadflowExtractText')
external JSPromise<JSString?> _leadflowExtractText(JSString imageUrl);

/// Calls the JS bridge (tesseract.js) and returns whatever raw text it read.
Future<String> extractTextFromUrl(String url) async {
  try {
    final promise = _leadflowExtractText(url.toJS);
    final result = await promise.toDart;
    return result?.toDart ?? '';
  } catch (_) {
    return '';
  }
}
