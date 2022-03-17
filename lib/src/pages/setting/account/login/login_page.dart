import 'package:flukit/flukit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_logic.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_state.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

class LoginPage extends StatelessWidget {
  final LoginPageLogic logic = Get.put<LoginPageLogic>(LoginPageLogic());
  final LoginPageState state = Get.find<LoginPageLogic>().state;

  LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LoginPageLogic>(builder: (logic) {
      return Scaffold(
        /// must set false
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: Text('login'.tr),
          elevation: 1,
          actions: [
            TextButton(
              onPressed: logic.changeLoginType,
              child: Text(state.loginType == LoginType.password ? 'cookieLogin'.tr : 'passwordLogin'.tr),
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.center,
          child: SizedBox(
            height: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (state.loginType == LoginType.password)
                    CupertinoFormSection.insetGrouped(
                      backgroundColor: Colors.transparent,
                      children: [
                        CupertinoTextFormFieldRow(
                          autofocus: true,
                          textAlign: TextAlign.right,
                          onEditingComplete: () => FocusScope.of(context).requestFocus(state.passwordFocusNode),
                          onChanged: (userName) => state.userName = userName,
                          prefix: Row(
                            children: [
                              Icon(Icons.account_circle, color: Theme.of(context).primaryColor),
                              Text('userName'.tr, style: const TextStyle(fontSize: 16)).marginOnly(left: 8),
                            ],
                          ),
                        ),
                        CupertinoTextFormFieldRow(
                          focusNode: state.passwordFocusNode,
                          textAlign: TextAlign.right,
                          obscureText: true,
                          onChanged: (password) => state.password = password,
                          onFieldSubmitted: (v) => logic.handleLogin(),
                          prefix: Row(
                            children: [
                              Icon(Icons.key, color: Theme.of(context).primaryColor),
                              Text('password'.tr, style: const TextStyle(fontSize: 16)).marginOnly(left: 8),
                            ],
                          ),
                        )
                      ],
                    ),
                  if (state.loginType == LoginType.cookie)
                    Column(
                      children: [
                        CupertinoFormSection.insetGrouped(
                          backgroundColor: Colors.transparent,
                          children: [
                            CupertinoTextFormFieldRow(
                              key: const Key('cookie'),
                              autofocus: true,
                              textAlign: TextAlign.right,
                              onChanged: (cookie) => state.cookie = cookie,
                              onFieldSubmitted: (v) => logic.handleLogin(),
                              prefix: Row(
                                children: [
                                  Icon(FontAwesomeIcons.cookieBite, color: Theme.of(context).primaryColor),
                                  const Text('Cookie', style: TextStyle(fontSize: 16)).marginOnly(left: 8),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'ipb_member_id=xxx; ipb_pass_hash=xxx;',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  LoadingStateIndicator(
                    width: 60,
                    height: 60,
                    loadingState: state.loginState,
                    errorWidgetSameWithIdle: true,
                    successWidget: const DoneWidget(outline: true),
                    idleWidget: FloatingActionButton(
                      onPressed: logic.handleLogin,
                      child: const Icon(
                        Icons.arrow_forward,
                        size: 28,
                      ),
                      elevation: 2,
                    ),
                  ).marginOnly(top: 32),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}
