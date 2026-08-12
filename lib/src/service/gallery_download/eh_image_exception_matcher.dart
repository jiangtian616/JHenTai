import 'package:get/get_utils/get_utils.dart';

import '../../exception/eh_image_exception.dart';

/// Matches downloaded image bytes against known E-Hentai error-page signatures.
/// Order matters: more specific patterns must come before generic ones.
class EHImageExceptionMatcher {
  static final List<({String pattern, EHImageExceptionType type, String Function() message, EHImageExceptionAfterOperation operation})> _matchers = [
    (
      pattern: 'Downloading original files of this gallery during peak hours requires GP, and you do not have enough.',
      type: EHImageExceptionType.peakHours,
      message: () => 'peakHoursHint'.tr,
      operation: EHImageExceptionAfterOperation.pause
    ),
    (
      pattern: 'Downloading original files of this gallery requires GP, and you do not have enough.',
      type: EHImageExceptionType.peakHours,
      message: () => 'oldGalleryHint'.tr,
      operation: EHImageExceptionAfterOperation.pause
    ),
    (
      pattern: 'You have reached the image limit, and do not have sufficient GP to buy a download quota.',
      type: EHImageExceptionType.peakHours,
      message: () => 'exceedLimitHint'.tr,
      operation: EHImageExceptionAfterOperation.pauseAll
    ),
    (pattern: 'Invalid token', type: EHImageExceptionType.invalidToken, message: () => '', operation: EHImageExceptionAfterOperation.reParse),
    (pattern: 'Invalid request', type: EHImageExceptionType.serverError, message: () => '', operation: EHImageExceptionAfterOperation.reParse),
    (pattern: 'An error has occurred', type: EHImageExceptionType.serverError, message: () => '', operation: EHImageExceptionAfterOperation.reParse),
  ];

  /// Parse downloaded image bytes into an [EHImageException] if it's actually
  /// an error page. Returns null-ish fallback (serverError + pause) when no
  /// pattern matches; blank input returns a blank-image exception.
  static EHImageException? match(String imageFileData) {
    if (imageFileData.isEmpty) {
      return EHImageException(
        type: EHImageExceptionType.blankImage,
        message: 'blankImageHint'.tr,
        operation: EHImageExceptionAfterOperation.reParse,
      );
    }

    for (final m in _matchers) {
      if (imageFileData.contains(m.pattern)) {
        return EHImageException(type: m.type, message: m.message(), operation: m.operation);
      }
    }

    return EHImageException(
      type: EHImageExceptionType.serverError,
      message: imageFileData,
      operation: EHImageExceptionAfterOperation.pause,
    );
  }
}
