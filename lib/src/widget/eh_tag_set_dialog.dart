import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';

import '../config/ui_config.dart';
import '../exception/eh_site_exception.dart';
import '../model/tag_set.dart';
import '../network/eh_request.dart';
import '../setting/preference_setting.dart';
import '../utils/eh_spider_parser.dart';
import '../service/log.dart';
import '../utils/route_util.dart';
import '../utils/snack_util.dart';
import 'loading_state_indicator.dart';

class EHTagSetDialog extends StatefulWidget {
  const EHTagSetDialog({super.key});

  @override
  State<EHTagSetDialog> createState() => _EHTagSetDialogState();
}

class _EHTagSetDialogState extends State<EHTagSetDialog> {
  LoadingState _loadingState = LoadingState.idle;
  List<({int number, String name})> _tagSets = [];

  bool remember = false;

  @override
  void initState() {
    super.initState();
    _getTagSet();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      contentPadding: const EdgeInsets.only(top: 16, left: 12, right: 12, bottom: 16),
      title: Text('chooseTagSet'.tr),
      children: [
        if (_loadingState == LoadingState.loading) SizedBox(height: 24, child: Center(child: UIConfig.loadingAnimation(context))),
        if (_loadingState == LoadingState.error)
          GestureDetector(
            onTap: _getTagSet,
            child: Icon(FontAwesomeIcons.redoAlt, size: 24, color: UIConfig.loadingStateIndicatorButtonColor(context)),
          ),
        if (_loadingState == LoadingState.success)
          ..._tagSets
              .map(
                (tagSet) => ListTile(
                  title: Text(tagSet.name),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  onTap: () => backRoute(result: (tagSetNo: tagSet.number, remember: remember)),
                ),
              )
              .toList(),
        if (_loadingState == LoadingState.success && PreferenceSetting.enableDefaultTagSet.isTrue)
          ListTile(
            dense: true,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            visualDensity: const VisualDensity(vertical: -2, horizontal: -4),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text('asYourDefault'.tr), Checkbox(value: remember, onChanged: (value) => setState(() => remember = value!))],
            ),
          )
      ],
    );
  }

  Future<void> _getTagSet() async {
    setStateSafely(() {
      _loadingState = LoadingState.loading;
    });

    ({List<({int number, String name})> tagSets, bool tagSetEnable, Color? tagSetBackgroundColor, List<WatchedTag> tags, String apikey}) pageInfo;
    try {
      pageInfo = await EHRequest.requestMyTagsPage(
        parser: EHSpiderParser.myTagsPage2TagSetNamesAndTagSetsAndApikey,
      );
    } on DioException catch (e) {
      log.error('getTagSetFailed'.tr, e.errorMsg);
      snack('getTagSetFailed'.tr, e.errorMsg ?? '', isShort: true);
      setStateSafely(() {
        _loadingState = LoadingState.error;
      });
      return;
    } on EHSiteException catch (e) {
      log.error('getTagSetFailed'.tr, e.message);
      snack('getTagSetFailed'.tr, e.message, isShort: true);
      setStateSafely(() {
        _loadingState = LoadingState.error;
      });
      return;
    } catch (e) {
      log.error('getTagSetFailed'.tr, e.toString());
      snack('getTagSetFailed'.tr, e.toString(), isShort: true);
      setStateSafely(() {
        _loadingState = LoadingState.error;
      });
      return;
    }

    setStateSafely(() {
      _tagSets = pageInfo.tagSets;
      _loadingState = LoadingState.success;
    });
  }
}
