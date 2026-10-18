import 'package:flutter/material.dart';
import 'package:jhentai/src/widget/eh_tag_dialog_desktop_actions.dart';

import '../database/database.dart';
import '../model/gallery_tag.dart';
import 'eh_tag_dialog_shared.dart';

/// Centered tag dialog for desktop / wide screens.
class EHTagDialog extends StatefulWidget {
  final TagData tagData;
  final int gid;
  final String token;
  final String apikey;
  final EHTagVoteStatus? voteStatus;
  final OnTagVoted? onTagVoted;

  const EHTagDialog({
    Key? key,
    required this.tagData,
    required this.gid,
    required this.token,
    required this.apikey,
    this.voteStatus,
    this.onTagVoted,
  }) : super(key: key);

  @override
  _EHTagDialogState createState() => _EHTagDialogState();
}

class _EHTagDialogState extends State<EHTagDialog> with EHTagVoteLogicMixin<EHTagDialog> {
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
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EHTagDialogHeader(tagData: tagData, showCloseButton: true),
            if (tagData.tagName != null) Flexible(child: EHTagDialogInfo(tagData: tagData, maxHeight: 300, scrollController: scrollController)),
            const Divider(height: 1),
            const SizedBox(height: 4),
            EHTagDialogDesktopActions(
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
