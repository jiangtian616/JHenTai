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

  /// same languageCode
  for (String key in LocaleConsts.localeCode2Description.keys) {
    if (key.split('_')[0] == windowLocale.toString().split('_')[0]) {
      return localeCode2Locale(key);
    }
  }

  return const Locale('en', 'US');
}
