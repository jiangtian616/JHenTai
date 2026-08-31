import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

/// Scrollable action list for the mobile tag bottom sheet.
/// Common actions (vote / follow / hide) are visible by default; management
/// actions (tag sets) are revealed by swiping up inside this list.
class EHTagDialogMobileActions extends StatelessWidget {
  final bool? currentVote;
  final LoadingState voteUpState;
  final LoadingState voteDownState;
  final LoadingState addWatchedTagState;
  final LoadingState addHiddenTagState;
  final ({int tagSetNo, bool watched, bool hidden})? tagInfo;

  final VoidCallback onVoteUp;
  final VoidCallback onVoteDown;
  final VoidCallback onFollow;
  final VoidCallback onHide;
  final VoidCallback onGotoTagSets;

  const EHTagDialogMobileActions({
    Key? key,
    required this.currentVote,
    required this.voteUpState,
    required this.voteDownState,
    required this.addWatchedTagState,
    required this.addHiddenTagState,
    required this.tagInfo,
    required this.onVoteUp,
    required this.onVoteDown,
    required this.onFollow,
    required this.onHide,
    required this.onGotoTagSets,
  }) : super(key: key);

  /// Number of common actions always visible without scrolling (vote up / down, follow, hide).
  static const int _commonActionCount = 4;

  @override
  Widget build(BuildContext context) {
    // The visible height is capped slightly below the full height of the common actions,
    // so the last visible tile is clipped by the fade and hints at more content below.
    const double visibleHeight = _commonActionCount * 48.0 - 12;

    return ShaderMask(
      // Bottom edge fades out to hint that more actions can be revealed by swiping up.
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, 0.8, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: visibleHeight),
        child: _buildList(context),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: 8),
      children: [
        _ActionTile(
          activeIcon: Icons.thumb_up,
          inactiveIcon: Icons.thumb_up_outlined,
          label: 'tagActionAccurate'.tr,
          active: currentVote == true,
          state: voteUpState,
          onTap: onVoteUp,
        ),
        _ActionTile(
          activeIcon: Icons.thumb_down,
          inactiveIcon: Icons.thumb_down_outlined,
          label: 'tagActionInaccurate'.tr,
          active: currentVote == false,
          state: voteDownState,
          onTap: onVoteDown,
        ),
        // A tag can only be in one state on EH: once watched, the hide action is
        // redundant (and vice versa), so only show the inactive-state action.
        if (tagInfo?.hidden != true)
          _ActionTile(
            activeIcon: Icons.favorite,
            inactiveIcon: Icons.favorite_border,
            label: 'tagActionFollow'.tr,
            active: tagInfo?.watched == true,
            state: addWatchedTagState,
            subtitle: tagInfo?.watched == true ? '${'watched'.tr} · #${tagInfo!.tagSetNo}' : null,
            onTap: onFollow,
          ),
        if (tagInfo?.watched != true)
          _ActionTile(
            activeIcon: Icons.visibility_off,
            inactiveIcon: Icons.visibility_off_outlined,
            label: 'tagActionHide'.tr,
            active: tagInfo?.hidden == true,
            state: addHiddenTagState,
            subtitle: tagInfo?.hidden == true ? '${'hidden'.tr} · #${tagInfo!.tagSetNo}' : null,
            onTap: onHide,
          ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.settings_outlined),
          title: Text('tagActionTagSets'.tr),
          onTap: onGotoTagSets,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool active;
  final LoadingState state;
  final String? subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.active,
    required this.state,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color color = active ? UIConfig.tagDialogLikedButtonColor(context) : UIConfig.tagDialogButtonColor(context);

    Widget? trailing;
    if (state == LoadingState.loading) {
      trailing = const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2));
    } else if (active) {
      trailing = Icon(Icons.check, size: 18, color: UIConfig.tagDialogLikedButtonColor(context));
    }

    return ListTile(
      dense: true,
      leading: Icon(active ? activeIcon : inactiveIcon, color: color),
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
