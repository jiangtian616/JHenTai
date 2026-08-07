import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';

import 'desktop_layout_page_logic.dart';
import 'desktop_layout_page_state.dart';

class DesktopHomePage extends StatelessWidget {
  final DesktopLayoutPageLogic logic = Get.find();
  final DesktopLayoutPageState state = Get.find<DesktopLayoutPageLogic>().state;

  DesktopHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<DesktopLayoutPageLogic>(
      id: logic.leftColumnId,
      builder: (_) => Stack(
        children: state.icons
            .where((icon) => icon.shouldRender)
            .mapIndexed(
              (index, icon) => _DesktopTabLayer(
                active: state.selectedTabOrder == index,
                child: icon.page.call(),
              ),
            )
            .toList(),
      ),
    );
  }
}

/// Keeps desktop sections alive like the old [Offstage] implementation, while
/// giving each section a short, macOS-style cross-fade when the icon rail
/// changes selection.
class _DesktopTabLayer extends StatefulWidget {
  const _DesktopTabLayer({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<_DesktopTabLayer> createState() => _DesktopTabLayerState();
}

class _DesktopTabLayerState extends State<_DesktopTabLayer> {
  static const Duration _transitionDuration = Duration(milliseconds: 220);
  bool _visible = false;
  late bool _keepTicking = widget.active;

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _visible = true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _DesktopTabLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        setState(() {
          _keepTicking = true;
          _visible = true;
        });
      } else {
        setState(() => _visible = false);
        Future<void>.delayed(_transitionDuration, () {
          if (mounted && !widget.active) {
            setState(() => _keepTicking = false);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ThemeConfig.isApple) {
      return Offstage(offstage: !widget.active, child: widget.child);
    }
    return IgnorePointer(
      ignoring: !widget.active,
      child: TickerMode(
        enabled: _keepTicking,
        child: AnimatedOpacity(
          duration: _transitionDuration,
          curve: Curves.easeOutCubic,
          opacity: _visible ? 1 : 0,
          child: widget.child,
        ),
      ),
    );
  }
}
