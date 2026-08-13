import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

/// Material button families and the [CupertinoButton] constructor that mirrors
/// each one while the Apple visual style is enabled.
enum _EHAppleButtonKind {
  /// [TextButton] → [CupertinoButton] (plain, no background).
  text,

  /// [ElevatedButton] → [CupertinoButton.filled].
  elevated,

  /// [FilledButton] → [CupertinoButton.filled].
  filled,

  /// [FilledButton.tonal] → [CupertinoButton.tinted].
  tonal,

  /// [OutlinedButton] → [CupertinoButton.tinted].
  outlined,
}

/// Rounded-corner shape shared by the EHApple* label buttons. [GlassButton]
/// defaults to [LiquidOval], which stretches into a flat ellipse whenever the
/// label is wider than it is tall (e.g. "No Comments"). A squircle keeps the
/// button looking like a button regardless of label length.
const LiquidShape _glassLabelButtonShape =
    LiquidRoundedSuperellipse(borderRadius: 14);

/// Default inner padding for filled/tonal/outlined glass label buttons that do
/// not carry an explicit [ButtonStyle.minimumSize]. Material label buttons
/// ship with a 64x40 minimum + padding; the glass branch skips the minimum so
/// *text* buttons size to their content, but without this padding a filled
/// label would then hug its text (e.g. a ~28x20 "view" pill in a LAN row).
const EdgeInsets _glassLabelButtonPadding =
    EdgeInsets.symmetric(horizontal: 16, vertical: 10);

/// Builds the Cupertino branch shared by all the [EHApple*Button] wrappers.
///
/// Builds the iOS 26 liquid-glass branch shared by the [EHApple*Button]
/// wrappers, using [liquid_glass_widgets].
///
/// The glass surface itself (refraction, specular, blur) comes from the
/// package renderer + [GlassThemeData], so only the Material [ButtonStyle]
/// fields that size the button — minimum/maximum size — are translated;
/// colour/padding/elevation have no equivalent on a glass button. Material's
/// default 64x40 minimum is skipped so text buttons size to their content.
Widget _buildGlassButton({
  required _EHAppleButtonKind kind,
  required VoidCallback? onPressed,
  VoidCallback? onLongPress,
  required ButtonStyle? style,
  bool autofocus = false,
  FocusNode? focusNode,
  required Widget child,
}) {
  final bool enabled = onPressed != null || onLongPress != null;
  // GlassButton has no onLongPress and requires a non-null onTap; the
  // enabled flag carries the disabled state.
  final VoidCallback onTap = enabled && onPressed != null ? onPressed : () {};

  final Size? minimumSize = style?.minimumSize?.resolve(const <WidgetState>{});
  final Size? maximumSize = style?.maximumSize?.resolve(const <WidgetState>{});
  final Size? effectiveMinimumSize = minimumSize == const Size(64, 40)
      ? null
      : minimumSize;

  // Toolbar icon buttons (originally transparent ElevatedButton/FilledButton)
  // should use the standard glass fill like GlassIconButton, not the heavier
  // prominent surface reserved for real primary actions.
  final Color? background =
      style?.backgroundColor?.resolve(const <WidgetState>{});
  final bool transparentBackground =
      background != null && background.a == 0;

  final GlassButtonStyle glassStyle = switch (kind) {
    _EHAppleButtonKind.text => GlassButtonStyle.transparent,
    _EHAppleButtonKind.elevated || _EHAppleButtonKind.filled =>
      transparentBackground
          ? GlassButtonStyle.filled
          : GlassButtonStyle.prominent,
    _EHAppleButtonKind.tonal || _EHAppleButtonKind.outlined =>
      GlassButtonStyle.filled,
  };

  // Filled/tonal/outlined label buttons get the default padding only when
  // they size themselves (no explicit minimumSize). Text buttons stay
  // content-sized, and explicitly sized or transparent toolbar/icon buttons
  // keep their exact size.
  final bool isLabelButton = kind != _EHAppleButtonKind.text;
  final Widget labelChild =
      !isLabelButton || effectiveMinimumSize != null || transparentBackground
      ? child
      : Padding(padding: _glassLabelButtonPadding, child: child);

  final Widget button = GlassButton.custom(
    child: labelChild,
    onTap: onTap,
    width: effectiveMinimumSize?.width,
    height: effectiveMinimumSize?.height,
    shape: _glassLabelButtonShape,
    style: glassStyle,
    enabled: enabled,
    autofocus: autofocus,
    focusNode: focusNode,
  );

  if (maximumSize != null) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maximumSize.width,
        maxHeight: maximumSize.height,
      ),
      child: button,
    );
  }
  return button;
}

/// Shared implementation behind the [EHApple*Button] wrappers: renders the
/// matching iOS 26 liquid-glass button while the Apple visual style is
/// enabled, and the original Material widget otherwise, so both paths keep
/// their look.
class _EHAppleButtonBase extends StatelessWidget {
  const _EHAppleButtonBase({
    super.key,
    required this.kind,
    required this.onPressed,
    this.onLongPress,
    this.style,
    this.focusNode,
    this.autofocus = false,
    this.icon,
    this.label,
    this.iconAlignment,
    this.child,
  });

  final _EHAppleButtonKind kind;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final ButtonStyle? style;
  final FocusNode? focusNode;
  final bool autofocus;
  final Widget? icon;
  final Widget? label;
  final IconAlignment? iconAlignment;
  final Widget? child;

  bool get _isIcon => icon != null && label != null;

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return _buildGlassButton(
        kind: kind,
        onPressed: onPressed,
        onLongPress: onLongPress,
        style: style,
        autofocus: autofocus,
        focusNode: focusNode,
        child: _isIcon ? _buildIconRow() : (child ?? const SizedBox.shrink()),
      );
    }
    return _buildMaterialButton(context);
  }

  Widget _buildIconRow() {
    final bool end = iconAlignment == IconAlignment.end;
    final Widget leading = end ? label! : icon!;
    final Widget trailing = end ? icon! : label!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [leading, const SizedBox(width: 8), trailing],
    );
  }

  Widget _buildMaterialButton(BuildContext context) {
    if (_isIcon) {
      return switch (kind) {
        _EHAppleButtonKind.text => TextButton.icon(
            onPressed: onPressed,
            onLongPress: onLongPress,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            icon: icon,
            label: label!,
            iconAlignment: iconAlignment ?? IconAlignment.start,
          ),
        _EHAppleButtonKind.elevated => ElevatedButton.icon(
            onPressed: onPressed,
            onLongPress: onLongPress,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            icon: icon,
            label: label!,
            iconAlignment: iconAlignment ?? IconAlignment.start,
          ),
        _EHAppleButtonKind.filled => FilledButton.icon(
            onPressed: onPressed,
            onLongPress: onLongPress,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            icon: icon,
            label: label!,
            iconAlignment: iconAlignment ?? IconAlignment.start,
          ),
        _EHAppleButtonKind.tonal => FilledButton.tonalIcon(
            onPressed: onPressed,
            onLongPress: onLongPress,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            icon: icon,
            label: label!,
            iconAlignment: iconAlignment ?? IconAlignment.start,
          ),
        _EHAppleButtonKind.outlined => OutlinedButton.icon(
            onPressed: onPressed,
            onLongPress: onLongPress,
            style: style,
            focusNode: focusNode,
            autofocus: autofocus,
            icon: icon,
            label: label!,
            iconAlignment: iconAlignment ?? IconAlignment.start,
          ),
      };
    }
    return switch (kind) {
      _EHAppleButtonKind.text => TextButton(
          onPressed: onPressed,
          onLongPress: onLongPress,
          style: style,
          focusNode: focusNode,
          autofocus: autofocus,
          child: child ?? const SizedBox.shrink(),
        ),
      _EHAppleButtonKind.elevated => ElevatedButton(
          onPressed: onPressed,
          onLongPress: onLongPress,
          style: style,
          focusNode: focusNode,
          autofocus: autofocus,
          child: child ?? const SizedBox.shrink(),
        ),
      _EHAppleButtonKind.filled => FilledButton(
          onPressed: onPressed,
          onLongPress: onLongPress,
          style: style,
          focusNode: focusNode,
          autofocus: autofocus,
          child: child ?? const SizedBox.shrink(),
        ),
      _EHAppleButtonKind.tonal => FilledButton.tonal(
          onPressed: onPressed,
          onLongPress: onLongPress,
          style: style,
          focusNode: focusNode,
          autofocus: autofocus,
          child: child ?? const SizedBox.shrink(),
        ),
      _EHAppleButtonKind.outlined => OutlinedButton(
          onPressed: onPressed,
          onLongPress: onLongPress,
          style: style,
          focusNode: focusNode,
          autofocus: autofocus,
          child: child ?? const SizedBox.shrink(),
        ),
    };
  }
}

/// [TextButton] that renders a Cupertino text button while the Apple visual
/// style is enabled, and the normal Material button otherwise.
class EHAppleTextButton extends _EHAppleButtonBase {
  const EHAppleTextButton({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.child,
  }) : super(kind: _EHAppleButtonKind.text);

  const EHAppleTextButton.icon({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.icon,
    super.label,
    super.iconAlignment,
  }) : super(kind: _EHAppleButtonKind.text);
}

/// [ElevatedButton] that renders a filled Cupertino button while the Apple
/// visual style is enabled, and the normal Material button otherwise.
class EHAppleElevatedButton extends _EHAppleButtonBase {
  const EHAppleElevatedButton({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.child,
  }) : super(kind: _EHAppleButtonKind.elevated);

  const EHAppleElevatedButton.icon({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.icon,
    super.label,
    super.iconAlignment,
  }) : super(kind: _EHAppleButtonKind.elevated);
}

/// [FilledButton] that renders a filled Cupertino button while the Apple visual
/// style is enabled, and the normal Material button otherwise.
class EHAppleFilledButton extends _EHAppleButtonBase {
  const EHAppleFilledButton({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.child,
  }) : super(kind: _EHAppleButtonKind.filled);

  const EHAppleFilledButton.icon({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.icon,
    super.label,
    super.iconAlignment,
  }) : super(kind: _EHAppleButtonKind.filled);

  /// [FilledButton.tonal] that renders a tinted Cupertino button while the
  /// Apple visual style is enabled.
  const EHAppleFilledButton.tonal({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.child,
  }) : super(kind: _EHAppleButtonKind.tonal);
}

/// [OutlinedButton] that renders a tinted Cupertino button while the Apple
/// visual style is enabled, and the normal Material button otherwise.
class EHAppleOutlinedButton extends _EHAppleButtonBase {
  const EHAppleOutlinedButton({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.child,
  }) : super(kind: _EHAppleButtonKind.outlined);

  const EHAppleOutlinedButton.icon({
    super.key,
    super.onPressed,
    super.onLongPress,
    super.style,
    super.focusNode,
    super.autofocus = false,
    super.icon,
    super.label,
    super.iconAlignment,
  }) : super(kind: _EHAppleButtonKind.outlined);
}
