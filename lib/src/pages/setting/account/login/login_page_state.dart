import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

enum LoginType {
  password,
  cookie,
  web,
}

class LoginPageState {
  LoginType loginType = LoginType.password;
  FocusNode passwordFocusNode = FocusNode();
  String? userName;
  String? password;
  String? cookie;
  LoadingState loginState = LoadingState.idle;

  LoginPageState() {}
}
