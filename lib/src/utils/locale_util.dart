import 'dart:ui';

Locale localeCode2Locale(String localeCode) {
  List<String> parts = localeCode.split('_');
  if (parts.length == 1) {
    return Locale(parts[0]);
  }
  return Locale(parts[0], parts[1]);
}
