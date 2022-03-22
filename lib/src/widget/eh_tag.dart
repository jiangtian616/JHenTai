import 'package:dio/dio.dart';
import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/get_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../consts/color_consts.dart';
import '../setting/gallery_setting.dart';
import '../setting/user_setting.dart';

class EHTag extends StatefulWidget {
  final String namespace;
  final String tagName;
  final bool withColor;
  final bool inZh;
  final double borderRadius;
  final double fontSize;
  final double textHeight;
  final EdgeInsetsGeometry padding;
  final bool enableTapping;

  const EHTag({
    Key? key,
    required this.namespace,
    required this.tagName,
    this.withColor = false,
    this.inZh = false,
    this.borderRadius = 7,
    this.fontSize = 13,
    this.textHeight = 1.3,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    this.enableTapping = false,
  }) : super(key: key);

  @override
  _EHTagState createState() => _EHTagState();
}

class _EHTagState extends State<EHTag> {
  final TagTranslationService tagTranslationService = Get.find();
  TagData? tagData;

  @override
  void initState() {
    if (GallerySetting.enableTagZHTranslation.isTrue && tagTranslationService.loadingState.value == LoadingState.success) {
      tagTranslationService.getTagTranslation(widget.tagName, widget.namespace).then((tagData) {
        setState(() {
          this.tagData = tagData;
        });
      });
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget tag = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        color: widget.withColor ? ColorConsts.tagCategoryColor[widget.tagName] : Colors.grey.shade200,
        padding: widget.padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              tagData?.tagName ?? widget.tagName,
              style: TextStyle(
                fontSize: widget.fontSize,
                height: widget.textHeight,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );

    if (!widget.enableTapping) {
      return tag;
    }

    return InkWell(
      child: tag,
      borderRadius: BorderRadius.circular(widget.borderRadius),
      onTap: _searchTag,
      onLongPress: _showDialog,
    );
  }

  void _searchTag() {}

  void _showDialog() {
    Get.dialog(_TagDialog(
      namespace: widget.namespace,
      tagName: widget.tagName,
      tagData: tagData,
    ));
  }
}

class _TagDialog extends StatefulWidget {
  final String namespace;
  final String tagName;
  final TagData? tagData;

  const _TagDialog({
    Key? key,
    required this.namespace,
    required this.tagName,
    this.tagData,
  }) : super(key: key);

  @override
  _TagDialogState createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  LoadingState voteUpState = LoadingState.idle;
  LoadingState voteDownState = LoadingState.idle;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text('${widget.namespace}:${widget.tagName}'),
      titlePadding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 8.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            LoadingStateIndicator(
              loadingState: voteUpState,
              idleWidget: GestureDetector(
                onTap: () => _vote(true),
                child: Icon(Icons.thumb_up, color: Colors.green.shade700),
              ),
              successWidget: const DoneWidget(),
            ),
            LoadingStateIndicator(
              loadingState: voteDownState,
              idleWidget: GestureDetector(
                onTap: () => _vote(false),
                child: Icon(Icons.thumb_down, color: Colors.red.shade700),
              ),
              successWidget: DoneWidget(),
            ),
            if (widget.tagData != null)
              GestureDetector(
                onTap: () => _showInfo(),
                child: Icon(Icons.visibility, color: Colors.blue.shade700),
              ),
          ],
        )
      ],
    );
  }

  Future<bool> _vote(bool isVotingUp) async {
    if (!UserSetting.hasLoggedIn()) {
      Get.snackbar('operationFailed'.tr, 'needLoginToOperate'.tr);
      return false;
    }

    final DetailsPageState state = Get.find<DetailsPageLogic>().state;

    setState(() {
      if (isVotingUp) {
        voteUpState = LoadingState.loading;
      } else {
        voteDownState = LoadingState.loading;
      }
    });

    try {
      await EHRequest.voteTag(
        state.gallery!.gid,
        state.gallery!.token,
        UserSetting.ipbMemberId.value!,
        state.apikey,
        widget.namespace,
        widget.tagName,
        isVotingUp,
      );
    } on DioError catch (e) {
      setState(() {
        if (isVotingUp) {
          voteUpState = LoadingState.error;
        } else {
          voteDownState = LoadingState.error;
        }
      });
      Log.error('vote tag failed', e.message);
      Get.snackbar('vote tag failed', e.message);
      return false;
    }

    setState(() {
      if (isVotingUp) {
        voteUpState = LoadingState.success;
      } else {
        voteDownState = LoadingState.success;
      }
    });

    return true;
  }

  _showInfo() {
    Get.back();
    Get.dialog(
      SimpleDialog(
        children: [
          HtmlWidget(
            widget.tagData!.fullTagName + widget.tagData!.intro + widget.tagData!.links,
            onErrorBuilder: (context, element, error) => Text('$element error: $error'),
            onLoadingBuilder: (context, element, loadingProgress) => CircularProgressIndicator(),
            onTapUrl: (url) {
              print('tapped $url');
              return true;
            },
            renderMode: RenderMode.column,
            // set the default styling for text
            textStyle: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
