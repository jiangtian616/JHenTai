import 'dart:io';

import 'package:collection/collection.dart';
import 'package:jhentai/src/utils/string_uril.dart';

import 'log.dart';

class CookieUtil {
  static List<Cookie> parse2Cookies(String? cookiesString) {
    return callWithParamsUploadIfErrorOccurs(
      () {
        if (isEmptyOrNull(cookiesString)) {
          return <Cookie>[];
        }
        return cookiesString!.split(';').map((pair) {
          List<String> nameAndValue = pair.trim().split('=');
          if (nameAndValue.length < 2) {
            Log.error('parse2Cookies error: $cookiesString');
          }
          return Cookie(nameAndValue[0], nameAndValue[1]);
        }).toList();
      },
      params: cookiesString,
      defaultValue: [],
    );
  }

  static String parse2String(List<Cookie> cookies) {
    return cookies.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  static bool validateCookiesString(String? cookiesString) {
    if (cookiesString?.isEmpty ?? false) {
      return false;
    }
    RegExpMatch? match = RegExp(r'ipb_member_id=(\w+).*ipb_pass_hash=(\w+)').firstMatch(cookiesString!);
    String? ipbMemberId = match?.group(1);
    String? ipbPassHash = match?.group(2);
    return (ipbMemberId != null && ipbPassHash != null && ipbMemberId != '0' && ipbPassHash != '0');
  }

  static bool validateCookies(List<Cookie> cookies) {
    String? ipbMemberId = cookies.firstWhereOrNull((cookie) => cookie.name == 'ipb_member_id')?.value;
    String? ipbPassHash = cookies.firstWhereOrNull((cookie) => cookie.name == 'ipb_pass_hash')?.value;
    return (ipbMemberId != null && ipbPassHash != null && ipbMemberId != '0' && ipbPassHash != '0');
  }
}
