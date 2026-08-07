import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../model/image_translation.dart';
import '../routes/routes.dart';
import '../service/image_translation_service.dart';
import '../utils/route_util.dart';
import '../utils/toast_util.dart';

class ImageTranslationBottomSheet extends StatefulWidget {
  final ImageTranslationRequest request;

  const ImageTranslationBottomSheet({super.key, required this.request});

  @override
  State<ImageTranslationBottomSheet> createState() =>
      _ImageTranslationBottomSheetState();
}

class _ImageTranslationBottomSheetState
    extends State<ImageTranslationBottomSheet> {
  bool _showSource = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => imageTranslationService.translate(widget.request));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.52,
        minChildSize: 0.30,
        maxChildSize: 0.92,
        builder: (context, controller) => GetBuilder<ImageTranslationService>(
          id: imageTranslationService.taskId(widget.request.cacheKey),
          builder: (_) {
            final ImageTranslationResult result =
                imageTranslationService.resultFor(widget.request.cacheKey);
            return Column(
              children: [
                Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('imageTextTranslation'.tr,
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close)),
                    ],
                  ),
                ),
                Expanded(child: _buildContent(context, controller, result)),
                _buildActions(context, result),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ScrollController controller,
      ImageTranslationResult result) {
    if (result.status == ImageTranslationStatus.idle ||
        result.status == ImageTranslationStatus.recognizing) {
      return _buildLoading('recognizingImageText'.tr);
    }
    if (result.status == ImageTranslationStatus.translating) {
      return _buildLoading('translatingImageText'.tr);
    }

    final String text =
        _showSource || result.status == ImageTranslationStatus.failed
            ? result.sourceText
            : result.translatedText;
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      children: [
        if (result.status == ImageTranslationStatus.failed) ...[
          Text(_errorMessage(result),
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          const SizedBox(height: 12),
        ],
        if (text.isNotEmpty)
          SelectableText(text,
              style:
                  Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55))
        else if (result.status == ImageTranslationStatus.failed)
          Text('imageTranslationNoResult'.tr)
        else
          Text('noData'.tr),
      ],
    );
  }

  Widget _buildLoading(String label) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(label)
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, ImageTranslationResult result) {
    final bool hasSource = result.sourceText.isNotEmpty;
    final bool hasTranslation = result.translatedText.isNotEmpty;
    final bool isBusy = result.status == ImageTranslationStatus.recognizing ||
        result.status == ImageTranslationStatus.translating;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        children: [
          if (hasSource && hasTranslation)
            TextButton(
              onPressed: () => setState(() => _showSource = !_showSource),
              child:
                  Text(_showSource ? 'showTranslation'.tr : 'showOriginal'.tr),
            ),
          if (hasSource || hasTranslation)
            TextButton(
              onPressed: () {
                FlutterClipboard.copy(_showSource || !hasTranslation
                    ? result.sourceText
                    : result.translatedText);
                toast('hasCopiedToClipboard'.tr);
              },
              child: Text('copy'.tr),
            ),
          if (hasTranslation)
            TextButton(
              onPressed: _exporting ? null : _exportOverlay,
              child: Text(_exporting
                  ? 'imageTranslationExporting'.tr
                  : 'imageTranslationExportOverlay'.tr),
            ),
          if (result.needsConfiguration)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                toRoute(Routes.imageTranslation);
              },
              child: Text('configure'.tr),
            ),
          TextButton(
            onPressed: isBusy
                ? null
                : () => imageTranslationService.translate(widget.request,
                    force: true),
            child: Text('retry'.tr),
          ),
        ],
      ),
    );
  }

  Future<void> _exportOverlay() async {
    setState(() => _exporting = true);
    try {
      final file = await imageTranslationService.exportOverlay(widget.request);
      if (mounted) {
        toast('imageTranslationOverlaySaved'.trParams({'path': file.path}));
      }
    } on ImageTranslationException catch (error) {
      if (mounted) {
        toast(error.code == 'OVERLAY_NOT_READY'
            ? 'imageTranslationOverlayUnavailable'.tr
            : 'imageTranslationOverlayFailed'.tr);
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
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
      default:
        return 'imageTranslationFailed'.tr;
    }
  }
}
