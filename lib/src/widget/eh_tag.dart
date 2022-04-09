import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/pages/details/details_page_state.dart';
import 'package:jhentai/src/utils/log.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../consts/color_consts.dart';
import '../model/gallery_tag.dart';
import '../pages/search/search_page_logic.dart';
import '../routes/routes.dart';
import '../setting/user_setting.dart';
import '../utils/route_util.dart';
import '../utils/snack_util.dart';

class EHTag extends StatefulWidget {
  final GalleryTag tag;
  final bool addNameSpaceColor;
  final double borderRadius;
  final double fontSize;
  final double textHeight;
  final EdgeInsetsGeometry padding;
  final bool enableTapping;

  const EHTag({
    Key? key,
    required this.tag,
    this.addNameSpaceColor = false,
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
  @override
  Widget build(BuildContext context) {
    Widget tag = ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        color: widget.tag.backgroundColor ??
            (widget.addNameSpaceColor
                ? ColorConsts.zhTagNameSpaceColor[widget.tag.tagData.key] ??
                    ColorConsts.tagNameSpaceColor[widget.tag.tagData.key]!
                : Get.theme.brightness == Brightness.light
                    ? Colors.grey.shade200
                    : Colors.grey.shade800),
        padding: widget.padding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.tag.tagData.tagName ?? widget.tag.tagData.key,
              style: TextStyle(
                fontSize: widget.fontSize,
                height: widget.textHeight,
                color:widget.tag.color ?? (widget.addNameSpaceColor
                        ? Colors.black
                        : Get.theme.brightness == Brightness.light
                            ? Colors.grey.shade800
                            : Colors.grey.shade300),
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

  void _searchTag() {
    if (isAtTop(Routes.search)) {
      SearchPageLogic searchPageLogic = SearchPageLogic.current!;
      searchPageLogic.state.tabBarConfig.searchConfig.keyword = '${widget.tag.tagData.namespace}:"${widget.tag.tagData.key}\$"';
      searchPageLogic.searchMore();
    } else {
      toNamed(
        Routes.search,
        arguments: '${widget.tag.tagData.namespace}:"${widget.tag.tagData.key}\$"',
      );
    }
  }

  void _showDialog() {
    Get.dialog(_TagDialog(tagData: widget.tag.tagData));
  }
}

class _TagDialog extends StatefulWidget {
  final TagData tagData;

  const _TagDialog({Key? key, required this.tagData}) : super(key: key);

  @override
  _TagDialogState createState() => _TagDialogState();
}

class _TagDialogState extends State<_TagDialog> {
  LoadingState voteUpState = LoadingState.idle;
  LoadingState voteDownState = LoadingState.idle;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text('${widget.tagData.namespace}:${widget.tagData.key}'),
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
            if (widget.tagData.tagName != null)
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
      snack('operationFailed'.tr, 'needLoginToOperate'.tr);
      return false;
    }

    final DetailsPageState state = DetailsPageLogic.current!.state;

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
        widget.tagData.namespace,
        widget.tagData.key,
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
      Log.error('voteTagFailed'.tr, e.message);
      snack('voteTagFailed'.tr, e.message);
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
    back();

    String content = widget.tagData.fullTagName! + widget.tagData.intro! + widget.tagData.links!;
    Get.dialog(
      SimpleDialog(
        title: const Text('所有数据来源于EhTagTranslation'),
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: 50,
              minWidth: 200,
              maxHeight: 400,
              maxWidth: 200,
            ),
            child: HtmlWidget(
              content,
              renderMode: content.contains('img') ? RenderMode.listView : RenderMode.column,
              textStyle: const TextStyle(fontSize: 12),
              onErrorBuilder: (context, element, error) => Text('$element error: $error'),
              onLoadingBuilder: (context, element, loadingProgress) => const CircularProgressIndicator(),
              onTapUrl: (url) async {
                return await launch(url);
              },
              customWidgetBuilder: (element) {
                if (element.localName != 'img') {
                  return null;
                }
                return Center(
                  child: ExtendedImage.network(element.attributes['src']!).marginSymmetric(vertical: 20),
                );
              },
            ).paddingSymmetric(horizontal: 20),
          ),
        ],
      ),
    );
  }
}
