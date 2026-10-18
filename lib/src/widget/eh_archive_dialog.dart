import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/gallery_archive.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/archive_bot_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/eh_asset.dart';
import 'package:jhentai/src/widget/eh_group_name_selector.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../exception/eh_site_exception.dart';
import '../model/archive_bot_response/archive_bot_response.dart';
import '../network/archive_bot_request.dart';
import '../network/eh_request.dart';
import '../utils/eh_spider_parser.dart';
import '../service/log.dart';
import '../utils/snack_util.dart';

class EHArchiveDialog extends StatefulWidget {
  final String title;
  final int gid;
  final String token;
  final String? currentGroup;
  final List<String> candidates;
  final String archivePageUrl;

  const EHArchiveDialog({
    Key? key,
    required this.title,
    required this.gid,
    required this.token,
    this.currentGroup,
    required this.candidates,
    required this.archivePageUrl,
  }) : super(key: key);

  @override
  _EHArchiveDialogState createState() => _EHArchiveDialogState();
}

class _EHArchiveDialogState extends State<EHArchiveDialog> {
  late String group;
  late List<String> candidates;
  late GalleryArchive archive;
  LoadingState loadingState = LoadingState.idle;
  LoadingState balanceState = LoadingState.idle;
  LoadingState botCostState = LoadingState.idle;
  int? balance;
  int? botCost;
  bool useBot = archiveBotSetting.isReady;

  @override
  void initState() {
    super.initState();

    group = widget.currentGroup ?? widget.candidates.firstOrNull ?? 'default'.tr;
    candidates = List.of(widget.candidates);
    candidates.remove(group);
    candidates.insert(0, group);
    
    _getArchiveInfo();
    
    if (useBot) {
      _checkBalance();
      _getBotCost();
    }
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
          successWidgetBuilder: _buildBody,
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        EHGroupNameSelector(candidates: candidates, currentGroup: group, listener: (g) => group = g),
        _buildSourceSelector().marginOnly(top: 12),
        if (!useBot && archive.creditCount != null && archive.gpCount != null)
          EHAsset(gpCount: archive.gpCount!, creditCount: archive.creditCount!).marginOnly(top: 12),
        if (useBot) _buildBalance().marginOnly(top: 12),
        Expanded(child: _buildButtons().marginOnly(top: 12)),
      ],
    );
  }

  Widget _buildSourceSelector() {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 24, vertical: 8)),
      ),
      segments: [
        ButtonSegment(
          value: false,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.language_outlined, size: UIConfig.archiveDialogDownloadIconSize),
              const SizedBox(width: 4),
              Text('official'.tr),
            ],
          ),
        ),
        ButtonSegment(
          value: true,
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.smart_toy_outlined, size: UIConfig.archiveDialogDownloadIconSize),
              const SizedBox(width: 4),
              Text('archiveBotShort'.tr),
            ],
          ),
        ),
      ],
      selected: {useBot},
      onSelectionChanged: (Set<bool> selection) => _switchSource(selection.first),
    );
  }

  Future<void> _switchSource(bool toBot) async {
    if (toBot == useBot) {
      return;
    }

    if (toBot && !archiveBotSetting.isReady) {
      bool? result = await Get.dialog(EHDialog(title: 'archiveBotNotConfigured'.tr));
      if (result == true) {
        backRoute();
        toRoute(Routes.archiveBotSettings);
      }
      return;
    }

    setState(() => useBot = toBot);
    unawaited(archiveBotSetting.savePreferBotSource(toBot));
    if (toBot) {
      if (balanceState != LoadingState.success) {
        unawaited(_checkBalance());
      }
      if (botCostState != LoadingState.success) {
        unawaited(_getBotCost());
      }
    }
  }

  Widget _buildBalance() {
    return LoadingStateIndicator(
      loadingState: balanceState,
      height: UIConfig.archiveDialogBalanceHeight,
      useCupertinoIndicator: true,
      indicatorRadius: 6,
      idleWidgetBuilder: () => const SizedBox(),
      successWidgetBuilder: () => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _CircleAssetChip(str: 'G'),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(balance?.toString() ?? '', style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
      errorWidgetBuilder: () => const Icon(Icons.error_outline, size: 16),
      errorTapCallback: _checkBalance,
    );
  }

  Future<void> _checkBalance() async {
    if (balanceState == LoadingState.loading) {
      return; 
    }
    if (!archiveBotSetting.isReady) {
      return;
    }

    setStateSafely(() => balanceState = LoadingState.loading);

    try {
      ArchiveBotResponse response = await archiveBotRequest.requestBalance(
        botType: archiveBotSetting.botType.value,
        apiAddress: archiveBotSetting.apiAddress.value!,
        apiKey: archiveBotSetting.apiKey.value!,
      );
      log.info('Check archive bot balance response: $response');

      if (response.isSuccess) {
        setStateSafely(() {
          balanceState = LoadingState.success;
          balance = archiveBotSetting.botType.value.parseBalance(response.data).gp;
        });
      } else {
        log.error('checkBalanceFailed'.tr, response.errorMessage);
        setStateSafely(() => balanceState = LoadingState.error);
      }
    } on DioException catch (e) {
      log.error('checkBalanceFailed'.tr, e.errorMsg, e.stackTrace);
      setStateSafely(() => balanceState = LoadingState.error);
    } catch (e) {
      log.error('checkBalanceFailed'.tr, e.toString(), StackTrace.current);
      setStateSafely(() => balanceState = LoadingState.error);
    }
  }

  Future<void> _getBotCost() async {
    if (botCostState == LoadingState.loading) {
      return;
    }

    setStateSafely(() => botCostState = LoadingState.loading);

    try {
      ({int filesize, int posted}) metadata = await ehRequest.requestGalleryMetadata(
        gid: widget.gid,
        token: widget.token,
        parser: EHSpiderParser.galleryMetadataJson2FileSizeAndPosted,
      );

      /// same formula as the archive bot server: base cost by filesize, tripled for galleries posted more than a year ago
      int now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      int multiplier = now - metadata.posted > 31536000 ? 3 : 1;
      int cost = (metadata.filesize / 1e6 * 20).toInt() + 1;

      setStateSafely(() {
        botCostState = LoadingState.success;
        botCost = cost * multiplier;
      });
    } on DioException catch (e) {
      log.error('getBotCostFailed'.tr, e.errorMsg, e.stackTrace);
      setStateSafely(() => botCostState = LoadingState.error);
    } catch (e) {
      log.error('getBotCostFailed'.tr, e.toString(), StackTrace.current);
      setStateSafely(() => botCostState = LoadingState.error);
    }
  }

  String _botCostText() {
    return switch (botCostState) {
      LoadingState.loading => '...',
      LoadingState.success => '$botCost GP',
      _ => 'N/A',
    };
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButtonSet(isOriginal: false),
        _buildButtonSet(isOriginal: true),
      ],
    );
  }

  Widget _buildButtonSet({required bool isOriginal}) {
    return _ArchiveButtonSet(
      cost: useBot ? _botCostText() : (isOriginal ? archive.originalCost : archive.resampleCost),
      size: isOriginal ? archive.originalSize : archive.resampleSize,
      text: isOriginal ? 'original'.tr : 'resample'.tr,
      callback: _canDownload(isOriginal: isOriginal)
          ? () => backRoute(
                result: (useBot: useBot, isOriginal: isOriginal, size: _computeSizeInBytes(isOriginal: isOriginal), group: group),
              )
          : null,
    );
  }

  Future<void> _getArchiveInfo() async {
    setState(() => loadingState = LoadingState.loading);

    try {
      archive = await ehRequest.get(url: widget.archivePageUrl, parser: EHSpiderParser.archivePage2Archive);
    } on DioException catch (e) {
      log.error('getGalleryArchiveFailed'.tr, e.errorMsg);
      snack('getGalleryArchiveFailed'.tr, e.errorMsg ?? '');
      setStateSafely(() => loadingState = LoadingState.error);
      return;
    } on EHSiteException catch (e) {
      log.error('getGalleryArchiveFailed'.tr, e.message);
      snack('getGalleryArchiveFailed'.tr, e.message);
      setStateSafely(() => loadingState = LoadingState.error);
      return;
    } on Exception catch (_) {
      snack('getGalleryArchiveFailed'.tr, 'parseGalleryArchiveFailed'.tr, isShort: true);
      if (mounted) {
        setState(() => loadingState = LoadingState.error);
      }
      return;
    } on Error catch (_) {
      snack('getGalleryArchiveFailed'.tr, 'parseGalleryArchiveFailed'.tr, isShort: true);
      if (mounted) {
        setState(() => loadingState = LoadingState.error);
      }
      return;
    }

    if (mounted) {
      setState(() => loadingState = LoadingState.success);
    }
  }

  bool _canDownload({required bool isOriginal}) {
    if (useBot) {
      if (isOriginal) {
        return true;
      }
      return archive.resampleSize != null;
    }
    return _canAffordDownload(isOriginal: isOriginal);
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

      /// we can use credits to afford GP cost
      return true;
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

      return true;
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
  final String? text;
  final VoidCallback? callback;

  const _ArchiveButtonSet({
    Key? key,
    this.cost,
    this.size,
    this.text,
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
          child: Text(text!, style: const TextStyle(fontSize: UIConfig.archiveDialogDownloadTextSize)),
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

class _CircleAssetChip extends StatelessWidget {
  final String str;

  const _CircleAssetChip({Key? key, required this.str}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: UIConfig.primaryColor(context), shape: BoxShape.circle),
      child: Center(
        child: Text(
          str,
          style: TextStyle(
            color: UIConfig.onPrimaryColor(context),
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}
