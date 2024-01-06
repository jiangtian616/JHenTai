import 'package:flutter/material.dart';
import 'package:jhentai/src/utils/log.dart';

class CheckException implements Exception {
  final String msg;
  dynamic uploadParam;

  CheckException(this.msg, {this.uploadParam});

  @override
  String toString() {
    return 'CheckException{msg: $msg, uploadParam: $uploadParam}';
  }
}

class CheckUtil {
  final ValueGetter<bool> _checkExpression;
  final String _errorMsg;

  dynamic _uploadParam;
  VoidCallback? _onSuccess;
  VoidCallback? _onFailed;

  CheckUtil._(this._checkExpression, this._errorMsg);

  factory CheckUtil.build(ValueGetter<bool> checkExpression, {String? errorMsg}) {
    return CheckUtil._(checkExpression, errorMsg ?? "");
  }

  CheckUtil withUploadParam(dynamic uploadParam) {
    _uploadParam = uploadParam;
    return this;
  }

  CheckUtil onSuccess(VoidCallback onSuccess) {
    _onSuccess = onSuccess;
    return this;
  }

  CheckUtil onFailed(VoidCallback onFailed) {
    _onFailed = onFailed;
    return this;
  }

  void check({bool throwExceptionWhenFailed = true}) {
    if (_checkExpression.call()) {
      _onSuccess?.call();
    } else {
      _onFailed?.call();

      CheckException e = CheckException(_errorMsg, uploadParam: _uploadParam);
      if (throwExceptionWhenFailed) {
        throw e;
      } else {
        Log.error('Check failed!', e);
        Log.uploadError(e);
      }
    }
  }
}
