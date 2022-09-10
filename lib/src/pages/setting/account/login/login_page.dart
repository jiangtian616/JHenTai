import 'dart:math';

import 'package:flukit/flukit.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_logic.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_state.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/icon_text_button.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../../../../utils/screen_size_util.dart';

class LoginPage extends StatelessWidget {
  final LoginPageLogic logic = Get.put<LoginPageLogic>(LoginPageLogic());
  final LoginPageState state = Get.find<LoginPageLogic>().state;

  LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LoginPageLogic>(
      builder: (_) => Scaffold(
        /// set false to deal with keyboard
        resizeToAvoidBottomInset: false,
        backgroundColor: UIConfig.loginPageBackgroundColor,
        appBar:
            AppBar(backgroundColor: UIConfig.loginPageBackgroundColor, leading: const BackButton(color: UIConfig.loginPageForegroundColor)),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _TopArea(),
            const Text('EHenTai', style: TextStyle(color: UIConfig.loginPageForegroundColor, fontSize: 60)),
            _buildForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
      height: 300,
      width: 300,
      decoration: BoxDecoration(color: UIConfig.loginPageForegroundColor, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GetBuilder<LoginPageLogic>(
            id: LoginPageLogic.formId,
            builder: (_) => SizedBox(
              height: 140,
              child: Center(child: state.loginType == LoginType.password ? _buildUserNameForm() : _buildCookieForm()),
            ),
          ),
          _buildButtons().marginOnly(top: 24),
        ],
      ),
    );
  }

  Widget _buildUserNameForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildUsernameField(),
        _buildPasswordField().marginOnly(top: 18),
      ],
    );
  }

  Widget _buildUsernameField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(color: UIConfig.loginPageFieldColor, borderRadius: BorderRadius.circular(40)),
      child: TextFormField(
        onEditingComplete: state.passwordFocusNode.requestFocus,
        onChanged: (userName) => state.userName = userName,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'userName'.tr,
          hintStyle: TextStyle(color: UIConfig.loginPageHintColor, fontSize: 14, height: 1),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.account_circle, size: 22, color: UIConfig.loginPagePrefixIconColor),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(color: UIConfig.loginPageFieldColor, borderRadius: BorderRadius.circular(40)),
      height: 48,
      child: TextFormField(
        focusNode: state.passwordFocusNode,
        obscureText: state.obscureText,
        onChanged: (password) => state.password = password,
        onFieldSubmitted: (v) => logic.handleLogin(),
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: 'password'.tr,
          border: InputBorder.none,
          hintStyle: TextStyle(color: UIConfig.loginPageHintColor, fontSize: 14, height: 1),
          prefixIcon: Icon(Icons.key, size: 22, color: UIConfig.loginPagePrefixIconColor),
          suffixIcon: InkWell(
            child: state.obscureText
                ? Icon(Icons.visibility, size: 22, color: UIConfig.loginPagePrefixIconColor)
                : Icon(Icons.visibility_off, size: 22, color: UIConfig.loginPagePrefixIconColor),
            onTap: () {
              state.obscureText = !state.obscureText;
              logic.update();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCookieForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(color: UIConfig.loginPageFieldColor, borderRadius: BorderRadius.circular(40)),
          height: 48,
          child: TextFormField(
            key: const Key('cookie'),
            decoration: InputDecoration(
              hintText: 'Cookie',
              border: InputBorder.none,
              hintStyle: TextStyle(color: UIConfig.loginPageHintColor, fontSize: 14, height: 1),
              prefixIcon: Icon(FontAwesomeIcons.cookieBite, size: 18, color: UIConfig.loginPagePrefixIconColor),
            ),
            onChanged: (cookie) => state.cookie = cookie,
            onFieldSubmitted: (_) => logic.handleLogin(),
          ),
        ),
        Text('ipb_member_id=xxx; ipb_pass_hash=xxx;', style: TextStyle(color: Colors.grey.shade400)).marginOnly(top: 12),
      ],
    );
  }

  Widget _buildButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTextButton(
          icon: Icon(Icons.public, color: UIConfig.loginPageBackgroundColor),
          text: const Text('Web', style: TextStyle(fontSize: 10)),
          onPressed: GetPlatform.isDesktop ? () => toast('webLoginIsDisabled'.tr) : logic.handleWebLogin,
        ),
        ElevatedButton(
          onPressed: logic.handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: UIConfig.loginPageBackgroundColor,
            foregroundColor: UIConfig.loginPageForegroundColor,
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(16),
            minimumSize: const Size(56, 56),
            maximumSize: const Size(56, 56),
          ),
          child: GetBuilder<LoginPageLogic>(
            id: LoginPageLogic.loadingStateId,
            builder: (_) => LoadingStateIndicator(
              useCupertinoIndicator: true,
              loadingState: state.loginState,
              indicatorRadius: 10,
              indicatorColor: UIConfig.loginPageForegroundColor,
              idleWidget: const Icon(Icons.arrow_forward),
              successWidgetBuilder: () => const Icon(Icons.check),
              errorWidgetSameWithIdle: true,
            ),
          ),
        ).marginSymmetric(horizontal: 12),
        IconTextButton(
          icon: Icon(state.loginType == LoginType.password ? Icons.cookie : Icons.face, color: UIConfig.loginPageBackgroundColor),
          text: Text(state.loginType == LoginType.password ? 'Cookie' : 'User', style: const TextStyle(fontSize: 10)),
          onPressed: logic.toggleLoginType,
        ),
      ],
    );
  }
}

class _TopArea extends StatelessWidget {
  const _TopArea({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: max(screenHeight / 10 - MediaQuery.of(context).viewInsets.bottom, 0),
      width: double.infinity,
    );
  }
}
