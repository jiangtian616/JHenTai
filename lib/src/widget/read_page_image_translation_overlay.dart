import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/model/image_translation.dart';
import 'package:jhentai/src/service/image_translation_service.dart';
import 'package:jhentai/src/setting/image_translation_setting.dart';
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
                    child:
                        ThemeConfig.isApple
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
                    constraints: BoxConstraints(
                      // Keep the message readable on phones while allowing a
                      // wider, less tall chip on desktop.
                      maxWidth: math.min(
                        MediaQuery.sizeOf(context).width - 48,
                        520,
                      ),
                    ),
                    child: Text(
                      _errorMessage(result),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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
        // Keep background style independent of GetX.  It must repaint an
        // already translated page immediately when the user changes color or
        // opacity, even if another reader observer is rebuilding.
        StreamBuilder<Color>(
          stream: imageTranslationSetting.translationBackgroundColor.stream,
          initialData: imageTranslationSetting.translationBackgroundColor.value,
          builder:
              (context, colorSnapshot) => StreamBuilder<double>(
                stream:
                    imageTranslationSetting.translationBackgroundOpacity.stream,
                initialData:
                    imageTranslationSetting.translationBackgroundOpacity.value,
                builder:
                    (context, opacitySnapshot) => IgnorePointer(
                      child: LayoutBuilder(
                        builder:
                            (context, constraints) => CustomPaint(
                              size: constraints.biggest,
                              painter: _ImageTranslationOverlayPainter(
                                result: result,
                                textDirection: Directionality.of(context),
                                backgroundColor:
                                    colorSnapshot.data ?? Colors.white,
                                backgroundOpacity: opacitySnapshot.data ?? 0.9,
                              ),
                            ),
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
      // Context (multi-page) translation failures. These are grouped to the
      // closest single-page message so the user sees the real cause instead of
      // the generic "translation failed" label.
      case 'CONTEXT_ENGINE_UNAVAILABLE':
      case 'CONTEXT_ENGINE_NOT_READY':
      case 'CONTEXT_ENGINE_NOT_CONFIGURED':
      case 'CONTEXT_ENGINE_RUNTIME_UNAVAILABLE':
        return 'imageTranslationConfigureHint'.tr;
      case 'CONTEXT_ENGINE_INVALID_RESPONSE':
      case 'CONTEXT_INVALID_RESPONSE':
      case 'CONTEXT_MISSING_LINE':
      case 'CONTEXT_EMPTY_LINE':
        return 'imageTranslationInvalidResponse'.tr;
      case 'CONTEXT_ENGINE_REQUEST_FAILED':
      case 'CONTEXT_ENGINE_TIMEOUT':
      case 'CONTEXT_ENGINE_SERVER_TIMEOUT':
        return 'imageTranslationRequestFailed'.tr;
      case 'CONTEXT_ENGINE_UNSUPPORTED_PLATFORM':
        return 'imageTranslationUnsupportedPlatform'.tr;
      // Local-engine runtime failures (llama-server / llama-ffi) and model
      // resolution errors are left to the default branch, which surfaces the
      // CONTEXT_* code verbatim so the exact failure is identifiable.
      default:
        // Unknown CONTEXT_* codes are surfaced verbatim so a debugging round
        // can identify the real failure without digging through logs.
        if (result.errorMessage?.startsWith('CONTEXT_') ?? false) {
          return result.errorMessage!;
        }
        return 'imageTranslationFailed'.tr;
    }
  }
}

/// The exact visible source-image rect used by [EHImage] in the reader.
///
/// Keeping this transform explicit makes the reader overlay match exported
/// images even while a page is still using a placeholder-sized container.
Rect translationOverlayVisibleImageRect({
  required Size sourceSize,
  required Size canvasSize,
}) {
  if (sourceSize.width <= 0 ||
      sourceSize.height <= 0 ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    return Rect.zero;
  }
  final FittedSizes fitted = applyBoxFit(
    BoxFit.contain,
    sourceSize,
    canvasSize,
  );
  return Alignment.center.inscribe(
    fitted.destination,
    Offset.zero & canvasSize,
  );
}

class _ImageTranslationOverlayPainter extends CustomPainter {
  final ImageTranslationResult result;
  final TextDirection textDirection;
  final Color backgroundColor;
  final double backgroundOpacity;

  const _ImageTranslationOverlayPainter({
    required this.result,
    required this.textDirection,
    required this.backgroundColor,
    required this.backgroundOpacity,
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

    // EHImage displays a page through BoxFit.contain and then centers the
    // fitted image in its page container. The standalone export path paints
    // at source resolution, but this live reader painter must make the same
    // source-pixel -> visible-image transform. Scaling independently to the
    // whole Stack used to stretch coordinates into letterbox space; on reader
    // containers whose placeholder aspect differed from the decoded page it
    // could turn ordinary OCR boxes into an apparent page-wide backing plate.
    final Rect visibleImage = translationOverlayVisibleImageRect(
      sourceSize: Size(imageWidth.toDouble(), imageHeight.toDouble()),
      canvasSize: size,
    );
    if (visibleImage.isEmpty) {
      return;
    }
    final double scaleX = visibleImage.width / imageWidth;
    final double scaleY = visibleImage.height / imageHeight;
    final List<String> translations =
        result.translatedText.split('\n').map((line) => line.trim()).toList();

    // Render each speech bubble as one text layout. Keeping each OCR line in a
    // separate narrow box makes a natural translation fragment into tiny,
    // disconnected labels; the merged rect gives the whole utterance one
    // readable size and natural wrapping.
    final List<(Rect, String, double)> entries = <(Rect, String, double)>[];
    final List<Rect> mergedBackgrounds = <Rect>[];
    final List<RecognizedTextGroup> groups = translationTextGroups(
      result.blocks,
      merge: result.mergeTextBlocks,
      containers: result.containers,
    );
    for (int groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final RecognizedTextGroup group = groups[groupIndex];
      Rect? merged;
      final List<String> groupLines = <String>[];
      for (final int index in group.blockIndices) {
        final String translation =
            index < translations.length ? translations[index] : '';
        if (translation.trim().isEmpty) {
          continue;
        }
        groupLines.add(translation);
        // The group rectangle is the unit of layout. For a stable multi-line
        // container this is expanded beyond the OCR glyph boxes; otherwise it
        // remains the conservative OCR-group union.
        if (merged == null) {
          final RecognizedTextGroupRenderBounds? detected =
              explicitRenderBoundsForRecognizedTextGroup(
                group,
                result.containers,
              );
          final RecognizedTextGroupRenderBounds bounds =
              detected ??
              renderBoundsForRecognizedTextGroup(group, result.blocks);
          merged = Rect.fromLTRB(
            visibleImage.left + bounds.left * scaleX - 4,
            visibleImage.top + bounds.top * scaleY - 3,
            visibleImage.left + bounds.right * scaleX + 4,
            visibleImage.top + bounds.bottom * scaleY + 3,
          );
        }
      }
      if (merged != null) {
        final Rect? safeRect = safeTranslationBackgroundRect(merged, size);
        if (safeRect == null) {
          continue;
        }
        mergedBackgrounds.add(safeRect);
        final String translation =
            groupIndex < result.translatedGroups.length &&
                    result.translatedGroups[groupIndex].trim().isNotEmpty
                ? result.translatedGroups[groupIndex].trim()
                : groupLines.join('\n');
        final double resolved = fitTranslationFontSize(
          translation,
          math.max(1, safeRect.width - 8),
          math.max(1, safeRect.height - 4),
          textDirection,
        );
        entries.add((safeRect, translation, resolved));
      }
    }
    for (final Rect rect in mergedBackgrounds) {
      paintTranslationBubbleBackground(
        canvas,
        rect,
        color: backgroundColor,
        opacity: backgroundOpacity,
      );
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
      oldDelegate.textDirection != textDirection ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.backgroundOpacity != backgroundOpacity;
}
