import 'package:flutter/material.dart';

class CheckException implements Exception {
  final String msg;
  dynamic uploadParam;

  CheckException(this.msg, {this.uploadParam});

  @override
  String toString() {
    return 'CheckException{msg: $msg, uploadParam: $uploadParam}';
  }
}

class CheckService {
  final ValueGetter<bool> _checkExpression;
  final String _errorMsg;

  dynamic _uploadParam;
  VoidCallback? _onSuccess;
  VoidCallback? _onFailed;

  CheckService._(this._checkExpression, this._errorMsg);

  factory CheckService.build(ValueGetter<bool> checkExpression, {String? errorMsg}) {
    return CheckService._(checkExpression, errorMsg ?? "");
  }

  CheckService withUploadParam(dynamic uploadParam) {
    _uploadParam = uploadParam;
    return this;
  }

  CheckService onSuccess(VoidCallback onSuccess) {
    _onSuccess = onSuccess;
    return this;
  }

  CheckService onFailed(VoidCallback onFailed) {
    _onFailed = onFailed;
    return this;
  }

  void check() {
    if (_checkExpression.call()) {
      _onSuccess?.call();
    } else {
      _onFailed?.call();
      throw CheckException(_errorMsg, uploadParam: _uploadParam);
    }
  }
}
