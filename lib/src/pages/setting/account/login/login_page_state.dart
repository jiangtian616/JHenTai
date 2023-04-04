import 'package:flutter/cupertino.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

enum LoginType { password, cookie, web }

class LoginPageState {
  LoginType loginType = LoginType.password;

  FocusNode passwordFocusNode = FocusNode();
  FocusNode ipbPassHashFocusNode = FocusNode();
  FocusNode igneousFocusNode = FocusNode();
  
  bool obscureText = true;

  String? userName;
  String? password;
  String? ipbMemberId;
  String? ipbPassHash;
  String? igneous;
  
  LoadingState loginState = LoadingState.idle;
}
