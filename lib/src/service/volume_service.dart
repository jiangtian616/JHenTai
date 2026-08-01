import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:volume_button_override/volume_button_override.dart';

import 'jh_service.dart';
import 'log.dart';

VolumeService volumeService = VolumeService();

/// Listens to volume key events so that they can be used to turn page in read page.
///
/// - On Android, volume events are intercepted natively via [methodChannel], and the system volume won't change.
/// - On iOS, volume events are captured via [VolumeButtonController], the system volume may still change.
class VolumeService extends GetxService with WidgetsBindingObserver, JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  static const int _volumeUp = 1;
  static const int _volumeDown = -1;

  late final MethodChannel _methodChannel;
  final VolumeButtonController _iosController = VolumeButtonController();

  bool _isListening = false;
  Function(VolumeEventType)? _listener;

  @override
  Future<void> doInitBean() async {
    Get.put(this, permanent: true);
  }

  @override
  Future<void> doAfterBeanReady() async {
    WidgetsBinding.instance.addObserver(this);

    if (GetPlatform.isAndroid) {
      _methodChannel = const MethodChannel('top.jtmonster.jhentai.volume.event.intercept');
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
    cancelListen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    /// iOS deactivates the ambient audio session when the app is backgrounded, which stops volume
    /// button events from being observed; re-establish the listener when the app is resumed.
    if (GetPlatform.isIOS && state == AppLifecycleState.resumed && _listener != null) {
      listen(_listener!);
    }
  }

  Future<void> listen(Function(VolumeEventType) onData) async {
    await cancelListen();
    _listener = onData;

    if (GetPlatform.isAndroid) {
      try {
        await _methodChannel.invokeMethod('set', true);
      } on PlatformException catch (e) {
        log.error('Set intercept volume event error!', e);
        log.uploadError(e);
        return;
      }

      _methodChannel.setMethodCallHandler((MethodCall call) {
        if (call.method == 'event') {
          final int eventType = call.arguments as int;
          if (eventType == _volumeUp) {
            onData(VolumeEventType.volumeUp);
          } else if (eventType == _volumeDown) {
            onData(VolumeEventType.volumeDown);
          }
        }
        return Future.value();
      });

      _isListening = true;
    } else if (GetPlatform.isIOS) {
      try {
        _isListening = await _iosController.startListening(
          volumeUpAction: ButtonAction(id: ButtonActionId.volumeUp, onAction: () => onData(VolumeEventType.volumeUp)),
          volumeDownAction: ButtonAction(id: ButtonActionId.volumeDown, onAction: () => onData(VolumeEventType.volumeDown)),
        );
      } catch (e) {
        log.error('Start listening to volume button error!', e);
        log.uploadError(e);
      }
    }
  }

  Future<void> cancelListen() async {
    if (_isListening) {
      if (GetPlatform.isAndroid) {
        try {
          await _methodChannel.invokeMethod('set', false);
        } on PlatformException catch (e) {
          log.error('Set intercept volume event error!', e);
          log.uploadError(e);
        }
        _methodChannel.setMethodCallHandler(null);
      } else if (GetPlatform.isIOS) {
        try {
          await _iosController.stopListening();
        } catch (e) {
          log.error('Stop listening to volume button error!', e);
          log.uploadError(e);
        }
      }

      _isListening = false;
    }

    _listener = null;
  }
}

enum VolumeEventType { volumeUp, volumeDown }
