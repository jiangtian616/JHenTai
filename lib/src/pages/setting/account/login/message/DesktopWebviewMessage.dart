class DesktopWebviewMessage {
  final int type;
  final String? data;

  DesktopWebviewMessage(this.type, this.data);
}

enum DesktopWebviewMessageType {
  loginSuccess(1),
  loginFailed(2),
  ;

  final int code;

  const DesktopWebviewMessageType(this.code);
}
