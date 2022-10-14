import 'dart:ui';

import 'package:jhentai/src/consts/locale_consts.dart';

Locale localeCode2Locale(String localeCode) {
  List<String> parts = localeCode.split('_');
  if (parts.length == 1) {
    return Locale(parts[0]);
  }
  if (parts.length == 2) {
    return Locale(parts[0], parts[1]);
  }
  return Locale(parts[0], parts[2]);
}

Locale computeDefaultLocale(Locale windowLocale) {
  /// same languageCode and countryCode
  if (LocaleConsts.localeCode2Description.containsKey(windowLocale.toString())) {
    return windowLocale;
  }

  List<String> localeParts = windowLocale.toString().split('_');

  /// same language code & country code
  for (String key in LocaleConsts.localeCode2Description.keys) {
    List<String> keyParts = key.split('_');

    if (localeParts.length >= 3 && keyParts[0] == localeParts[0] && keyParts[1] == localeParts[2]) {
      return localeCode2Locale(key);
    }
  }

  /// same language code & country code
  for (String key in LocaleConsts.localeCode2Description.keys) {
    List<String> keyParts = key.split('_');

    if (localeParts.length >= 2 && keyParts[0] == localeParts[0] && keyParts[1] == localeParts[1]) {
      return localeCode2Locale(key);
    }
  }

  /// same language code
  for (String key in LocaleConsts.localeCode2Description.keys) {
    List<String> keyParts = key.split('_');

    if (localeParts.isNotEmpty && keyParts[0] == localeParts[0]) {
      return localeCode2Locale(key);
    }
  }

  /// fallback
  return const Locale('en', 'US');
}
