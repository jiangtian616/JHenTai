import 'package:flutter/cupertino.dart';

extension StringExtension on String {
  /// https://github.com/flutter/flutter/issues/61081
  String get breakWord {
    return Characters(this).join('\u{200B}');
  }

  String defaultIfEmpty(String defaultString) {
    return (isEmpty ? defaultString : this).breakWord;
  }
}
