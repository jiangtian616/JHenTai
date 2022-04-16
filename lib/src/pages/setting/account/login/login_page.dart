import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/global_config.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_logic.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_state.dart';
import 'package:jhentai/src/widget/icon_text_button.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../utils/screen_size_util.dart';

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
          elevation: 0,
        ),
        body: Column(
          children: [
            SizedBox(height: (screenHeight - GlobalConfig.appBarHeight) / 10, width: fullScreenWidth),
            const Text('EHenTai', style: TextStyle(color: Colors.white, fontSize: 60)),
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
                      Column(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              color: Colors.grey.shade200,
                              height: 48,
                              child: TextFormField(
                                onEditingComplete: () => FocusScope.of(context).requestFocus(state.passwordFocusNode),
                                onChanged: (userName) => state.userName = userName,
                                style: const TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  hintText: 'userName'.tr,
                                  hintStyle: TextStyle(color: Colors.grey.shade700),
                                  border: InputBorder.none,
                                  prefixIcon: Icon(Icons.account_circle, size: 22, color: Colors.grey.shade600),
                                ),
                              ),
                            ),
                          ).marginSymmetric(horizontal: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(40),
                            child: Container(
                              color: Colors.grey.shade200,
                              height: 48,
                              child: TextFormField(
                                focusNode: state.passwordFocusNode,
                                obscureText: state.obscureText,
                                style: const TextStyle(color: Colors.black),
                                onChanged: (password) => state.password = password,
                                onFieldSubmitted: (v) => logic.handleLogin(),
                                decoration: InputDecoration(
                                  hintText: 'password'.tr,
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.grey.shade700),
                                  prefixIcon: Icon(Icons.key, size: 22, color: Colors.grey.shade600),
                                  suffixIcon: InkWell(
                                    child: state.obscureText
                                        ? Icon(Icons.visibility, size: 22, color: Colors.grey.shade600)
                                        : Icon(Icons.visibility_off, size: 22, color: Colors.grey.shade600),
                                    onTap: () {
                                      state.obscureText = !state.obscureText;
                                      logic.update();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ).marginSymmetric(horizontal: 16).marginOnly(top: 18),
                        ],
                      ),
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
                                style: const TextStyle(color: Colors.black),
                                decoration: InputDecoration(
                                  hintText: 'Cookie',
                                  border: InputBorder.none,
                                  hintStyle: TextStyle(color: Colors.grey.shade700),
                                  prefixIcon: Icon(FontAwesomeIcons.cookieBite, size: 18, color: Colors.grey.shade600)
                                      .paddingOnly(),
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
                      ).marginOnly(bottom: 42),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconTextButton(
                          text: const Text('Web', style: TextStyle(fontSize: 10)),
                          iconData: Icons.public,
                          onPressed: logic.handleWebLogin,
                          iconColor: Get.theme.primaryColor,
                        ).marginOnly(right: 12),
                        LoadingStateIndicator(
                          width: 56,
                          height: 56,
                          loadingState: state.loginState,
                          errorWidgetSameWithIdle: true,
                          successWidgetBuilder: () => const DoneWidget(outline: true),
                          idleWidget: FloatingActionButton(
                            onPressed: logic.handleLogin,
                            elevation: 2,
                            foregroundColor: Colors.white,
                            backgroundColor: Get.theme.primaryColor,
                            child: const Icon(
                              Icons.arrow_forward,
                              size: 28,
                            ),
                          ),
                        ),
                        IconTextButton(
                          text: Text(
                            state.loginType == LoginType.password ? 'Cookie' : 'User',
                            style: const TextStyle(fontSize: 10),
                          ),
                          onPressed: logic.changeLoginType,
                          iconData: state.loginType == LoginType.password ? Icons.cookie : Icons.face,
                          iconColor: Get.theme.primaryColor,
                        ).marginOnly(left: 12),
                      ],
                    )
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
