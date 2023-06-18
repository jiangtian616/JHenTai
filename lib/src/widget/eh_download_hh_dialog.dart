import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/utils/route_util.dart';

import '../config/ui_config.dart';
import '../exception/eh_exception.dart';
import '../exception/upload_exception.dart';
import '../model/gallery_hh_archive.dart';
import '../model/gallery_hh_info.dart';
import '../network/eh_request.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';
import '../utils/snack_util.dart';
import 'eh_asset.dart';
import 'loading_state_indicator.dart';

class EHDownloadHHDialog extends StatefulWidget {
  final String archivePageUrl;

  const EHDownloadHHDialog({Key? key, required this.archivePageUrl}) : super(key: key);

  @override
  State<EHDownloadHHDialog> createState() => _EHDownloadHHDialogState();
}

class _EHDownloadHHDialogState extends State<EHDownloadHHDialog> {
  late GalleryHHInfo hhInfo;
  LoadingState loadingState = LoadingState.idle;

  @override
  void initState() {
    super.initState();
    _getHHInfo();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('H@H ${'download'.tr}'),
      content: SizedBox(
        height: UIConfig.hhDialogBodyHeight,
        child: LoadingStateIndicator(
          loadingState: loadingState,
          errorTapCallback: _getHHInfo,
          successWidgetBuilder: () => _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (hhInfo.creditCount != null && hhInfo.gpCount != null) EHAsset(gpCount: hhInfo.creditCount!, creditCount: hhInfo.gpCount!),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_HHDownloadButtonSet(archive: hhInfo.archives[0]), _HHDownloadButtonSet(archive: hhInfo.archives[1])],
        ).marginOnly(top: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_HHDownloadButtonSet(archive: hhInfo.archives[2]), _HHDownloadButtonSet(archive: hhInfo.archives[3])],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [_HHDownloadButtonSet(archive: hhInfo.archives[4]), _HHDownloadButtonSet(archive: hhInfo.archives[5])],
        ),
      ],
    );
  }

  Future<void> _getHHInfo() async {
    setState(() => loadingState = LoadingState.loading);

    try {
      hhInfo = await EHRequest.request(
        url: widget.archivePageUrl,
        parser: EHSpiderParser.archivePage2HHInfo,
        useCacheIfAvailable: false,
      );
    } on DioError catch (e) {
      Log.error('Get H@H download info failed', e.message);
      snack('failed'.tr, e.message);
      setStateSafely(() => loadingState = LoadingState.error);
      return;
    } on EHException catch (e) {
      Log.error('Get H@H download info failed', e.message);
      snack('failed'.tr, e.message);
      setStateSafely(() => loadingState = LoadingState.error);
      return;
    } on NotUploadException catch (_) {
      snack('Get H@H download info failed', 'parseGalleryArchiveFailed'.tr);
      if (mounted) {
        setState(() => loadingState = LoadingState.error);
      }
      return;
    }

    if (mounted) {
      setState(() => loadingState = LoadingState.success);
    }
  }
}

class _HHDownloadButtonSet extends StatelessWidget {
  final GalleryHHArchive archive;

  const _HHDownloadButtonSet({Key? key, required this.archive}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: archive.resolution == null ? null : () => backRoute(result: archive.resolution),
          child: SizedBox(
            width: UIConfig.hhDialogTextButtonWidth,
            child: Center(
              child: Text(archive.resolutionDesc, style: const TextStyle(fontSize: UIConfig.archiveDialogDownloadTextSize)),
            ),
          ),
        ),
        Row(
          children: [
            Text(
              archive.size.removeAllWhitespace,
              style: TextStyle(color: UIConfig.hhDialogCostTextColor(context), fontSize: UIConfig.hhDialogTextSize),
            ).marginOnly(right: 6),
            Text(
              archive.cost.removeAllWhitespace,
              style: TextStyle(color: UIConfig.hhDialogCostTextColor(context), fontSize: UIConfig.hhDialogTextSize),
            ),
          ],
        )
      ],
    );
  }
}
