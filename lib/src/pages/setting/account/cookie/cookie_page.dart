import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../network/eh_cookie_manager.dart';

class CookiePage extends StatelessWidget {
  const CookiePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('accountSetting'.tr)),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: CookieUtil.parse2Cookies(EHCookieManager.userCookies)
            .map(
              (cookie) => ListTile(
                title: Text(cookie.name),
                subtitle: Text(cookie.value),
                onTap: _copyCookies,
                dense: true,
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _copyCookies() async {
    await FlutterClipboard.copy(EHCookieManager.userCookies);
    toast('hasCopiedToClipboard'.tr);
  }
}
