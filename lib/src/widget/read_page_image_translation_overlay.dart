import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/service/image_translation_service.dart';

/// Inline overlay for the read page. After "recognize and translate this page"
/// is triggered, the bottom result sheet is no longer shown; instead this
/// widget paints the translated text directly on the image and shows a small
/// progress / error chip while the task is running.
class ReadPageImageTranslationOverlay extends StatelessWidget {
  final ImageTranslationRequest request;

  const ReadPageImageTranslationOverlay({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ImageTranslationService>(
      id: imageTranslationService.taskId(request.cacheKey),
      builder: (_) {
        final ImageTranslationResult result =
            imageTranslationService.resultFor(request.cacheKey);
        switch (result.status) {
          case ImageTranslationStatus.idle:
            return const SizedBox.shrink();
          case ImageTranslationStatus.recognizing:
          case ImageTranslationStatus.translating:
            return _buildStatusChip(context, result);
          case ImageTranslationStatus.failed:
            return _buildFailureChip(context, result);
          case ImageTranslationStatus.success:
            return _buildOverlay(context, result);
        }
      },
    );
  }

  Widget _buildStatusChip(BuildContext context, ImageTranslationResult result) {
    final String label = result.status == ImageTranslationStatus.recognizing
        ? 'recognizingImageText'.tr
        : 'translatingImageText'.tr;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white)),
                  const SizedBox(width: 8),
                  Text(label,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: imageTranslationService.cancelBatch,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFailureChip(
      BuildContext context, ImageTranslationResult result) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding:
                  const EdgeInsets.only(left: 12, right: 4, top: 2, bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.orangeAccent, size: 16),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      _errorMessage(result),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () =>
                        imageTranslationService.translate(request, force: true),
                    icon: const Icon(Icons.refresh,
                        color: Colors.white, size: 18),
                    tooltip: 'retry'.tr,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context, ImageTranslationResult result) {
    if (result.blocks.isEmpty ||
        result.imageWidth == null ||
        result.imageHeight == null) {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        IgnorePointer(
          child: LayoutBuilder(
            builder: (context, constraints) => CustomPaint(
              size: constraints.biggest,
              painter: _ImageTranslationOverlayPainter(
                  result: result, textDirection: Directionality.of(context)),
            ),
          ),
        ),
        if (result.fromCache)
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () =>
                    imageTranslationService.translate(request, force: true),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text('imageTranslationCachedRetranslate'.tr,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _errorMessage(ImageTranslationResult result) {
    switch (result.errorMessage) {
      case 'TRANSLATOR_NOT_CONFIGURED':
        return 'imageTranslationConfigureHint'.tr;
      case 'OCR_UNSUPPORTED_PLATFORM':
        return 'imageTranslationUnsupportedPlatform'.tr;
      case 'OCR_UNAVAILABLE':
        return 'imageTranslationOcrUnavailable'.tr;
      case 'OCR_FAILED':
        return 'imageTranslationOcrFailed'.tr;
      case 'NO_TEXT':
        return 'imageTranslationNoText'.tr;
      case 'TRANSLATION_REQUEST_FAILED':
        return 'imageTranslationRequestFailed'.tr;
      case 'TRANSLATION_INVALID_RESPONSE':
        return 'imageTranslationInvalidResponse'.tr;
      case 'TRANSLATION_UNAVAILABLE':
        return 'imageTranslationTranslationUnavailable'.tr;
      case 'TRANSLATION_NOT_INSTALLED':
        return 'imageTranslationTranslationNotInstalled'.tr;
      case 'TRANSLATION_FAILED':
        return 'imageTranslationTranslationFailed'.tr;
      case 'PADDLE_RUNTIME_NOT_READY':
        return 'imageTranslationPaddleNotReady'.tr;
      default:
        return 'imageTranslationFailed'.tr;
    }
  }
}

class _ImageTranslationOverlayPainter extends CustomPainter {
  final ImageTranslationResult result;
  final TextDirection textDirection;

  const _ImageTranslationOverlayPainter({
    required this.result,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int? imageWidth = result.imageWidth;
    final int? imageHeight = result.imageHeight;
    if (imageWidth == null ||
        imageHeight == null ||
        imageWidth <= 0 ||
        imageHeight <= 0) {
      return;
    }

    final double scaleX = size.width / imageWidth;
    final double scaleY = size.height / imageHeight;
    final List<String> translations =
        result.translatedText.split('\n').map((line) => line.trim()).toList();

    for (int index = 0; index < result.blocks.length; index++) {
      final RecognizedTextBlock block = result.blocks[index];
      final String translation =
          index < translations.length ? translations[index] : '';
      if (translation.isEmpty) {
        continue;
      }

      final Rect rect = Rect.fromLTWH(
        block.left * scaleX - 4,
        block.top * scaleY - 3,
        block.width * scaleX + 8,
        block.height * scaleY + 6,
      );
      final RRect rrect =
          RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xE6FFFFFF));
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.stroke,
      );

      final double fontSize = (rect.width / (translation.length * 0.82))
          .clamp(8, (rect.height * 0.6).clamp(10, 30))
          .toDouble();
      final TextPainter painter = TextPainter(
        text: TextSpan(
            text: translation,
            style: TextStyle(
                color: Colors.black, fontSize: fontSize, height: 1.05)),
        textAlign: TextAlign.center,
        textDirection: textDirection,
        maxLines: 3,
        ellipsis: '…',
      )..layout(maxWidth: rect.width - 4);
      painter.paint(
          canvas, Offset(rect.left + 2, rect.center.dy - painter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ImageTranslationOverlayPainter oldDelegate) =>
      oldDelegate.result != result ||
      oldDelegate.textDirection != textDirection;
}
