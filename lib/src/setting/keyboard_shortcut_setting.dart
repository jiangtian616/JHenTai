import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/read_action.dart';
import 'package:jhentai/src/service/jh_service.dart';
import 'package:jhentai/src/service/log.dart';

KeyboardShortcutSetting keyboardShortcutSetting = KeyboardShortcutSetting();

// ---------------------------------------------------------------------------
// Binding model
// ---------------------------------------------------------------------------

enum ReadActionBindingType { keyboard, mouseButton4, mouseButton5 }

/// A single input source bound to a [ReadAction].
/// Either a keyboard key or a mouse side button.
class ReadActionBinding {
  final ReadActionBindingType type;

  /// Keyboard key id. Only set when [type] == [ReadActionBindingType.keyboard].
  final int? keyId;

  const ReadActionBinding.keyboard(this.keyId) : type = ReadActionBindingType.keyboard;

  const ReadActionBinding.mouseButton4()
      : type = ReadActionBindingType.mouseButton4,
        keyId = null;

  const ReadActionBinding.mouseButton5()
      : type = ReadActionBindingType.mouseButton5,
        keyId = null;

  bool get isKeyboard => type == ReadActionBindingType.keyboard;

  bool get isMouseButton4 => type == ReadActionBindingType.mouseButton4;

  bool get isMouseButton5 => type == ReadActionBindingType.mouseButton5;

  LogicalKeyboardKey? get logicalKey {
    if (!isKeyboard || keyId == null) {
      return null;
    }
    return LogicalKeyboardKey.findKeyByKeyId(keyId!);
  }

  /// Physical mouse button code, or null for keyboard bindings.
  int? get mouseButton {
    if (isMouseButton4) {
      return kForwardMouseButton;
    }
    if (isMouseButton5) {
      return kBackMouseButton;
    }
    return null;
  }

  /// Human-readable display name shown in the settings UI.
  String get displayName {
    if (isKeyboard) {
      return logicalKey?.debugName ?? '';
    }
    if (isMouseButton4) {
      return 'mouseButton4Name';
    }
    return 'mouseButton5Name';
  }

  Map<String, dynamic> toJson() {
    if (isKeyboard) {
      return {'type': 'keyboard', 'keyId': keyId};
    }
    if (isMouseButton4) {
      return {'type': 'mouseButton4'};
    }
    return {'type': 'mouseButton5'};
  }

  static ReadActionBinding? fromJson(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final String? type = raw['type'] as String?;
    if (type == 'keyboard') {
      return ReadActionBinding.keyboard(raw['keyId'] as int?);
    }
    if (type == 'mouseButton4') {
      return const ReadActionBinding.mouseButton4();
    }
    if (type == 'mouseButton5') {
      return const ReadActionBinding.mouseButton5();
    }
    return null;
  }

  @override
  bool operator ==(Object other) {
    if (other is! ReadActionBinding) {
      return false;
    }
    return type == other.type && keyId == other.keyId;
  }

  @override
  int get hashCode => Object.hash(type, keyId);
}

// ---------------------------------------------------------------------------
// Setting
// ---------------------------------------------------------------------------

class KeyboardShortcutSetting with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  static final Map<ReadAction, List<ReadActionBinding?>> _defaults = {
    ReadAction.toNext: [ReadActionBinding.keyboard(LogicalKeyboardKey.pageDown.keyId), null],
    ReadAction.toPrev: [ReadActionBinding.keyboard(LogicalKeyboardKey.pageUp.keyId), null],
    ReadAction.toLeft: [ReadActionBinding.keyboard(LogicalKeyboardKey.arrowLeft.keyId), null],
    ReadAction.toRight: [ReadActionBinding.keyboard(LogicalKeyboardKey.arrowRight.keyId), null],
    ReadAction.back: [ReadActionBinding.keyboard(LogicalKeyboardKey.escape.keyId), null],
    ReadAction.toggleMenu: [ReadActionBinding.keyboard(LogicalKeyboardKey.space.keyId), null],
    ReadAction.toggleFirstPageAlone: [ReadActionBinding.keyboard(LogicalKeyboardKey.keyM.keyId), null],
    ReadAction.toggleFullScreen: [ReadActionBinding.keyboard(LogicalKeyboardKey.f11.keyId), null],
  };

  /// Two binding slots per action (keyboard key or mouse side button, or null).
  final RxMap<ReadAction, List<ReadActionBinding?>> bindings = RxMap<ReadAction, List<ReadActionBinding?>>({});

  @override
  ConfigEnum get configEnum => ConfigEnum.keyboardShortcutSetting;

  @override
  Future<void> doInitBean() async {
    resetToDefault();
  }

  @override
  void doAfterBeanReady() {}

  @override
  void applyBeanConfig(String configString) {
    resetToDefault();
    try {
      final Map map = jsonDecode(configString) as Map;
      for (final ReadAction action in ReadAction.values) {
        final value = map[action.name];
        if (value == null) continue;

        if (value is List) {
          // New format: list of up to 2 bindings
          final list = value.map((e) => ReadActionBinding.fromJson(e)).take(2).toList();
          while (list.length < 2) { list.add(null); }
          bindings[action] = list;
        } else {
          // Old format: single binding object
          bindings[action] = [ReadActionBinding.fromJson(value), null];
        }
      }
    } catch (e) {
      log.error('Failed to parse keyboard shortcut settings, reset to default', e);
      resetToDefault();
    }
  }

  @override
  String toConfigString() {
    final Map<String, dynamic> map = {};
    for (final ReadAction action in ReadAction.values) {
      map[action.name] = bindings[action]?.map((b) => b?.toJson()).toList();
    }
    return jsonEncode(map);
  }

  void resetToDefault() {
    for (final ReadAction action in ReadAction.values) {
      bindings[action] = List.from(_defaults[action]!);
    }
  }

  // ---------------------------------------------------------------------------
  // Query helpers
  // ---------------------------------------------------------------------------

  List<ReadActionBinding?> bindingsFor(ReadAction action) => bindings[action] ?? [null, null];

  /// Returns the action whose binding matches [binding], skipping [excludeAction].
  ReadAction? getActionForBinding(ReadActionBinding binding, ReadAction excludeAction) {
    return _getActionForBindingWithExclude(binding, excludeAction, null);
  }

  ReadAction? _getActionForBindingWithExclude(ReadActionBinding binding, ReadAction excludeAction, int? excludeSlot) {
    for (final MapEntry<ReadAction, List<ReadActionBinding?>> entry in bindings.entries) {
      final bool isExcludedAction = entry.key == excludeAction;
      for (int i = 0; i < entry.value.length; i++) {
        if (isExcludedAction && i == excludeSlot) continue;
        if (entry.value[i] == binding) return entry.key;
      }
    }
    return null;
  }

  bool isBindingConflicting(ReadActionBinding binding, ReadAction excludeAction) {
    return getActionForBinding(binding, excludeAction) != null;
  }

  bool isBindingConflictingWithSlot(ReadActionBinding binding, ReadAction excludeAction, int excludeSlot) {
    return _getActionForBindingWithExclude(binding, excludeAction, excludeSlot) != null;
  }

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  Future<void> bind(ReadAction action, int slotIndex, ReadActionBinding? binding) async {
    log.debug('bind: ${action.name}[$slotIndex] -> ${binding?.displayName}');
    final list = List<ReadActionBinding?>.from(bindings[action] ?? [null, null]);
    while (list.length < 2) { list.add(null); }
    list[slotIndex] = binding;
    bindings[action] = list;
    await saveBeanConfig();
  }

  Future<void> resetAndSave() async {
    log.debug('resetKeyboardShortcuts to default');
    resetToDefault();
    await saveBeanConfig();
  }

  // ---------------------------------------------------------------------------
  // Handler map builders (consumed by ReadPage)
  // ---------------------------------------------------------------------------

  /// Keyboard handler map for [EHKeyboardListener].
  Map<LogicalKeyboardKey, VoidCallback> buildHandlerMap({
    required VoidCallback onToNext,
    required VoidCallback onToPrev,
    required VoidCallback onToLeft,
    required VoidCallback onToRight,
    required VoidCallback onBack,
    required VoidCallback onToggleMenu,
    required VoidCallback onToggleFirstPageAlone,
    required VoidCallback onToggleFullScreen,
  }) {
    final Map<ReadAction, VoidCallback> callbacks = _buildCallbackMap(
      onToNext: onToNext,
      onToPrev: onToPrev,
      onToLeft: onToLeft,
      onToRight: onToRight,
      onBack: onBack,
      onToggleMenu: onToggleMenu,
      onToggleFirstPageAlone: onToggleFirstPageAlone,
      onToggleFullScreen: onToggleFullScreen,
    );

    final Map<LogicalKeyboardKey, VoidCallback> result = {};
    for (final MapEntry<ReadAction, List<ReadActionBinding?>> entry in bindings.entries) {
      for (final ReadActionBinding? b in entry.value) {
        if (b == null || !b.isKeyboard) continue;
        final LogicalKeyboardKey? key = b.logicalKey;
        if (key != null) result[key] = callbacks[entry.key]!;
      }
    }
    return result;
  }

  /// Mouse handler map for [EHMouseButtonListener].
  Map<int, VoidCallback> buildMouseHandlerMap({
    required VoidCallback onToNext,
    required VoidCallback onToPrev,
    required VoidCallback onToLeft,
    required VoidCallback onToRight,
    required VoidCallback onBack,
    required VoidCallback onToggleMenu,
    required VoidCallback onToggleFirstPageAlone,
    required VoidCallback onToggleFullScreen,
  }) {
    final Map<ReadAction, VoidCallback> callbacks = _buildCallbackMap(
      onToNext: onToNext,
      onToPrev: onToPrev,
      onToLeft: onToLeft,
      onToRight: onToRight,
      onBack: onBack,
      onToggleMenu: onToggleMenu,
      onToggleFirstPageAlone: onToggleFirstPageAlone,
      onToggleFullScreen: onToggleFullScreen,
    );

    final Map<int, VoidCallback> result = {};
    for (final MapEntry<ReadAction, List<ReadActionBinding?>> entry in bindings.entries) {
      for (final ReadActionBinding? b in entry.value) {
        if (b == null) continue;
        final int? button = b.mouseButton;
        if (button != null) result[button] = callbacks[entry.key]!;
      }
    }
    return result;
  }

  Map<ReadAction, VoidCallback> _buildCallbackMap({
    required VoidCallback onToNext,
    required VoidCallback onToPrev,
    required VoidCallback onToLeft,
    required VoidCallback onToRight,
    required VoidCallback onBack,
    required VoidCallback onToggleMenu,
    required VoidCallback onToggleFirstPageAlone,
    required VoidCallback onToggleFullScreen,
  }) {
    return {
      ReadAction.toNext: onToNext,
      ReadAction.toPrev: onToPrev,
      ReadAction.toLeft: onToLeft,
      ReadAction.toRight: onToRight,
      ReadAction.back: onBack,
      ReadAction.toggleMenu: onToggleMenu,
      ReadAction.toggleFirstPageAlone: onToggleFirstPageAlone,
      ReadAction.toggleFullScreen: onToggleFullScreen,
    };
  }
}

