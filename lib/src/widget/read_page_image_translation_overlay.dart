import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/utils/image_text_grouping.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Inline overlay for the read page. After "recognize and translate this page"
/// is triggered, the bottom result sheet is no longer shown; instead this
/// widget paints the translated text directly on the image and shows a small
/// progress / error chip while the task is running.
class ReadPageImageTranslationOverlay extends StatelessWidget {
  final ImageTranslationRequest request;
  final Future<void> Function()? onRetry;

  const ReadPageImageTranslationOverlay({
    super.key,
    required this.request,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return GetBuilder<ImageTranslationService>(
      id: imageTranslationService.taskId(request.cacheKey),
      builder: (_) {
        final ImageTranslationResult result = imageTranslationService.resultFor(
          request.cacheKey,
        );
        switch (result.status) {
          case ImageTranslationStatus.idle:
            return const SizedBox.shrink();
          case ImageTranslationStatus.queued:
          case ImageTranslationStatus.downloading:
          case ImageTranslationStatus.recognizing:
          case ImageTranslationStatus.translating:
            return _buildStatusChip(context, result);
          case ImageTranslationStatus.downloadError:
          case ImageTranslationStatus.ocrError:
          case ImageTranslationStatus.noText:
          case ImageTranslationStatus.canceled:
          case ImageTranslationStatus.failed:
            return _buildFailureChip(context, result);
          case ImageTranslationStatus.success:
            return _buildOverlay(context, result);
        }
      },
    );
  }

  Widget _buildStatusChip(BuildContext context, ImageTranslationResult result) {
    final String label;
    switch (result.status) {
      case ImageTranslationStatus.queued:
        label = 'loading'.tr;
      case ImageTranslationStatus.downloading:
        label = 'downloading'.tr;
      case ImageTranslationStatus.recognizing:
        label = 'recognizingImageText'.tr;
      case ImageTranslationStatus.translating:
        label = 'translatingImageText'.tr;
      default:
        label = 'loading'.tr;
    }
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
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: ThemeConfig.isApple
                        ? GlassProgressIndicator.circular(
                            strokeWidth: 2,
                            color: Colors.white,
                          )
                        : const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
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
    BuildContext context,
    ImageTranslationResult result,
  ) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Material(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 4,
                top: 2,
                bottom: 2,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.orangeAccent,
                    size: 16,
                  ),
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
                  EHAppleIconButton(
                    onPressed: () {
                      unawaited(
                        onRetry?.call() ??
                            imageTranslationService.translate(
                              request,
                              force: true,
                            ),
                      );
                    },
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 18,
                    ),
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
                result: result,
                textDirection: Directionality.of(context),
              ),
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
                onTap: () {
                  unawaited(
                    onRetry?.call() ??
                        imageTranslationService.translate(request, force: true),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.refresh, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(
                        'imageTranslationCachedRetranslate'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
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
      case 'IMAGE_DOWNLOAD_TIMEOUT':
        return 'imageTranslationSourceUnavailable'.tr;
      case 'IMAGE_SOURCE_UNAVAILABLE':
        return 'imageTranslationSourceUnavailable'.tr;
      case 'TRANSLATOR_NOT_CONFIGURED':
        return 'imageTranslationConfigureHint'.tr;
      case 'OCR_UNSUPPORTED_PLATFORM':
        return 'imageTranslationUnsupportedPlatform'.tr;
      case 'OCR_NOT_CONFIGURED':
        return 'imageTranslationOcrNotConfigured'.tr;
      case 'OCR_UNAVAILABLE':
        return 'imageTranslationOcrUnavailable'.tr;
      case 'OCR_FAILED':
        return 'imageTranslationOcrFailed'.tr;
      case 'OCR_CANCELLED':
        return 'imageTranslationCancelled'.tr;
      case 'OCR_TIMEOUT':
      case 'OCR_WORKER_TIMEOUT':
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
        return (GetPlatform.isIOS
                ? 'imageTranslationTranslationNotInstalledIos'
                : 'imageTranslationTranslationNotInstalled')
            .tr;
      case 'TRANSLATION_FAILED':
        return 'imageTranslationTranslationFailed'.tr;
      case 'TRANSLATION_TIMEOUT':
        return 'imageTranslationTranslationFailed'.tr;
      case 'TRANSLATION_TASK_FAILED':
        return 'imageTranslationFailed'.tr;
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
    final List<String> translations = result.translatedText
        .split('\n')
        .map((line) => line.trim())
        .toList();

    // Adjacent lines of the same speech bubble (a group) share ONE background
    // pill AND one font size, so a merged bubble reads as a coherent block
    // instead of a set of independently-sized lines. All pills are drawn first
    // (see paintTranslationBubbleBackground) so a later bubble never covers an
    // earlier line's wrapped text overflow; text stays per-line inside.
    final List<(Rect, String, double)> entries = <(Rect, String, double)>[];
    final List<Rect> mergedBackgrounds = <Rect>[];
    for (final RecognizedTextGroup group in groupRecognizedTextBlocks(
      result.blocks,
    )) {
      Rect? merged;
      final List<(Rect, String)> groupEntries = <(Rect, String)>[];
      double groupFont = double.infinity;
      for (final int index in group.blockIndices) {
        final String translation = index < translations.length
            ? translations[index]
            : '';
        if (translation.trim().isEmpty) {
          continue;
        }
        final RecognizedTextBlock block = result.blocks[index];
        final Rect rect = Rect.fromLTWH(
          block.left * scaleX - 4,
          block.top * scaleY - 3,
          block.width * scaleX + 8,
          block.height * scaleY + 6,
        );
        groupEntries.add((rect, translation));
        merged = merged == null ? rect : merged.expandToInclude(rect);
        // The shared size is the tightest of the member lines' fits, so no
        // line overflows its own box and none is larger than its neighbors.
        groupFont = math.min(
          groupFont,
          fitTranslationFontSize(
            translation,
            math.max(1, rect.width - 4),
            rect.height,
            textDirection,
          ),
        );
      }
      if (merged != null) {
        mergedBackgrounds.add(merged);
        final double resolved = groupFont.isFinite ? groupFont : 8;
        for (final (Rect rect, String translation) in groupEntries) {
          entries.add((rect, translation, resolved));
        }
      }
    }
    for (final Rect rect in mergedBackgrounds) {
      paintTranslationBubbleBackground(canvas, rect);
    }
    for (final (Rect rect, String translation, double fontSize) in entries) {
      paintTranslationBubbleText(
        canvas,
        rect,
        translation,
        textDirection,
        fontSize: fontSize,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImageTranslationOverlayPainter oldDelegate) =>
      oldDelegate.result != result ||
      oldDelegate.textDirection != textDirection;
}
