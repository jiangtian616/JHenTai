import 'package:clipboard/clipboard.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/utils/cookie_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';

import '../../../../network/eh_cookie_manager.dart';

class CookiePage extends StatelessWidget {
  const CookiePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('accountSetting'.tr),
        actions: [
          IconButton(icon: const Icon(Icons.copy), onPressed: _copCookies),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: CookieUtil.parse2Cookies(EHCookieManager.userCookies)
            .map(
              (cookie) => ListTile(
                title: Text(cookie.name),
                subtitle: Text(cookie.value),
                onTap: _copyAllCookies,
                dense: true,
              ),
            )
            .toList(),
      ).withListTileTheme(context),
    );
  }

  Future<void> _copyAllCookies() async {
    await FlutterClipboard.copy(EHCookieManager.userCookies);
    toast('hasCopiedToClipboard'.tr);
  }

  Future<void> _copCookies() async {
    await FlutterClipboard.copy(CookieUtil.parse2String(CookieUtil.parse2Cookies(EHCookieManager.userCookies)
        .where(
          (cookie) => cookie.name == 'ipb_member_id' || cookie.name == 'ipb_pass_hash' || cookie.name == 'igneous',
        )
        .toList()));
    toast('hasCopiedToClipboard'.tr);
  }
}
