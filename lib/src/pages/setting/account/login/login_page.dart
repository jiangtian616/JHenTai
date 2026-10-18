import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/get_logic_extension.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_logic.dart';
import 'package:jhentai/src/pages/setting/account/login/login_page_state.dart';
import 'package:jhentai/src/widget/icon_text_button.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

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
            Center(child: Text('EHenTai', style: TextStyle(color: UIConfig.loginPageForegroundColor(context), fontSize: 60))),
            _buildTabBar(context).marginOnly(top: 24),
            Expanded(child: _buildTabBarView(context).marginOnly(top: 8)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return TabBar(
      controller: logic.tabController,
      labelColor: UIConfig.loginPageForegroundColor(context),
      unselectedLabelColor: UIConfig.loginPageForegroundColor(context).withValues(alpha: 0.5),
      indicatorColor: UIConfig.loginPageForegroundColor(context),
      tabs: [
        Tab(text: 'passwordTab'.tr),
        Tab(text: 'cookieTab'.tr),
        Tab(text: 'webTab'.tr),
      ],
    );
  }

  Widget _buildTabBarView(BuildContext context) {
    return TabBarView(
      controller: logic.tabController,
      children: [
        _PasswordTabBody(logic: logic, state: state),
        _CookieTabBody(logic: logic, state: state),
        _WebTabBody(logic: logic, state: state),
      ],
    );
  }
}

class _PasswordTabBody extends StatelessWidget {
  final LoginPageLogic logic;
  final LoginPageState state;

  const _PasswordTabBody({required this.logic, required this.state, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: UIConfig.loginPageForegroundColor(context), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUsernameField(context),
              _buildPasswordField(context).marginOnly(top: 16),
              _buildLoginButton(context).marginOnly(top: 24),
            ],
          ),
        ),
      ),
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
    return GetBuilder<LoginPageLogic>(
      builder: (_) => Container(
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
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: logic.handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: UIConfig.loginPageFormIconColor(context),
          foregroundColor: UIConfig.loginPageBackgroundColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        ),
        child: GetBuilder<LoginPageLogic>(
          id: LoginPageLogic.loadingStateId,
          builder: (_) => LoadingStateIndicator(
            useCupertinoIndicator: true,
            loadingState: state.loginState,
            indicatorRadius: 10,
            indicatorColor: UIConfig.loginPageIndicatorColor(context),
            idleWidgetBuilder: () => Text('login'.tr, style: TextStyle(color: UIConfig.loginPageBackgroundColor(context), fontSize: 16)),
            successWidgetBuilder: () => const Icon(Icons.check),
            errorWidgetSameWithIdle: true,
          ),
        ),
      ),
    );
  }
}

class _CookieTabBody extends StatelessWidget {
  final LoginPageLogic logic;
  final LoginPageState state;

  const _CookieTabBody({required this.logic, required this.state, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: UIConfig.loginPageForegroundColor(context), width: 2),
          ),
          child: GetBuilder<LoginPageLogic>(
            id: LoginPageLogic.cookieFormId,
            builder: (_) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIpbMemberIdField(context),
                _buildIpbPassHashField(context).marginOnly(top: 8),
                _buildIgneousRow(context).marginOnly(top: 8),
                _buildVerificationRadios(context).marginOnly(top: 12),
                _buildLoginButton(context).marginOnly(top: 12),
              ],
            ),
          ),
        ),
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
          prefixIcon: Icon(Icons.cookie, size: 18, color: UIConfig.loginPagePrefixIconColor(context)),
          suffixIcon: const SizedBox(height: 8, width: 8, child: Center(child: Text('*'))),
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
          prefixIcon: Icon(Icons.cookie, size: 18, color: UIConfig.loginPagePrefixIconColor(context)),
          suffixIcon: const SizedBox(height: 8, width: 8, child: Center(child: Text('*'))),
        ),
        onEditingComplete: state.igneousFocusNode.requestFocus,
        onFieldSubmitted: (v) => logic.handleLogin(),
        onChanged: (ipbPassHash) => state.ipbPassHash = ipbPassHash,
      ),
    );
  }

  Widget _buildIgneousRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(40)),
            child: TextFormField(
              key: const Key('igneous'),
              focusNode: state.igneousFocusNode,
              controller: TextEditingController(text: state.igneous ?? ''),
              decoration: InputDecoration(
                hintText: 'igneousHint'.tr,
                hintStyle: TextStyle(color: UIConfig.loginPageTextHintColor(context), fontSize: UIConfig.loginPageTextHintSize, height: 1),
                prefixIcon: Icon(Icons.cookie, size: 18, color: UIConfig.loginPagePrefixIconColor(context)),
              ),
              onChanged: (igneous) => state.igneous = igneous,
              onFieldSubmitted: (v) => logic.handleLogin(),
            ),
          ),
        ),
        IconTextButton(
          icon: Icon(Icons.paste, size: 22, color: UIConfig.loginPagePrefixIconColor(context)),
          text: Text('parse'.tr, style: const TextStyle(fontSize: UIConfig.loginPageParseCookieTextSize)),
          onPressed: logic.pasteCookie,
        ),
      ],
    );
  }

  Widget _buildVerificationRadios(BuildContext context) {
    return GetBuilder<LoginPageLogic>(
      id: LoginPageLogic.cookieVerificationTypeId,
      builder: (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RadioListTile<CookieVerificationType>(
            value: CookieVerificationType.normal,
            groupValue: state.cookieVerificationType,
            onChanged: (value) {
              state.cookieVerificationType = value ?? CookieVerificationType.normal;
              logic.updateSafely([LoginPageLogic.cookieVerificationTypeId]);
            },
            title: Text('onlineVerification'.tr, style: const TextStyle(fontSize: 13)),
            dense: true,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<CookieVerificationType>(
            value: CookieVerificationType.webview,
            groupValue: state.cookieVerificationType,
            onChanged: (value) {
              state.cookieVerificationType = value ?? CookieVerificationType.webview;
              logic.updateSafely([LoginPageLogic.cookieVerificationTypeId]);
            },
            title: Text('${'onlineVerification'.tr}（WebView${'assist'.tr}）', style: const TextStyle(fontSize: 13)),
            dense: true,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            contentPadding: EdgeInsets.zero,
          ),
          RadioListTile<CookieVerificationType>(
            value: CookieVerificationType.skip,
            groupValue: state.cookieVerificationType,
            onChanged: (value) {
              state.cookieVerificationType = value ?? CookieVerificationType.skip;
              logic.updateSafely([LoginPageLogic.cookieVerificationTypeId]);
            },
            title: Text('skipVerification'.tr, style: const TextStyle(fontSize: 13)),
            dense: true,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: ElevatedButton(
        onPressed: logic.handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: UIConfig.loginPageFormIconColor(context),
          foregroundColor: UIConfig.loginPageBackgroundColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
        ),
        child: GetBuilder<LoginPageLogic>(
          id: LoginPageLogic.loadingStateId,
          builder: (_) => LoadingStateIndicator(
            useCupertinoIndicator: true,
            loadingState: state.loginState,
            indicatorRadius: 10,
            indicatorColor: UIConfig.loginPageIndicatorColor(context),
            idleWidgetBuilder: () => Text('verifyAndLogin'.tr, style: TextStyle(color: UIConfig.loginPageBackgroundColor(context), fontSize: 16)),
            successWidgetBuilder: () => const Icon(Icons.check),
            errorWidgetSameWithIdle: true,
          ),
        ),
      ),
    );
  }
}

class _WebTabBody extends StatelessWidget {
  final LoginPageLogic logic;
  final LoginPageState state;

  const _WebTabBody({required this.logic, required this.state, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: UIConfig.loginPageForegroundColor(context), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.public, size: 48, color: UIConfig.loginPagePrefixIconColor(context)),
              const SizedBox(height: 20),
              Text(
                'webTabHint'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(color: UIConfig.loginPageFormHintColor(context), fontSize: 13),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: logic.handleWebLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UIConfig.loginPageFormIconColor(context),
                    foregroundColor: UIConfig.loginPageBackgroundColor(context),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                  child: Text('launchWebLogin'.tr, style: TextStyle(color: UIConfig.loginPageBackgroundColor(context), fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
