import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';

import '../enum/config_enum.dart';
import 'jh_service.dart';
import 'local_config_service.dart';
import 'log.dart';
import 'path_service.dart';

FrameRateService frameRateService = FrameRateService();

class FrameRateService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  List<DisplayMode> supportedModes = [];

  /// Preferred display mode id as string; null means not set yet.
  String? selection;

  @override
  List<JHLifeCircleBean> get initDependencies => [pathService, log, localConfigService];

  @override
  Future<void> doInitBean() async {
    if (!GetPlatform.isAndroid) {
      log.debug('Frame rate service is skipped on non-Android platform');
      return;
    }

    try {
      supportedModes = await FlutterDisplayMode.supported;
      log.info('Fetch supported display modes success, count: ${supportedModes.length}');
    } catch (e, stack) {
      log.error('Fetch supported display modes failed', e, stack);
      return;
    }

    String? saved = await localConfigService.read(configKey: ConfigEnum.frameRateMode);

    // First launch: force the highest refresh rate and remember that choice.
    // Later launches only apply the user's saved selection.
    if (saved == null) {
      selection = _highestModeId();
      log.info('First launch, force highest refresh rate: $selection');
      await FlutterDisplayMode.setHighRefreshRate();
      await localConfigService.write(configKey: ConfigEnum.frameRateMode, value: selection!);
      return;
    }

    selection = saved;
    log.info('Apply saved refresh rate selection: $saved');
    await _apply(saved);
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> setSelection(String value) async {
    log.info('Set refresh rate selection: $value');
    selection = value;
    await localConfigService.write(configKey: ConfigEnum.frameRateMode, value: value);
    await _apply(value);
  }

  Future<void> _apply(String value) async {
    if (!GetPlatform.isAndroid) {
      return;
    }

    int? id = int.tryParse(value);
    DisplayMode? mode;
    for (DisplayMode m in supportedModes) {
      if (m.id == id) {
        mode = m;
        break;
      }
    }

    if (mode == null) {
      // stale id (e.g. device changed): fall back to highest
      log.warning('Unknown display mode id $value, fallback to highest refresh rate');
      await FlutterDisplayMode.setHighRefreshRate();
      return;
    }

    // setPreferredMode only requests a preferred mode; the system may keep
    // the current one based on its own heuristics, so it may not take effect.
    log.info('Apply display mode: id=${mode.id}, ${mode.refreshRate} Hz, ${mode.width}x${mode.height}');
    await FlutterDisplayMode.setPreferredMode(mode);
  }

  /// The supported mode with the highest refresh rate (largest resolution wins
  /// on ties), i.e. what [FlutterDisplayMode.setHighRefreshRate] would pick.
  String? _highestModeId() {
    DisplayMode? best;
    for (DisplayMode mode in supportedModes) {
      if (mode.refreshRate <= 0) {
        continue;
      }
      if (best == null ||
          mode.refreshRate > best.refreshRate ||
          (mode.refreshRate == best.refreshRate && mode.width * mode.height > best.width * best.height)) {
        best = mode;
      }
    }
    return best?.id.toString();
  }

  /// One mode per distinct refresh rate (largest resolution wins), ascending.
  /// [DisplayMode.auto] (refreshRate == 0) is excluded.
  List<DisplayMode> get distinctRateModes {
    Map<double, DisplayMode> best = {};
    for (DisplayMode mode in supportedModes) {
      if (mode.refreshRate <= 0) {
        continue;
      }
      DisplayMode? current = best[mode.refreshRate];
      if (current == null || mode.width * mode.height > current.width * current.height) {
        best[mode.refreshRate] = mode;
      }
    }
    List<DisplayMode> modes = best.values.toList();
    modes.sort((a, b) => a.refreshRate.compareTo(b.refreshRate));
    return modes;
  }
}
