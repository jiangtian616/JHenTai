import 'package:clipboard/clipboard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/mixin/login_required_logic_mixin.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_warning_image.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:like_button/like_button.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../config/ui_config.dart';
import '../database/database.dart';
import '../network/eh_request.dart';
import '../setting/user_setting.dart';
import '../utils/log.dart';
import '../utils/snack_util.dart';
import '../utils/string_uril.dart';
import 'loading_state_indicator.dart';

class EHTagDialog extends StatefulWidget {
  final TagData tagData;
  final int gid;
  final String token;
  final String apikey;

  const EHTagDialog({
    Key? key,
    required this.tagData,
    required this.gid,
    required this.token,
    required this.apikey,
  }) : super(key: key);

  @override
  _EHTagDialogState createState() => _EHTagDialogState();
}

class _EHTagDialogState extends State<EHTagDialog> with LoginRequiredMixin {
  LoadingState voteUpState = LoadingState.idle;
  LoadingState voteDownState = LoadingState.idle;
  LoadingState addWatchedTagState = LoadingState.idle;
  LoadingState addHiddenTagState = LoadingState.idle;

  ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    super.dispose();
    scrollController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: GestureDetector(
        child: Text('${widget.tagData.namespace}:${widget.tagData.key}'),
        onTap: () => FlutterClipboard.copy('${widget.tagData.namespace}:"${widget.tagData.key}"').then((_) => toast('hasCopiedToClipboard'.tr)),
      ),
      contentPadding: const EdgeInsets.only(left: 12, right: 12, bottom: 12, top: 12),
      children: [
        if (widget.tagData.tagName != null) ...[
          _buildInfo(),
          const Divider(height: 1).marginOnly(top: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildVoteUpButton(),
            _buildVoteDownButton(),
            _buildWatchTagButton(),
            _buildHideTagButton(),
            _buildFilterLocalTagButton(),
            if (UserSetting.hasLoggedIn()) _buildGoToTagSetsButton(),
          ],
        ).marginOnly(top: 12),
      ],
    );
  }

  Widget _buildInfo() {
    String content = widget.tagData.fullTagName! + widget.tagData.intro! + widget.tagData.links!;

    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 50,
        maxHeight: 400,
        minWidth: 200,
        maxWidth: 200,
      ),
      child: EHWheelSpeedController(
        controller: scrollController,
        child: HtmlWidget(
          content,
          renderMode: ListViewMode(shrinkWrap: true, controller: scrollController),
          textStyle: const TextStyle(fontSize: 12),
          onErrorBuilder: (context, element, error) => Text('$element error: $error'),
          onLoadingBuilder: (context, element, loadingProgress) => const CircularProgressIndicator(),
          onTapUrl: launchUrlString,
          customWidgetBuilder: (element) {
            if (element.localName != 'img') {
              return null;
            }
            return Center(
              child: EHWarningImage(
                warning: PreferenceSetting.showR18GImageDirectly.isFalse && element.attributes['nsfw'] == 'R18G',
                src: element.attributes['src']!,
              ).marginSymmetric(vertical: 20),
            );
          },
        ).paddingSymmetric(horizontal: 12),
      ),
    );
  }

  Widget _buildVoteUpButton() {
    return LikeButton(
      likeBuilder: (bool liked) => Icon(
        Icons.thumb_up,
        size: UIConfig.tagDialogButtonSize,
        color: liked ? UIConfig.tagDialogLikedButtonColor(context) : UIConfig.tagDialogButtonColor(context),
      ),
      onTap: (bool liked) => liked ? Future.value(true) : vote(isVotingUp: true),
    );
  }

  Widget _buildVoteDownButton() {
    return LikeButton(
      likeBuilder: (bool liked) => Icon(
        Icons.thumb_down,
        size: UIConfig.tagDialogButtonSize,
        color: liked ? UIConfig.tagDialogLikedButtonColor(context) : UIConfig.tagDialogButtonColor(context),
      ),
      onTap: (bool liked) => liked ? Future.value(true) : vote(isVotingUp: false),
    );
  }

  Widget _buildWatchTagButton() {
    return LikeButton(
      isLiked: MyTagsSetting.containWatchedOnlineLocalTag(widget.tagData),
      likeBuilder: (bool liked) => Icon(
        Icons.favorite,
        size: UIConfig.tagDialogButtonSize,
        color: liked ? UIConfig.tagDialogLikedButtonColor(context) : UIConfig.tagDialogButtonColor(context),
      ),
      onTap: (bool liked) => liked ? Future.value(true) : addNewTagSet(true),
    );
  }

  Widget _buildHideTagButton() {
    return LikeButton(
      isLiked: MyTagsSetting.containHiddenOnlineLocalTag(widget.tagData),
      likeBuilder: (bool liked) => Icon(
        Icons.visibility_off,
        size: UIConfig.tagDialogButtonSize,
        color: liked ? UIConfig.tagDialogLikedButtonColor(context) : UIConfig.tagDialogButtonColor(context),
      ),
      onTap: (bool liked) => liked ? Future.value(true) : addNewTagSet(false),
    );
  }

  Widget _buildFilterLocalTagButton() {
    return LikeButton(
      isLiked: MyTagsSetting.containLocalTag(widget.tagData),
      likeBuilder: (bool liked) => Icon(
        Icons.cancel_outlined,
        size: UIConfig.tagDialogButtonSize,
        color: liked ? UIConfig.tagDialogLikedButtonColor(context) : UIConfig.tagDialogButtonColor(context),
      ),
      onTap: (bool liked) {
        if (liked) {
          MyTagsSetting.removeLocalTagSet(widget.tagData);
          return Future.value(false);
        } else {
          MyTagsSetting.addLocalTagSet(widget.tagData);
          return Future.value(true);
        }
      },
    );
  }

  Widget _buildGoToTagSetsButton() {
    return LikeButton(
      likeBuilder: (_) => Icon(
        Icons.settings,
        size: UIConfig.tagDialogButtonSize,
        color: UIConfig.tagDialogButtonColor(context),
      ),
      onTap: (_) async {
        backRoute();
        toRoute(Routes.tagSets);
        return null;
      },
    );
  }

  Future<bool> vote({required bool isVotingUp}) async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return false;
    }

    if (voteUpState == LoadingState.loading || voteDownState == LoadingState.loading) {
      return true;
    }

    if (isVotingUp) {
      voteUpState = LoadingState.loading;
    } else {
      voteDownState = LoadingState.loading;
    }

    _doVote(isVotingUp: isVotingUp);

    return true;
  }

  Future<void> _doVote({required bool isVotingUp}) async {
    Log.info('Vote for tag:${widget.tagData.key}, isVotingUp: $isVotingUp');

    String? errMsg;
    try {
      errMsg = await EHRequest.voteTag(
        widget.gid,
        widget.token,
        UserSetting.ipbMemberId.value!,
        widget.apikey,
        '${widget.tagData.namespace}:${widget.tagData.key}',
        isVotingUp,
        parser: EHSpiderParser.voteTagResponse2ErrorMessage,
      );
    } on DioError catch (e) {
      if (isVotingUp) {
        voteUpState = LoadingState.error;
      } else {
        voteDownState = LoadingState.error;
      }
      Log.error('voteTagFailed'.tr, e.message);
      snack('voteTagFailed'.tr, e.message);
      return;
    } on EHException catch (e) {
      if (isVotingUp) {
        voteUpState = LoadingState.error;
      } else {
        voteDownState = LoadingState.error;
      }
      Log.error('voteTagFailed'.tr, e.message);
      snack('voteTagFailed'.tr, e.message);
      return;
    }
    
    if (isVotingUp) {
      voteUpState = LoadingState.success;
    } else {
      voteDownState = LoadingState.success;
    }
    
    if (!isEmptyOrNull(errMsg)) {
      snack('voteTagFailed'.tr, errMsg!, longDuration: true);
      return;
    } else {
      toast('success'.tr);
    }
  }

  Future<bool> addNewTagSet(bool watch) async {
    if (!UserSetting.hasLoggedIn()) {
      showLoginToast();
      return false;
    }

    if (addWatchedTagState == LoadingState.loading || addHiddenTagState == LoadingState.loading) {
      return true;
    }

    if (watch) {
      addWatchedTagState = LoadingState.loading;
    } else {
      addHiddenTagState = LoadingState.loading;
    }

    _doAddNewTagSet(watch);

    return true;
  }

  Future<void> _doAddNewTagSet(bool watch) async {
    Log.info('Add new tag set: ${widget.tagData.namespace}:${widget.tagData.key}, watch:$watch');

    try {
      await EHRequest.requestAddTagSet(
        tag: '${widget.tagData.namespace}:${widget.tagData.key}',
        tagWeight: 10,
        watch: watch,
        hidden: !watch,
        parser: EHSpiderParser.addTagSetResponse2Result,
      );
    } on DioError catch (e) {
      Log.error('addNewTagSetFailed'.tr, e.message);
      toast('${'addNewTagSetFailed'.tr}: ${e.message}', isShort: false);

      if (watch) {
        addWatchedTagState = LoadingState.error;
      } else {
        addHiddenTagState = LoadingState.error;
      }
      return;
    } on EHException catch (e) {
      toast(e.message.tr, isShort: false);
      if (watch) {
        addWatchedTagState = LoadingState.error;
      } else {
        addHiddenTagState = LoadingState.error;
      }
      return;
    }

    if (watch) {
      addWatchedTagState = LoadingState.success;
    } else {
      addHiddenTagState = LoadingState.success;
    }

    toast(watch ? 'addNewWatchedTagSetSuccess'.tr : 'addNewHiddenTagSetSuccess'.tr);
  }
}
