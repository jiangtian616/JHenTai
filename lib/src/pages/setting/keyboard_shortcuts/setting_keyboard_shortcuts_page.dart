import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/read_action.dart';
import 'package:jhentai/src/setting/keyboard_shortcut_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';

class SettingKeyboardShortcutsPage extends StatefulWidget {
  const SettingKeyboardShortcutsPage({Key? key}) : super(key: key);

  @override
  State<SettingKeyboardShortcutsPage> createState() => _SettingKeyboardShortcutsPageState();
}

class _SettingKeyboardShortcutsPageState extends State<SettingKeyboardShortcutsPage> {
  ReadAction? _capturingAction;
  int _capturingSlot = 0;
  final FocusNode _captureFocusNode = FocusNode();

  static const double _keyChipWidth = 120.0;
  static const double _actionButtonWidth = 28.0;
  static const double _slotGap = 4.0;
  static const double _slotWidth = _keyChipWidth + _slotGap + _actionButtonWidth;

  bool _isSlotFixed(ReadAction action, int slot) {
    return slot == 0 && (action == ReadAction.back || action == ReadAction.toggleFullScreen);
  }

  String _fixedSlotLabel(ReadAction action) {
    switch (action) {
      case ReadAction.back:
        return 'Esc';
      case ReadAction.toggleFullScreen:
        return 'F11';
      default:
        return '';
    }
  }

  @override
  void dispose() {
    _captureFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _cancelCapture,
      behavior: HitTestBehavior.translucent,
      child: Listener(
        onPointerDown: _onPointerDown,
        child: Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text('keyboardShortcuts'.tr),
            actions: [
              TextButton(
                onPressed: _resetAll,
                child: Text('resetAll'.tr, style: const TextStyle(fontSize: 14)),
              ),
            ],
          ),
          body: Obx(
            () => Focus(
              focusNode: _captureFocusNode,
              onKeyEvent: _onCaptureKeyEvent,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: ReadAction.values.map(_buildActionTile).toList(),
              ).withListTileTheme(context),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tile builders
  // ---------------------------------------------------------------------------

  Widget _buildActionTile(ReadAction action) {
    final bool isCapturing = _capturingAction == action;
    final int capturingSlot = _capturingSlot;
    final List<ReadActionBinding?> bindings = keyboardShortcutSetting.bindingsFor(action);

    return ListTile(
      title: Text(_actionLabel(action)),
      subtitle: isCapturing
          ? Text(
              'pressAnyKey'.tr,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: _slotWidth,
            child: _buildSlotChip(action, 0, bindings[0], isCapturing && capturingSlot == 0),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              width: 1,
              height: 20,
              color: Theme.of(context).dividerColor,
            ),
          ),
          SizedBox(
            width: _slotWidth,
            child: _buildSlotChip(action, 1, bindings[1], isCapturing && capturingSlot == 1),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Slot chip
  // ---------------------------------------------------------------------------

  Widget _buildSlotChip(ReadAction action, int slot, ReadActionBinding? binding, bool isCapturing) {
    final bool isFixed = _isSlotFixed(action, slot);

    Widget keyContent;
    Widget actionContent;

    if (isFixed) {
      keyContent = _buildKeyChip(_fixedSlotLabel(action), dimmed: true);
      actionContent = Icon(Icons.lock_outline, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4));
    } else if (isCapturing) {
      keyContent = _buildCapturingChip();
      actionContent = const SizedBox.shrink();
    } else if (binding != null) {
      keyContent = GestureDetector(
        onTap: () => _startCapture(action, slot),
        child: _buildKeyChip(_bindingLabel(binding)),
      );
      actionContent = SizedBox(
        width: 24,
        height: 24,
        child: IconButton(
          icon: const Icon(Icons.clear, size: 14),
          onPressed: () => _clearBinding(action, slot),
          tooltip: 'clearKey'.tr,
          padding: EdgeInsets.zero,
        ),
      );
    } else {
      keyContent = GestureDetector(
        onTap: () => _startCapture(action, slot),
        child: _buildKeyChip('+', dimmed: true),
      );
      actionContent = const SizedBox(width: 24);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: _keyChipWidth, child: keyContent),
        const SizedBox(width: _slotGap),
        SizedBox(width: _actionButtonWidth, height: 24, child: Center(child: actionContent)),
      ],
    );
  }

  Widget _buildCapturingChip() {
    return Container(
      width: _keyChipWidth,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'pressAnyKey'.tr,
        textAlign: TextAlign.center,
        style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Key chip
  // ---------------------------------------------------------------------------

  Widget _buildKeyChip(String label, {bool dimmed = false}) {
    return Container(
      width: _keyChipWidth,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: dimmed ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5) : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: TextStyle(
          fontSize: 13,
          color: dimmed ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45) : null,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Capture logic
  // ---------------------------------------------------------------------------

  KeyEventResult _onCaptureKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_capturingAction != null) {
        _cancelCapture();
        return KeyEventResult.handled;
      }
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }

    if (_capturingAction == null) {
      return KeyEventResult.ignored;
    }

    _commitKeyboardCapture(event.logicalKey);
    return KeyEventResult.handled;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_capturingAction == null) {
      return;
    }

    final int button = event.buttons;
    if (button == kForwardMouseButton) {
      _commitMouseCapture(const ReadActionBinding.mouseButton4());
    } else if (button == kBackMouseButton) {
      _commitMouseCapture(const ReadActionBinding.mouseButton5());
    }
  }

  void _startCapture(ReadAction action, int slot) {
    setState(() {
      _capturingAction = action;
      _capturingSlot = slot;
    });
    _captureFocusNode.requestFocus();
  }

  void _cancelCapture() {
    if (_capturingAction == null) {
      return;
    }
    setState(() {
      _capturingAction = null;
    });
  }

  Future<void> _commitKeyboardCapture(LogicalKeyboardKey key) async {
    final ReadAction? action = _capturingAction;
    if (action == null) {
      return;
    }
    final int slot = _capturingSlot;
    setState(() {
      _capturingAction = null;
    });

    final ReadActionBinding newBinding = ReadActionBinding.keyboard(key.keyId);
    if (keyboardShortcutSetting.isBindingConflictingWithSlot(newBinding, action, slot)) {
      final ReadAction? conflicting = keyboardShortcutSetting.getActionForBinding(newBinding, action);
      toast(
        '${'keyConflict'.tr}: ${key.debugName} → ${conflicting != null ? _actionLabel(conflicting) : ''}',
        isShort: false,
      );
      return;
    }

    await keyboardShortcutSetting.bind(action, slot, newBinding);
    toast('saveSuccess'.tr);
  }

  Future<void> _commitMouseCapture(ReadActionBinding mouseBinding) async {
    final ReadAction? action = _capturingAction;
    if (action == null) {
      return;
    }
    final int slot = _capturingSlot;

    setState(() {
      _capturingAction = null;
    });

    if (keyboardShortcutSetting.isBindingConflictingWithSlot(mouseBinding, action, slot)) {
      final ReadAction? conflicting = keyboardShortcutSetting.getActionForBinding(mouseBinding, action);
      toast(
        '${'keyConflict'.tr}: ${_bindingLabel(mouseBinding)} → ${conflicting != null ? _actionLabel(conflicting) : ''}',
        isShort: false,
      );
      return;
    }

    await keyboardShortcutSetting.bind(action, slot, mouseBinding);
    toast('saveSuccess'.tr);
  }

  Future<void> _clearBinding(ReadAction action, int slot) async {
    await keyboardShortcutSetting.bind(action, slot, null);
  }

  Future<void> _resetAll() async {
    _cancelCapture();
    await keyboardShortcutSetting.resetAndSave();
    toast('resetSuccess'.tr);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _bindingLabel(ReadActionBinding binding) {
    if (binding.isKeyboard) {
      if (binding.logicalKey!.keyLabel == ' ') {
        return 'Space';
      }
      return binding.logicalKey!.keyLabel;
    }
    if (binding.isMouseButton4) {
      return 'mouseButton4Name'.tr;
    }
    if (binding.isMouseButton5) {
      return 'mouseButton5Name'.tr;
    }
    return '?';
  }

  String _actionLabel(ReadAction action) {
    switch (action) {
      case ReadAction.toNext:
        return 'toNext'.tr;
      case ReadAction.toPrev:
        return 'toPrev'.tr;
      case ReadAction.toLeft:
        return 'toLeft'.tr;
      case ReadAction.toRight:
        return 'toRight'.tr;
      case ReadAction.back:
        return 'back'.tr;
      case ReadAction.toggleMenu:
        return 'toggleMenu'.tr;
      case ReadAction.toggleFirstPageAlone:
        return 'displayFirstPageAlone'.tr;
      case ReadAction.toggleFullScreen:
        return 'toggleFullScreen'.tr;
    }
  }
}
