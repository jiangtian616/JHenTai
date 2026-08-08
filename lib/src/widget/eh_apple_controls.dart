import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jhentai/src/config/theme_config.dart';

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

    return CupertinoListTile(
      title: title,
      subtitle: subtitle,
      onTap: enabled && onChanged != null ? () => onChanged!(!value) : null,
      trailing: CupertinoSwitch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

/// [Switch] that renders a Cupertino switch while the Apple visual style is
/// enabled.
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
      return CupertinoSwitch(value: value, onChanged: onChanged);
    }
    return Switch(value: value, onChanged: onChanged);
  }
}

/// [Slider] that renders a Cupertino slider while the Apple visual style is
/// enabled.
class EHAppleSlider extends StatelessWidget {
  const EHAppleSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 1,
    this.label,
    this.divisions,
    this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final String? label;
  final int? divisions;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return CupertinoSlider(
        value: value,
        min: min,
        max: max,
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
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}

/// [TextField] that renders a Cupertino text field while the Apple visual
/// style is enabled.
class EHAppleTextField extends StatelessWidget {
  const EHAppleTextField({
    super.key,
    this.controller,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    this.inputFormatters,
    this.onSubmitted,
    this.obscureText = false,
    this.enabled = true,
    this.decoration,
    this.style,
    this.onChanged,
    this.autocorrect = true,
    this.enableSuggestions = true,
  });

  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final TextAlign textAlign;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool obscureText;
  final bool enabled;
  final InputDecoration? decoration;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final bool autocorrect;
  final bool enableSuggestions;

  @override
  Widget build(BuildContext context) {
    if (ThemeConfig.isApple) {
      return CupertinoTextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: textAlign,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        obscureText: obscureText,
        enabled: enabled,
        style: style,
        onChanged: onChanged,
        autocorrect: autocorrect,
        enableSuggestions: enableSuggestions,
        placeholder: decoration?.labelText ?? decoration?.hintText,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      );
    }
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textAlign: textAlign,
      inputFormatters: inputFormatters,
      onSubmitted: onSubmitted,
      obscureText: obscureText,
      enabled: enabled,
      decoration: decoration,
      style: style,
      onChanged: onChanged,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
    );
  }
}
