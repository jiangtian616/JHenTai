import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/exception/upload_exception.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_archive.dart';
import 'package:jhentai/src/widget/eh_asset.dart';
import 'package:jhentai/src/widget/eh_group_name_selector.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../exception/eh_exception.dart';
import '../network/eh_request.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';
import '../utils/route_util.dart';
import '../utils/snack_util.dart';

class EHArchiveDialog extends StatefulWidget {
  final String? currentGroup;
  final List<String> candidates;
  final String archivePageUrl;

  const EHArchiveDialog({
    Key? key,
    this.currentGroup,
    required this.candidates,
    required this.archivePageUrl,
  }) : super(key: key);

  @override
  _EHArchiveDialogState createState() => _EHArchiveDialogState();
}

class _EHArchiveDialogState extends State<EHArchiveDialog> {
  late String group;
  late GalleryArchive archive;
  LoadingState loadingState = LoadingState.idle;

  @override
  void initState() {
    super.initState();
    group = widget.currentGroup ?? 'default'.tr;
    widget.candidates.remove(group);
    widget.candidates.insert(0, group);
    _getArchiveInfo();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('chooseArchive'.tr),
      content: SizedBox(
        height: UIConfig.archiveDialogBodyHeight,
        child: LoadingStateIndicator(
          loadingState: loadingState,
          errorTapCallback: _getArchiveInfo,
          successWidgetBuilder: () => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EHGroupNameSelector(candidates: widget.candidates, currentGroup: 'default'.tr, listener: (g) => group = g),
        if (archive.creditCount != null && archive.gpCount != null)
          EHAsset(gpCount: archive.gpCount!, creditCount: archive.creditCount!).marginOnly(top: 20),
        Expanded(child: _buildButtons().marginOnly(top: 12)),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ArchiveButtonSet(
          cost: archive.resampleCost,
          size: archive.resampleSize,
          text: 'resample'.tr,
          callback: _canAffordDownload(isOriginal: false)
              ? () => backRoute(
                    result: {'isOriginal': false, 'size': _computeSizeInBytes(isOriginal: false), 'group': group},
                  )
              : null,
        ),
        _ArchiveButtonSet(
          cost: archive.originalCost,
          size: archive.originalSize,
          text: 'original'.tr,
          callback: _canAffordDownload(isOriginal: true)
              ? () => backRoute(
                    result: {'isOriginal': true, 'size': _computeSizeInBytes(isOriginal: true), 'group': group},
                  )
              : null,
        ),
      ],
    );
  }

  Future<void> _getArchiveInfo() async {
    setState(() => loadingState = LoadingState.loading);

    try {
      archive = await EHRequest.request(
        url: widget.archivePageUrl,
        parser: EHSpiderParser.archivePage2Archive,
        useCacheIfAvailable: false,
      );
    } on DioError catch (e) {
      Log.error('getGalleryArchiveFailed'.tr, e.message);
      snack('getGalleryArchiveFailed'.tr, e.message);
      setStateSafely(() => loadingState = LoadingState.error);
      return;
    } on EHException catch (e) {
      Log.error('getGalleryArchiveFailed'.tr, e.message);
      snack('getGalleryArchiveFailed'.tr, e.message);
      setStateSafely(() => loadingState = LoadingState.error);
      return;
    } on NotUploadException catch (_) {
      snack('getGalleryArchiveFailed'.tr, 'parseGalleryArchiveFailed'.tr);
      if (mounted) {
        setState(() => loadingState = LoadingState.error);
      }
      return;
    }

    if (mounted) {
      setState(() => loadingState = LoadingState.success);
    }
  }

  bool _canAffordDownload({required bool isOriginal}) {
    if (isOriginal) {
      if (archive.originalCost.contains('Free')) {
        return true;
      }

      /// ex site
      if (archive.downloadOriginalHint.contains('Insufficient Funds')) {
        return false;
      }
      if (archive.originalCost.contains('GP')) {
        return (archive.gpCount ?? double.maxFinite) >= int.parse(archive.originalCost.split(' ')[0]);
      }
      return (archive.creditCount ?? double.maxFinite) >= int.parse(archive.originalCost.split(' ')[0]);
    } else {
      if (archive.resampleCost == null || archive.resampleCost == 'N/A') {
        return false;
      }

      /// ex site
      if (archive.downloadResampleHint.contains('Insufficient Funds')) {
        return false;
      }
      if (archive.resampleCost!.contains('Free')) {
        return true;
      }
      if (archive.resampleCost!.contains('GP')) {
        return (archive.gpCount ?? double.maxFinite) >= int.parse(archive.resampleCost!.split(' ')[0]);
      }
      return (archive.creditCount ?? double.maxFinite) >= int.parse(archive.resampleCost!.split(' ')[0]);
    }
  }

  int _computeSizeInBytes({required bool isOriginal}) {
    String sizeString = isOriginal ? archive.originalSize : archive.resampleSize!;

    List<String> parts = sizeString.split(' ');
    double number = double.parse(parts[0]);
    String unit = parts[1];

    if (unit.startsWith('K')) {
      return (number * 1024).toInt();
    }
    if (unit.startsWith('M')) {
      return (number * 1024 * 1024).toInt();
    }
    return (number * 1024 * 1024 * 1024).toInt();
  }
}

class _ArchiveButtonSet extends StatelessWidget {
  final String? cost;
  final String? size;
  final String text;
  final VoidCallback? callback;

  const _ArchiveButtonSet({
    Key? key,
    this.cost,
    this.size,
    required this.text,
    this.callback,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cost != null)
          Text(
            cost!,
            style: TextStyle(color: UIConfig.archiveDialogCostTextColor(context), fontSize: UIConfig.archiveDialogCostTextSize),
          ),
        ElevatedButton(
          onPressed: callback,
          child: Row(
            children: [
              Text(text, style: const TextStyle(fontSize: UIConfig.archiveDialogDownloadTextSize)),
              const Icon(Icons.download_for_offline, size: UIConfig.archiveDialogDownloadIconSize),
            ],
          ),
        ),
        if (size != null)
          Text(
            size!,
            style: TextStyle(color: UIConfig.archiveDialogCostTextColor(context), fontSize: UIConfig.archiveDialogCostTextSize),
          ),
      ],
    );
  }
}
