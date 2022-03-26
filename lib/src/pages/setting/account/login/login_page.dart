import 'package:flukit/flukit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_login/flutter_login.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';
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
        backgroundColor: Get.theme.primaryColor,
        appBar: AppBar(
          backgroundColor: Get.theme.primaryColor,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            TextButton(
              onPressed: logic.changeLoginType,
              child: Text(state.loginType == LoginType.password ? 'cookieLogin'.tr : 'passwordLogin'.tr),
            ),
          ],
        ),
        body: Column(
          children: [
            SizedBox(height: (context.height - GlobalConfig.appBarHeight) / 10, width: context.width),
            const Text('JHenTai', style: TextStyle(color: Colors.white, fontSize: 60)),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: 300,
                width: 300,
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (state.loginType == LoginType.password)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          color: Colors.grey.shade200,
                          height: 48,
                          child: TextFormField(
                            onEditingComplete: () => FocusScope.of(context).requestFocus(state.passwordFocusNode),
                            onChanged: (userName) => state.userName = userName,
                            decoration: InputDecoration(
                              hintText: 'userName'.tr,
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.account_circle, size: 22),
                            ),
                          ),
                        ),
                      ).marginSymmetric(horizontal: 16),
                    if (state.loginType == LoginType.password)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          color: Colors.grey.shade200,
                          height: 48,
                          child: TextFormField(
                            focusNode: state.passwordFocusNode,
                            obscureText: state.obscureText,
                            onChanged: (password) => state.password = password,
                            onFieldSubmitted: (v) => logic.handleLogin(),
                            decoration: InputDecoration(
                              hintText: 'password'.tr,
                              border: InputBorder.none,
                              prefixIcon: const Icon(Icons.key, size: 22),
                              suffixIcon: InkWell(
                                child: state.obscureText
                                    ? const Icon(Icons.visibility, size: 22)
                                    : const Icon(Icons.visibility_off, size: 22),
                                onTap: () {
                                  state.obscureText = !state.obscureText;
                                  logic.update();
                                },
                              ),
                            ),
                          ),
                        ),
                      ).marginSymmetric(horizontal: 16),
                    if (state.loginType == LoginType.cookie)
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              color: Colors.grey.shade200,
                              height: 44,
                              child: TextFormField(
                                key: const Key('cookie'),
                                decoration: InputDecoration(
                                  hintText: 'Cookie',
                                  border: InputBorder.none,
                                  prefixIcon: const Icon(FontAwesomeIcons.cookieBite, size: 18).paddingOnly(),
                                ),
                                onChanged: (cookie) => state.cookie = cookie,
                                onFieldSubmitted: (v) => logic.handleLogin(),
                              ),
                            ),
                          ).marginSymmetric(horizontal: 16),
                          Text(
                            'ipb_member_id=xxx; ipb_pass_hash=xxx;',
                            style: TextStyle(color: Colors.grey.shade400),
                          ).marginOnly(top: 12),
                        ],
                      ),
                    LoadingStateIndicator(
                      width: 56,
                      height: 56,
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
                    ),
                  ],
                ),
              ),
            ).marginOnly(top: 24),
          ],
        ),
      );
    });
  }
}
