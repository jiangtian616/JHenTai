import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// A compact, black-and-white liquid-glass setting control.
///
/// [BackdropFilter] blurs the live content underneath the switch; translucent
/// gradients and two distinct specular highlights make the effect remain
/// visible even over the deliberately calm Settings background.
class EHLiquidGlassSwitch extends StatelessWidget {
  const EHLiquidGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool enabled = onChanged != null;
    final Color glassWhite = Colors.white.withValues(
      alpha: enabled ? 0.22 : 0.10,
    );
    final Color glassBlack = Colors.black.withValues(
      alpha: enabled ? 0.42 : 0.18,
    );
    final BorderRadius radius = BorderRadius.circular(14);

    return Semantics(
      toggled: value,
      enabled: enabled,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: SizedBox(
            // Intentionally flatter and longer than CupertinoSwitch's 51x31.
            width: 68,
            height: 28,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: enabled ? 0.28 : 0.10,
                    ),
                    blurRadius: value ? 12 : 8,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.32),
                    blurRadius: 2,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors:
                                value
                                    ? [
                                      glassWhite.withValues(
                                        alpha: glassWhite.a + 0.24,
                                      ),
                                      glassWhite,
                                      glassBlack.withValues(
                                        alpha: glassBlack.a * 0.45,
                                      ),
                                    ]
                                    : [
                                      glassWhite,
                                      glassBlack.withValues(
                                        alpha: glassBlack.a * 0.75,
                                      ),
                                    ],
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(
                              alpha: enabled ? 0.42 : 0.18,
                            ),
                            width: 0.8,
                          ),
                        ),
                      ),
                    ),
                    // A thin reflected band makes the glass legible over a
                    // plain background, where a blur alone has nothing to show.
                    Positioned(
                      top: 1,
                      left: 6,
                      right: 6,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(
                                alpha: enabled ? 0.24 : 0.10,
                              ),
                              Colors.white.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      alignment:
                          value ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 24,
                        height: 24,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors:
                                value
                                    ? [
                                      Colors.black.withValues(alpha: 0.90),
                                      Colors.black.withValues(alpha: 0.64),
                                    ]
                                    : [
                                      Colors.white.withValues(alpha: 0.96),
                                      Colors.white.withValues(alpha: 0.66),
                                    ],
                          ),
                          border: Border.all(
                            color:
                                value
                                    ? Colors.white.withValues(alpha: 0.24)
                                    : Colors.white.withValues(alpha: 0.84),
                            width: 0.7,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.32),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// [SwitchListTile] that renders a Cupertino-style switch row while the Apple
/// visual style is enabled, and the normal Material row otherwise.
class EHAppleSwitchListTile extends StatelessWidget {
  const EHAppleSwitchListTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.contentPadding,
    this.dense = false,
    this.enabled = true,
  });

  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final EdgeInsetsGeometry? contentPadding;
  final bool dense;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!ThemeConfig.isApple) {
      return SwitchListTile(
        title: title,
        subtitle: subtitle,
        value: value,
        onChanged: enabled ? onChanged : null,
        contentPadding: contentPadding,
        dense: dense,
      );
    }

    final Widget switchWidget = GlassSwitch(
      value: value,
      onChanged: enabled && onChanged != null ? onChanged! : (_) {},
      // Classic iOS switch: white thumb on a green-on / gray-off track.
      activeColor: CupertinoColors.systemGreen,
      inactiveColor: CupertinoColors.systemGrey,
      thumbColor: CupertinoColors.white,
    );

    return CupertinoListTile(
      title: title,
      subtitle: subtitle,
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      trailing: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: IgnorePointer(child: switchWidget),
      ),
    );
  }
}

/// [Switch] that renders an iOS 26 liquid-glass [GlassSwitch] while the Apple
/// visual style is enabled, and the normal Material switch otherwise.
class EHAppleSwitch extends StatelessWidget {
  const EHAppleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassSwitch(
        value: value,
        onChanged: onChanged ?? (_) {},
        // Classic iOS switch: white thumb on a green-on / gray-off track.
        activeColor: CupertinoColors.systemGreen,
        inactiveColor: CupertinoColors.systemGrey,
        thumbColor: CupertinoColors.white,
      );
    }
    return Switch(value: value, onChanged: onChanged);
  }
}

/// [Slider] that renders an iOS 26 liquid-glass [GlassSlider] while the Apple
/// visual style is enabled.
class EHAppleSlider extends StatelessWidget {
  const EHAppleSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.label,
    this.divisions,
    this.thumbColor,
    this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String? label;
  final int? divisions;
  final Color? thumbColor;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassSlider(
        value: value,
        min: min,
        max: max,
        label: label,
        divisions: divisions,
        thumbColor: thumbColor ?? CupertinoColors.white,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      );
    }
    return Slider(
      value: value,
      min: min,
      max: max,
      label: label,
      divisions: divisions,
      thumbColor: thumbColor,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}

/// [TextField] that renders an iOS 26 liquid-glass [GlassTextField] while the
/// Apple visual style is enabled.
class EHAppleTextField extends StatelessWidget {
  const EHAppleTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textInputAction,
    this.inputFormatters,
    this.onSubmitted,
    this.obscureText = false,
    this.enabled = true,
    this.minLines,
    this.maxLines = 1,
    this.maxLength,
    this.autofocus = false,
    this.onTapOutside,
    this.onTap,
    this.decoration,
    this.style,
    this.placeholderStyle,
    this.onChanged,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextAlign textAlign;

  /// Only honoured by the Material branch — the glass field has no
  /// vertical-alignment knob and centres its content itself.
  final TextAlignVertical? textAlignVertical;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool enabled;
  final int? minLines;
  final int? maxLines;
  final int? maxLength;
  final bool autofocus;
  final TapRegionCallback? onTapOutside;

  /// Only honoured by the Material branch — the glass field has no tap hook.
  final VoidCallback? onTap;
  final InputDecoration? decoration;
  final TextStyle? style;
  final TextStyle? placeholderStyle;
  final ValueChanged<String>? onChanged;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return GlassTextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        obscureText: obscureText,
        enabled: enabled,
        minLines: minLines,
        maxLines: maxLines ?? 1,
        maxLength: maxLength,
        autofocus: autofocus,
        onTapOutside: onTapOutside,
        textStyle: style,
        placeholderStyle: placeholderStyle,
        onChanged: onChanged,
        placeholder: decoration?.labelText ?? decoration?.hintText,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      );
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      enabled: enabled,
      minLines: minLines,
      maxLines: maxLines,
      maxLength: maxLength,
      autofocus: autofocus,
      onTapOutside: onTapOutside,
      onTap: onTap,
      decoration: decoration,
      style: style,
      onChanged: onChanged,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
    );
  }
}

/// [GlassMenu] that strips the ambient scrollbars from the popup list.
///
/// The app installs a scroll-bar-bearing [ScrollBehavior] at the root; the
/// glass menu's internal scrollable inherits it and shows a Material scrollbar
/// next to the liquid menu. Wrapping with a no-scrollbar [ScrollConfiguration]
/// keeps the popup clean while preserving every [GlassMenu] behaviour.
class EHGlassMenu extends StatelessWidget {
  const EHGlassMenu({
    super.key,
    this.trigger,
    this.triggerBuilder,
    required this.items,
    this.menuWidth = 200,
    this.menuAlignment,
    this.menuBorderRadius,
    this.itemBorderRadius,
    this.menuHeight,
    this.selectionColor,
    this.glowColor,
    this.glowRadius,
    this.glowIntensity,
    this.onClose,
    this.controller,
  });

  final Widget? trigger;
  final Widget Function(BuildContext, VoidCallback)? triggerBuilder;
  final List<Widget> items;
  final double menuWidth;
  final GlassMenuAlignment? menuAlignment;
  final double? menuBorderRadius;
  final double? itemBorderRadius;
  final double? menuHeight;
  final Color? selectionColor;
  final Color? glowColor;
  final double? glowRadius;
  final double? glowIntensity;
  final VoidCallback? onClose;
  final GlassMenuController? controller;

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: GlassMenu(
        trigger: trigger,
        triggerBuilder: triggerBuilder,
        items: items,
        menuWidth: menuWidth,
        menuAlignment: menuAlignment,
        menuBorderRadius: menuBorderRadius ?? 32.0,
        itemBorderRadius: itemBorderRadius ?? 24.0,
        menuHeight: menuHeight,
        selectionColor: selectionColor ?? const Color(0x3DFFFFFF),
        glowColor: glowColor,
        glowRadius: glowRadius ?? 0.6,
        glowIntensity: glowIntensity ?? 0.0,
        onClose: onClose,
        controller: controller,
      ),
    );
  }
}

/// [Checkbox] that renders an iOS 26 liquid-glass checkbox while the Apple
/// visual style is enabled, and the normal Material checkbox otherwise.
///
/// iOS has no native checkbox; a small glass rounded square with a check mark
/// is the closest idiom.
class EHAppleCheckbox extends StatelessWidget {
  const EHAppleCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  final bool? value;
  final ValueChanged<bool?>? onChanged;

  /// Material-only: the glass checkbox has its own primary-coloured check.
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    if (!ThemeConfig.isApple) {
      return Checkbox(value: value, onChanged: onChanged, activeColor: activeColor);
    }
    final bool checked = value ?? false;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      child: GlassContainer(
        width: 24,
        height: 24,
        shape: const LiquidRoundedRectangle(borderRadius: 6),
        child: checked
            ? Icon(
                CupertinoIcons.check_mark,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
    );
  }
}

/// [IconButton] that renders an iOS 26 liquid-glass [GlassIconButton] while the
/// Apple visual style is enabled, and the normal Material icon button
/// otherwise.
///
/// The glass button has no Material-equivalent knobs for tooltip / icon colour
/// / layout, so those are approximated: [tooltip] becomes a [Tooltip], [color]
/// is applied to the icon itself (GlassIconButton hard-codes its own icon
/// colour, so the tint must be nearer to the icon than its internal
/// [IconTheme]), [size] sets the glass button diameter and [glowColor] drives
/// its selection halo. Padding, visual density, constraints and the
/// selected/toggle pair are Material-only and are dropped in Apple mode.
class EHAppleIconButton extends StatelessWidget {
  const EHAppleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.onLongPress,
    this.tooltip,
    this.iconSize,
    this.color,
    this.size,
    this.glowColor,
    this.glowRadius,
    this.padding,
    this.visualDensity,
    this.constraints,
    this.selectedIcon,
    this.isSelected,
    this.splashColor,
    this.highlightColor,
    this.hoverColor,
    this.mouseCursor,
    this.focusNode,
    this.autofocus = false,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final String? tooltip;
  final double? iconSize;
  final Color? color;

  /// Glass-button diameter in Apple mode (Material mode ignores it — use
  /// [constraints] there). Falls back to a square tight [constraints] box.
  /// All glass circular buttons share this size for a uniform look.
  static const double defaultSize = 40;
  final double? size;
  final Color? glowColor;

  /// Restrained glass halo radius — GlassIconButton's default (20) reads as a
  /// harsh edge glow; keep it subtle so buttons stay calm.
  final double? glowRadius;
  final EdgeInsetsGeometry? padding;
  final VisualDensity? visualDensity;
  final BoxConstraints? constraints;
  final Widget? selectedIcon;
  final bool? isSelected;
  final Color? splashColor;
  final Color? highlightColor;
  final Color? hoverColor;
  final MouseCursor? mouseCursor;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Picks a square side from an explicit tight [constraints] box, otherwise
  /// the glass default.
  double get _glassSize {
    final BoxConstraints? c = constraints;
    if (c != null && c.hasBoundedWidth && c.hasBoundedHeight) {
      final double side = c.maxWidth == c.maxHeight ? c.maxWidth : 0;
      if (side > 0) {
        return side;
      }
    }
    return size ?? defaultSize;
  }

  @override
  Widget build(BuildContext context) {
    final Widget material = IconButton(
      icon: icon,
      onPressed: onPressed,
      onLongPress: onLongPress,
      tooltip: tooltip,
      iconSize: iconSize,
      color: color,
      padding: padding,
      visualDensity: visualDensity,
      constraints: constraints,
      selectedIcon: selectedIcon,
      isSelected: isSelected,
      splashColor: splashColor,
      highlightColor: highlightColor,
      hoverColor: hoverColor,
      mouseCursor: mouseCursor,
      focusNode: focusNode,
      autofocus: autofocus,
    );
    if (!ThemeConfig.isApple) {
      return material;
    }

    final double buttonSize = _glassSize;
    // GlassIconButton wraps the icon in its own IconTheme (label colour), so
    // the tint must be applied on the icon itself to win.
    final Widget tintedIcon = color == null
        ? icon
        : IconTheme(
            data: IconThemeData(color: color, size: iconSize),
            child: icon,
          );
    // Fixed square box so an AppBar leading / Row with tight non-square
    // constraints cannot squash the glass circle into an oval.
    Widget glass = SizedBox(
      width: buttonSize,
      height: buttonSize,
      child: Center(
        child: GlassIconButton(
          icon: tintedIcon,
          onPressed: onPressed,
          iconSize: iconSize,
          size: buttonSize,
          shape: GlassIconButtonShape.circle,
          glowColor: glowColor,
          glowRadius: glowRadius ?? 10,
          focusNode: focusNode,
          autofocus: autofocus,
        ),
      ),
    );
    if (tooltip != null) {
      glass = Tooltip(message: tooltip!, child: glass);
    }
    return glass;
  }
}
