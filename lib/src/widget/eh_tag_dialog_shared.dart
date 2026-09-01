import 'package:clipboard/clipboard.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/exception/eh_parse_exception.dart';
import 'package:jhentai/src/exception/eh_site_exception.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/mixin/login_required_logic_mixin.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/setting/my_tags_setting.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/setting/style_setting.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_tag_edit_dialog.dart';
import 'package:jhentai/src/widget/eh_tag_set_dialog.dart';
import 'package:jhentai/src/widget/eh_warning_image.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../database/database.dart';
import '../model/gallery_tag.dart';
import '../model/tag_set.dart';
import '../network/eh_request.dart';
import '../setting/user_setting.dart';
import '../service/log.dart';
import '../utils/color_util.dart';
import '../utils/snack_util.dart';
import '../utils/string_uril.dart';
import 'loading_state_indicator.dart';

typedef OnTagVoted = void Function(bool isVotingUp, bool isCancel);

/// Shared business logic (vote / tag-set operations) for the tag dialog (desktop)
/// and the tag bottom sheet (mobile). Host states must also mix in
/// [LoginRequiredMixin] to satisfy [showLoginToast].
mixin EHTagVoteLogicMixin<T extends StatefulWidget> on State<T> implements LoginRequiredMixin {
  @override
  bool checkLogin() {
    if (!userSetting.hasLoggedIn()) {
      showLoginToast();
      return false;
    }
    return true;
  }

  @override
  void showLoginToast() {
    toast('needLoginToOperate'.tr);
  }

  TagData get tagData;

  int get gid;

  String get token;

  String get apikey;

  OnTagVoted? get onTagVoted;

  EHTagVoteStatus? get voteStatus;

  LoadingState voteUpState = LoadingState.idle;
  LoadingState voteDownState = LoadingState.idle;
  LoadingState addWatchedTagState = LoadingState.idle;
  LoadingState addHiddenTagState = LoadingState.idle;

  bool? currentVote;

  void initTagVoteState() {
    currentVote = voteStatus == EHTagVoteStatus.up
        ? true
        : voteStatus == EHTagVoteStatus.down
            ? false
            : null;
  }

  ({int tagSetNo, bool watched, bool hidden})? findOnlineTag() {
    for (final entry in myTagsSetting.onlineTags.entries) {
      for (final tag in entry.value.tags) {
        if (tag.tagData.namespace == tagData.namespace && tag.tagData.key == tagData.key) {
          return (tagSetNo: entry.key, watched: tag.watched == true, hidden: tag.hidden == true);
        }
      }
    }
    return null;
  }

  int? findOnlineWatchedTagId() {
    for (final entry in myTagsSetting.onlineTags.entries) {
      for (final tag in entry.value.tags) {
        if (tag.tagData.namespace == tagData.namespace && tag.tagData.key == tagData.key) {
          return tag.tagId;
        }
      }
    }
    return null;
  }

  Future<void> vote({required bool isVotingUp}) async {
    if (!userSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    if (voteUpState == LoadingState.loading || voteDownState == LoadingState.loading) {
      return;
    }

    final bool? previousVote = currentVote;
    final bool isCancel = currentVote != null;

    // On E-Hentai, cancelling an existing vote is done by sending the opposite vote,
    // so the API direction may differ from the button the user tapped.
    final bool requestIsVotingUp = isCancel ? !previousVote! : isVotingUp;

    setState(() {
      voteUpState = isVotingUp ? LoadingState.loading : LoadingState.idle;
      voteDownState = isVotingUp ? LoadingState.idle : LoadingState.loading;
      currentVote = isCancel ? null : isVotingUp;
    });

    bool success = await doVote(requestIsVotingUp: requestIsVotingUp, clickedIsVotingUp: isVotingUp);
    if (!success) {
      setStateSafely(() => currentVote = previousVote);
    } else {
      onTagVoted?.call(isVotingUp, isCancel);
    }
  }

  Future<bool> doVote({required bool requestIsVotingUp, required bool clickedIsVotingUp}) async {
    log.info('Vote for tag:${tagData.key}, requestIsVotingUp: $requestIsVotingUp, clickedIsVotingUp: $clickedIsVotingUp');

    String? errMsg;
    try {
      errMsg = await ehRequest.voteTag(
        gid,
        token,
        userSetting.ipbMemberId.value!,
        apikey,
        '${tagData.namespace}:${tagData.key}',
        requestIsVotingUp,
        parser: EHSpiderParser.voteTagResponse2ErrorMessage,
      );
    } on DioException catch (e) {
      log.error('voteTagFailed'.tr, e.message);
      snack('voteTagFailed'.tr, e.message ?? '');
      setStateSafely(() {
        if (clickedIsVotingUp) {
          voteUpState = LoadingState.idle;
        } else {
          voteDownState = LoadingState.idle;
        }
      });
      return false;
    } on EHSiteException catch (e) {
      log.error('voteTagFailed'.tr, e.message);
      snack('voteTagFailed'.tr, e.message);
      setStateSafely(() {
        if (clickedIsVotingUp) {
          voteUpState = LoadingState.idle;
        } else {
          voteDownState = LoadingState.idle;
        }
      });
      return false;
    }

    bool success = isEmptyOrNull(errMsg);
    setStateSafely(() {
      if (clickedIsVotingUp) {
        voteUpState = success ? LoadingState.success : LoadingState.idle;
      } else {
        voteDownState = success ? LoadingState.success : LoadingState.idle;
      }
    });

    if (success) {
      toast('success'.tr);
      return true;
    } else {
      snack('voteTagFailed'.tr, errMsg!, isShort: true);
      return false;
    }
  }

  Future<void> handleAddTagToSet({required bool watch}) async {
    if (!userSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }

    if (addWatchedTagState == LoadingState.loading || addHiddenTagState == LoadingState.loading) {
      return;
    }

    // Issue #405: always allow re-selecting the tag set, even if the tag is already
    // watched / hidden. EH keeps the tag only in the most recently added set, so this
    // effectively moves the tag to the newly chosen set.
    final int? previousTagSetNo = findOnlineTag()?.tagSetNo;

    // The default tag set shortcut only applies to first-time adds; moving an
    // already-categorized tag should always go through the selection dialog.
    if (previousTagSetNo == null && preferenceSetting.enableDefaultTagSet.isTrue && userSetting.defaultTagSetNo.value != null) {
      await doAddNewTagSet(userSetting.defaultTagSetNo.value!, watch);
      return;
    }

    ({int tagSetNo, bool remember})? result = await Get.dialog(EHTagSetDialog(currentTagSetNo: previousTagSetNo));
    if (result == null) {
      return;
    }

    if (result.remember == true) {
      userSetting.saveDefaultTagSetNo(result.tagSetNo);
    }

    // Picking the set the tag already belongs to removes it (toggle behavior).
    if (previousTagSetNo != null && result.tagSetNo == previousTagSetNo) {
      await doDeleteWatchedTag(tagSetNo: result.tagSetNo, watch: watch);
      return;
    }

    await doAddNewTagSet(result.tagSetNo, watch, previousTagSetNo: previousTagSetNo);
  }

  /// Follow/hide buttons open this editor instead when the tag is already in a
  /// tag set, so users can tweak status / weight / color right from the detail page.
  void showTagEditDialog({required int tagSetNo}) {
    ({bool enable, Color? tagSetBackGroundColor, List<WatchedTag> tags})? tagSet = myTagsSetting.onlineTags[tagSetNo];
    if (tagSet == null) {
      return;
    }

    WatchedTag? onlineTag = tagSet.tags.firstWhereOrNull(
      (t) => t.tagData.namespace == tagData.namespace && t.tagData.key == tagData.key,
    );
    if (onlineTag == null) {
      return;
    }

    bool useDialog = !styleSetting.isInMobileLayout;

    Widget dialog = EHTagEditDialog(
      tag: onlineTag,
      tagSetBackgroundColor: tagSet.tagSetBackGroundColor,
      isDialog: useDialog,
      onConfirm: (_, WatchedTag newTag) => doUpdateWatchedTag(newTag, tagSetNo: tagSetNo),
      onDelete: (WatchedTag _) => doDeleteWatchedTag(tagSetNo: tagSetNo, watch: onlineTag.watched),
    );

    if (useDialog) {
      // Get.dialog doesn't provide a Material ancestor like Dialog does, and the
      // editor content (InkWell / SegmentedButton / buttons) requires one.
      Get.dialog(Dialog(child: dialog), barrierDismissible: true);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => SingleChildScrollView(child: dialog),
      );
    }
  }

  /// Update a watched tag's status / weight / color, then refresh the local cache
  /// before flipping the button state so the UI reflects everything in one go.
  Future<void> doUpdateWatchedTag(WatchedTag newTag, {required int tagSetNo}) async {
    log.info('Update watched tag: ${newTag.tagData.namespace}:${newTag.tagData.key}, tagSetNo:$tagSetNo');

    setStateSafely(() {
      addWatchedTagState = LoadingState.loading;
      addHiddenTagState = LoadingState.loading;
    });

    try {
      await ehRequest.requestUpdateWatchedTag(
        apiuid: userSetting.ipbMemberId.value!,
        apikey: apikey,
        tagId: newTag.tagId,
        tagColor: color2aRGBString(newTag.backgroundColor),
        tagWeight: newTag.weight,
        watch: newTag.watched,
        hidden: newTag.hidden,
      );
    } on DioException catch (e) {
      log.error('updateTagFailed'.tr, e.errorMsg);
      toast('${'updateTagFailed'.tr}: ${e.errorMsg}', isShort: false);
      setStateSafely(() {
        addWatchedTagState = LoadingState.idle;
        addHiddenTagState = LoadingState.idle;
      });
      return;
    } on EHSiteException catch (e) {
      log.error('updateTagFailed'.tr, e.message);
      toast('${'updateTagFailed'.tr}: ${e.message}', isShort: false);
      setStateSafely(() {
        addWatchedTagState = LoadingState.idle;
        addHiddenTagState = LoadingState.idle;
      });
      return;
    }

    await myTagsSetting.refreshOnlineTagSets(tagSetNo);

    setStateSafely(() {
      addWatchedTagState = LoadingState.idle;
      addHiddenTagState = LoadingState.idle;
    });

    toast('success'.tr);
  }

  Future<void> doDeleteWatchedTag({required int tagSetNo, required bool watch}) async {
    final int? tagId = findOnlineWatchedTagId();
    if (tagId == null) {
      return;
    }

    log.info('Delete watched tag: ${tagData.namespace}:${tagData.key}, tagSetNo:$tagSetNo');

    setStateSafely(() {
      if (watch) {
        addWatchedTagState = LoadingState.loading;
      } else {
        addHiddenTagState = LoadingState.loading;
      }
    });

    try {
      await ehRequest.requestDeleteWatchedTag(watchedTagId: tagId, tagSetNo: tagSetNo);
    } on DioException catch (e) {
      log.error('deleteTagFailed'.tr, e.errorMsg);
      toast('${'deleteTagFailed'.tr}: ${e.errorMsg}', isShort: false);
      setStateSafely(() {
        if (watch) {
          addWatchedTagState = LoadingState.idle;
        } else {
          addHiddenTagState = LoadingState.idle;
        }
      });
      return;
    } on EHSiteException catch (e) {
      log.error('deleteTagFailed'.tr, e.message);
      toast('${'deleteTagFailed'.tr}: ${e.message}', isShort: false);
      setStateSafely(() {
        if (watch) {
          addWatchedTagState = LoadingState.idle;
        } else {
          addHiddenTagState = LoadingState.idle;
        }
      });
      return;
    }

    await myTagsSetting.refreshOnlineTagSets(tagSetNo);

    setStateSafely(() {
      addWatchedTagState = LoadingState.idle;
      addHiddenTagState = LoadingState.idle;
    });

    toast('deleteTagSuccess'.tr);
  }

  Future<void> doAddNewTagSet(int tagSetNumber, bool watch, {int? previousTagSetNo}) async {
    log.info('Add new watched tag: ${tagData.namespace}:${tagData.key},tagSetNumber:$tagSetNumber, watch:$watch');

    setStateSafely(() {
      if (watch) {
        addWatchedTagState = LoadingState.loading;
      } else {
        addHiddenTagState = LoadingState.loading;
      }
    });

    try {
      await ehRequest.requestAddWatchedTag(
        tag: '${tagData.namespace}:${tagData.key}',
        tagWeight: 10,
        watch: watch,
        hidden: !watch,
        tagSetNo: tagSetNumber,
        parser: EHSpiderParser.addTagSetResponse2Result,
      );
    } on DioException catch (e) {
      log.error('addNewTagSetFailed'.tr, e.errorMsg);
      toast('${'addNewTagSetFailed'.tr}: ${e.errorMsg}', isShort: false);
      setStateSafely(() {
        if (watch) {
          addWatchedTagState = LoadingState.idle;
        } else {
          addHiddenTagState = LoadingState.idle;
        }
      });
      return;
    } on EHParseException catch (e) {
      toast(e.message.tr, isShort: false);
      setStateSafely(() {
        if (watch) {
          addWatchedTagState = LoadingState.idle;
        } else {
          addHiddenTagState = LoadingState.idle;
        }
      });
      return;
    }

    /// Wait for the cache refresh before flipping to success, so the button
    /// reflects the new watched/hidden status and the tag set in one go.
    await Future.wait([
      myTagsSetting.refreshOnlineTagSets(tagSetNumber),
      if (previousTagSetNo != null && previousTagSetNo != tagSetNumber) myTagsSetting.refreshOnlineTagSets(previousTagSetNo),
    ]);

    setStateSafely(() {
      if (watch) {
        addWatchedTagState = LoadingState.success;
      } else {
        addHiddenTagState = LoadingState.success;
      }
    });

    toast(watch ? 'addNewWatchedTagSetSuccess'.tr : 'addNewHiddenTagSetSuccess'.tr);
  }

  void gotoTagSets() {
    if (!userSetting.hasLoggedIn()) {
      showLoginToast();
      return;
    }
    backRoute();
    toRoute(Routes.tagSets);
  }
}

/// Shared header + HTML intro widgets for [EHTagDialog] and [EHTagBottomSheet].
class EHTagDialogHeader extends StatelessWidget {
  final TagData tagData;
  final bool showCloseButton;

  const EHTagDialogHeader({Key? key, required this.tagData, this.showCloseButton = false}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => FlutterClipboard.copy('${tagData.namespace}:"${tagData.key}"').then((_) => toast('hasCopiedToClipboard'.tr)),
                  child: Text(
                    '${tagData.namespace}:${tagData.key}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (tagData.tagName != null)
                  Text(
                    '${tagData.translatedNamespace ?? tagData.namespace}:${tagData.tagName}',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                  ),
              ],
            ),
          ),
          if (showCloseButton)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: backRoute,
            ),
        ],
      ),
    );
  }
}

class EHTagDialogInfo extends StatelessWidget {
  final TagData tagData;
  final double maxHeight;
  final ScrollController scrollController;

  const EHTagDialogInfo({Key? key, required this.tagData, required this.maxHeight, required this.scrollController}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String content = tagData.fullTagName! + tagData.intro! + tagData.links!;

    // ListViewMode.padding keeps the scrollbar flush with the viewport's right edge
    // (the scrollbar is drawn outside the viewport padding) while the text keeps
    // its horizontal inset.
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: EHWheelSpeedController(
          controller: scrollController,
          child: HtmlWidget(
            content,
            renderMode: ListViewMode(
              shrinkWrap: true,
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            ),
            textStyle: const TextStyle(fontSize: 13),
            onErrorBuilder: (context, element, error) => Text('$element error: $error'),
            onLoadingBuilder: (context, element, loadingProgress) => const CircularProgressIndicator(),
            onTapUrl: launchUrlString,
            customWidgetBuilder: (element) {
              if (element.localName != 'img') {
                return null;
              }
              return Center(
                child: EHWarningImage(
                  warning: preferenceSetting.showR18GImageDirectly.isFalse && element.attributes['nsfw'] == 'R18G',
                  src: element.attributes['src']!,
                ).marginSymmetric(vertical: 20),
              );
            },
          ),
        ),
      ),
    ).enableMouseDrag();
  }
}
