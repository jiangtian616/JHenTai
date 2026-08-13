import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../extension/string_extension.dart';
import '../service/image_translation_service.dart';
import '../setting/image_translation_setting.dart';

/// Renders [text], automatically translating it on-device when the
/// auto-translate-gallery-text setting is active (Apple Live Text + Apple's own
/// translation). While a translation is pending, when the feature is off, or
/// when translation is unavailable, it falls back to the original text, so it
/// is safe to drop into any title call site.
///
/// Mirrors the common [Text]/[SelectableText] parameters so existing call sites
/// keep their styling; [breakWord] reproduces `.breakWord` on the rendered
/// string (translated or original), and [contextMenuBuilder] passes through the
/// custom selection menu used on the details page (only applied when provided,
/// so `SelectableText`'s own default menu is kept otherwise).
class EHTranslatedText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final int? minLines;
  final TextOverflow? overflow;
  final bool softWrap;
  final bool selectable;
  final bool breakWord;
  final TextScaler? textScaler;
  final String? semanticsLabel;
  final Widget Function(
      BuildContext context, EditableTextState editableTextState)? contextMenuBuilder;

  const EHTranslatedText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.minLines,
    this.overflow,
    this.softWrap = true,
    this.selectable = false,
    this.breakWord = false,
    this.textScaler,
    this.semanticsLabel,
    this.contextMenuBuilder,
  });

  @override
  State<EHTranslatedText> createState() => _EHTranslatedTextState();
}

class _EHTranslatedTextState extends State<EHTranslatedText> {
  String? _translated;
  late final Worker _settingWorker;

  @override
  void initState() {
    super.initState();
    // Re-evaluate already-visible titles when the feature is toggled.
    _settingWorker = ever(imageTranslationSetting.autoTranslateGalleryText,
        (_) {
      if (!mounted) return;
      setState(() => _translated = null);
      _translate();
    });
    _translate();
  }

  @override
  void didUpdateWidget(EHTranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _translated = null;
      _translate();
    }
  }

  @override
  void dispose() {
    _settingWorker.dispose();
    super.dispose();
  }

  Future<void> _translate() async {
    // Capture the text this call translates so a stale in-flight future from a
    // previous title cannot overwrite the current one.
    final String requested = widget.text;
    // Read the cache synchronously so an already-translated text shows
    // immediately instead of waiting on the in-flight future.
    final String? cached =
        imageTranslationService.galleryTextTranslationFor(requested);
    if (cached != null) {
      if (mounted && cached != requested) {
        setState(() => _translated = cached);
      }
      return;
    }
    final String result =
        await imageTranslationService.translateGalleryText(requested);
    if (mounted && requested == widget.text && result != requested) {
      setState(() => _translated = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String raw = _translated ?? widget.text;
    final String display = widget.breakWord ? raw.breakWord : raw;
    if (widget.selectable) {
      // Omit contextMenuBuilder when not provided so SelectableText keeps its
      // own default selection toolbar (this Flutter's SelectableText has no
      // overflow/softWrap parameters, so those are intentionally not passed).
      if (widget.contextMenuBuilder != null) {
        return SelectableText(
          display,
          style: widget.style,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          minLines: widget.minLines,
          textScaler: widget.textScaler,
          semanticsLabel: widget.semanticsLabel,
          contextMenuBuilder: widget.contextMenuBuilder,
        );
      }
      return SelectableText(
        display,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        textScaler: widget.textScaler,
        semanticsLabel: widget.semanticsLabel,
      );
    }
    return Text(
      display,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      softWrap: widget.softWrap,
      textScaler: widget.textScaler,
      semanticsLabel: widget.semanticsLabel,
    );
  }
}
