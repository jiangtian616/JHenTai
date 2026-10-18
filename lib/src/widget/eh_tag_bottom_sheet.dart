import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/widget/eh_tag_dialog_mobile_actions.dart';

import '../database/database.dart';
import '../model/gallery_tag.dart';
import 'eh_tag_dialog_shared.dart';

/// Modal bottom sheet for tag details on mobile.
class EHTagBottomSheet extends StatefulWidget {
  final TagData tagData;
  final int gid;
  final String token;
  final String apikey;
  final EHTagVoteStatus? voteStatus;
  final OnTagVoted? onTagVoted;

  const EHTagBottomSheet({
    Key? key,
    required this.tagData,
    required this.gid,
    required this.token,
    required this.apikey,
    this.voteStatus,
    this.onTagVoted,
  }) : super(key: key);

  static Future<void> show({
    required TagData tagData,
    required int gid,
    required String token,
    required String apikey,
    EHTagVoteStatus? voteStatus,
    OnTagVoted? onTagVoted,
  }) {
    return showModalBottomSheet(
      context: Get.context!,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => EHTagBottomSheet(
        tagData: tagData,
        gid: gid,
        token: token,
        apikey: apikey,
        voteStatus: voteStatus,
        onTagVoted: onTagVoted,
      ),
    );
  }

  @override
  _EHTagBottomSheetState createState() => _EHTagBottomSheetState();
}

class _EHTagBottomSheetState extends State<EHTagBottomSheet> with EHTagVoteLogicMixin<EHTagBottomSheet> {
  final ScrollController scrollController = ScrollController();

  @override
  TagData get tagData => widget.tagData;

  @override
  int get gid => widget.gid;

  @override
  String get token => widget.token;

  @override
  String get apikey => widget.apikey;

  @override
  EHTagVoteStatus? get voteStatus => widget.voteStatus;

  @override
  OnTagVoted? get onTagVoted => widget.onTagVoted;

  @override
  void initState() {
    super.initState();
    initTagVoteState();
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EHTagDialogHeader(tagData: tagData),
            if (tagData.tagName != null)
              Flexible(child: EHTagDialogInfo(tagData: tagData, maxHeight: MediaQuery.of(context).size.height * 0.4, scrollController: scrollController)),
            const Divider(height: 1),
            EHTagDialogMobileActions(
              currentVote: currentVote,
              voteUpState: voteUpState,
              voteDownState: voteDownState,
              addWatchedTagState: addWatchedTagState,
              addHiddenTagState: addHiddenTagState,
              tagInfo: findOnlineTag(),
              onVoteUp: () => vote(isVotingUp: true),
              onVoteDown: () => vote(isVotingUp: false),
              onFollow: () {
                ({int tagSetNo, bool watched, bool hidden})? info = findOnlineTag();
                if (info != null) {
                  showTagEditDialog(tagSetNo: info.tagSetNo);
                } else {
                  handleAddTagToSet(watch: true);
                }
              },
              onHide: () {
                ({int tagSetNo, bool watched, bool hidden})? info = findOnlineTag();
                if (info != null) {
                  showTagEditDialog(tagSetNo: info.tagSetNo);
                } else {
                  handleAddTagToSet(watch: false);
                }
              },
              onGotoTagSets: gotoTagSets,
            ),
          ],
        ),
      ),
    );
  }
}
