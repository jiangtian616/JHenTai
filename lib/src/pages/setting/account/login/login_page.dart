import 'dart:math';

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
        backgroundColor: UIConfig.loginPageBackgroundColor(context),
        appBar: AppBar(backgroundColor: UIConfig.loginPageBackgroundColor(context), leading: BackButton(color: UIConfig.loginPageForegroundColor(context))),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _TopArea(),
            Text('EHenTai', style: TextStyle(color: UIConfig.loginPageForegroundColor(context), fontSize: 60)),
            _buildForm(context),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Container(
      height: 300,
      width: 300,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: UIConfig.loginPageForegroundColor(context), width: 2)),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GetBuilder<LoginPageLogic>(
        id: LoginPageLogic.formId,
        builder: (_) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 170,
              child: Center(child: state.loginType == LoginType.password ? _buildUserNameForm(context) : _buildCookieForm(context)),
            ),
            _buildButtons(context).marginOnly(top: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildUserNameForm(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildUsernameField(context).marginOnly(top: 6),
        _buildPasswordField(context).marginOnly(top: 12),
        _buildUserNameFormHint(context).marginOnly(top: 36),
      ],
    );
  }

  Widget _buildUsernameField(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
      child: TextFormField(
        onEditingComplete: state.passwordFocusNode.requestFocus,
        onChanged: (userName) => state.userName = userName,
        decoration: InputDecoration(
          hintText: 'userName'.tr,
          hintStyle: TextStyle(color: UIConfig.loginPageTextHintColor(context), fontSize: UIConfig.loginPageTextHintSize, height: 1),
          prefixIcon: Icon(Icons.account_circle, size: 22, color: UIConfig.loginPagePrefixIconColor(context)),
        ),
      ),
    );
  }

  Widget _buildPasswordField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
      height: 48,
      child: TextFormField(
        focusNode: state.passwordFocusNode,
        obscureText: state.obscureText,
        onChanged: (password) => state.password = password,
        onFieldSubmitted: (v) => logic.handleLogin(),
        decoration: InputDecoration(
          hintText: 'password'.tr,
          hintStyle: TextStyle(color: UIConfig.loginPageTextHintColor(context), fontSize: UIConfig.loginPageTextHintSize, height: 1),
          prefixIcon: Icon(Icons.key, size: 22, color: UIConfig.loginPagePrefixIconColor(context)),
          suffixIcon: InkWell(
            child: state.obscureText
                ? Icon(Icons.visibility, size: 22, color: UIConfig.loginPagePrefixIconColor(context))
                : Icon(Icons.visibility_off, size: 22, color: UIConfig.loginPagePrefixIconColor(context)),
            onTap: () {
              state.obscureText = !state.obscureText;
              logic.update();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUserNameFormHint(BuildContext context) {
    return Center(
      child: Text(
        'userNameFormHint'.tr,
        style: TextStyle(color: UIConfig.loginPageFormHintColor(context), fontSize: 13),
      ),
    );
  }

  Widget _buildCookieForm(BuildContext context) {
    return GetBuilder<LoginPageLogic>(
      id: LoginPageLogic.cookieFormId,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildIpbMemberIdField(context).marginOnly(top: 6),
          _buildIpbPassHashField(context).marginOnly(top: 6),
          Row(
            children: [
              Expanded(child: _buildIgneousField(context)),
              IconTextButton(
                icon: Icon(Icons.paste, size: 22, color: UIConfig.loginPagePrefixIconColor(context)),
                text: Text('parse'.tr, style: const TextStyle(fontSize: UIConfig.loginPageParseCookieTextSize)),
                onPressed: logic.pasteCookie,
              ),
            ],
          ).marginOnly(top: 6),
        ],
      ),
    );
  }

  Widget _buildIpbMemberIdField(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
      child: TextFormField(
        key: const Key('ipbMemberId'),
        onEditingComplete: state.passwordFocusNode.requestFocus,
        controller: TextEditingController(text: state.ipbMemberId ?? ''),
        decoration: InputDecoration(
          hintText: 'ipb_member_id',
          hintStyle: TextStyle(color: UIConfig.loginPageTextHintColor(context), fontSize: UIConfig.loginPageTextHintSize, height: 1),
          prefixIcon: Icon(FontAwesomeIcons.cookieBite, size: 18, color: UIConfig.loginPagePrefixIconColor(context)),
          suffixIcon: const SizedBox(
            height: 8,
            width: 8,
            child: Center(child: Text('*')),
          ),
        ),
        onChanged: (ipbMemberId) => state.ipbMemberId = ipbMemberId,
      ),
    );
  }

  Widget _buildIpbPassHashField(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
      child: TextFormField(
        key: const Key('ipbPassHash'),
        focusNode: state.ipbPassHashFocusNode,
        controller: TextEditingController(text: state.ipbPassHash ?? ''),
        decoration: InputDecoration(
          hintText: 'ipb_pass_hash',
          hintStyle: TextStyle(color: UIConfig.loginPageTextHintColor(context), fontSize: UIConfig.loginPageTextHintSize, height: 1),
          prefixIcon: Icon(FontAwesomeIcons.cookieBite, size: 18, color: UIConfig.loginPagePrefixIconColor(context)),
          suffixIcon: const SizedBox(
            height: 8,
            width: 8,
            child: Center(child: Text('*')),
          ),
        ),
        onEditingComplete: state.igneousFocusNode.requestFocus,
        onFieldSubmitted: (v) => logic.handleLogin(),
        onChanged: (ipbPassHash) => state.ipbPassHash = ipbPassHash,
      ),
    );
  }

  Widget _buildIgneousField(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
      child: TextFormField(
        key: const Key('igneous'),
        focusNode: state.igneousFocusNode,
        controller: TextEditingController(text: state.igneous ?? ''),
        decoration: InputDecoration(
          hintText: 'igneous',
          hintStyle: TextStyle(color: UIConfig.loginPageTextHintColor(context), fontSize: UIConfig.loginPageTextHintSize, height: 1),
          prefixIcon: Icon(FontAwesomeIcons.cookieBite, size: 18, color: UIConfig.loginPagePrefixIconColor(context)),
        ),
        onChanged: (igneous) => state.igneous = igneous,
        onFieldSubmitted: (v) => logic.handleLogin(),
      ),
    );
  }

  Widget _buildButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconTextButton(
          width: 56,
          icon: Icon(Icons.public, color: UIConfig.loginPageFormIconColor(context)),
          text: const Text('Web', style: TextStyle(fontSize: 10)),
          onPressed: GetPlatform.isDesktop ? () => toast('webLoginIsDisabled'.tr) : logic.handleWebLogin,
        ),
        ElevatedButton(
          onPressed: logic.handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: UIConfig.loginPageFormIconColor(context),
            foregroundColor: UIConfig.loginPageBackgroundColor(context),
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(12),
            minimumSize: const Size(52, 52),
            maximumSize: const Size(52, 52),
          ),
          child: GetBuilder<LoginPageLogic>(
            id: LoginPageLogic.loadingStateId,
            builder: (_) => LoadingStateIndicator(
              useCupertinoIndicator: true,
              loadingState: state.loginState,
              indicatorRadius: 10,
              indicatorColor: UIConfig.loginPageIndicatorColor(context),
              idleWidget: const Icon(Icons.arrow_forward),
              successWidgetBuilder: () => const Icon(Icons.check),
              errorWidgetSameWithIdle: true,
            ),
          ),
        ).marginSymmetric(horizontal: 18),
        IconTextButton(
          width: 56,
          icon: Icon(state.loginType == LoginType.password ? Icons.cookie : Icons.face, color: UIConfig.loginPageFormIconColor(context)),
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
