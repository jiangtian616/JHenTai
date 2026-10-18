import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class EHTagDialogDesktopActions extends StatelessWidget {
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

  const EHTagDialogDesktopActions({
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _ActionButton(
            activeIcon: Icons.thumb_up,
            inactiveIcon: Icons.thumb_up_outlined,
            label: 'tagActionAccurate'.tr,
            active: currentVote == true,
            state: voteUpState,
            tooltip: 'tagActionVoteUpTooltip'.tr,
            onTap: onVoteUp,
          ),
          _ActionButton(
            activeIcon: Icons.thumb_down,
            inactiveIcon: Icons.thumb_down_outlined,
            label: 'tagActionInaccurate'.tr,
            active: currentVote == false,
            state: voteDownState,
            tooltip: 'tagActionVoteDownTooltip'.tr,
            onTap: onVoteDown,
          ),
          // A tag can only be in one state on EH: once watched, the hide button is
          // redundant (and vice versa), so only show the inactive-state action.
          if (tagInfo?.hidden != true)
            _ActionButton(
              activeIcon: Icons.favorite,
              inactiveIcon: Icons.favorite_border,
              label: 'tagActionFollow'.tr,
              active: tagInfo?.watched == true,
              state: addWatchedTagState,
              tooltip: tagInfo?.watched == true ? '${'watched'.tr} · #${tagInfo!.tagSetNo}' : 'tagActionFollowHint'.tr,
              onTap: onFollow,
            ),
          if (tagInfo?.watched != true)
            _ActionButton(
              activeIcon: Icons.visibility_off,
              inactiveIcon: Icons.visibility_off_outlined,
              label: 'tagActionHide'.tr,
              active: tagInfo?.hidden == true,
              state: addHiddenTagState,
              tooltip: tagInfo?.hidden == true ? '${'hidden'.tr} · #${tagInfo!.tagSetNo}' : 'tagActionHideHint'.tr,
              onTap: onHide,
            ),
          _ActionButton(
            activeIcon: Icons.settings,
            inactiveIcon: Icons.settings_outlined,
            label: 'tagActionTagSets'.tr,
            active: false,
            state: LoadingState.idle,
            tooltip: 'tagActionTagSetsHint'.tr,
            onTap: onGotoTagSets,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool active;
  final LoadingState state;
  final String? tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.active,
    required this.state,
    this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color color = active ? UIConfig.tagDialogLikedButtonColor(context) : UIConfig.tagDialogButtonColor(context);

    Widget icon;
    if (state == LoadingState.loading) {
      icon = const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      icon = _PulseIcon(
        trigger: state == LoadingState.success,
        child: Icon(active ? activeIcon : inactiveIcon, size: 20),
      );
    }

    Widget button = TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

class _PulseIcon extends StatefulWidget {
  final bool trigger;
  final Widget child;

  const _PulseIcon({required this.trigger, required this.child});

  @override
  State<_PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<_PulseIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

  @override
  void didUpdateWidget(_PulseIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
        TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
      ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: widget.child,
    );
  }
}
