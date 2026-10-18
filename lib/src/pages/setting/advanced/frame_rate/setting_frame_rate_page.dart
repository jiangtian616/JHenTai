import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/service/frame_rate_service.dart';

class SettingFrameRatePage extends StatefulWidget {
  const SettingFrameRatePage({super.key});

  @override
  State<SettingFrameRatePage> createState() => _SettingFrameRatePageState();
}

class _SettingFrameRatePageState extends State<SettingFrameRatePage> {
  String? _selection = frameRateService.selection;
  DisplayMode? _activeMode;

  @override
  void initState() {
    super.initState();
    _loadActiveMode();
  }

  Future<void> _loadActiveMode() async {
    try {
      DisplayMode mode = await FlutterDisplayMode.active;
      if (mounted) {
        setState(() => _activeMode = mode);
      }
    } catch (_) {
      // active mode is best-effort info; ignore failures
    }
  }

  @override
  Widget build(BuildContext context) {
    List<DisplayMode> rateModes = frameRateService.distinctRateModes;

    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('refreshRate'.tr)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'refreshRateCurrent'.tr}: ${_activeMode != null ? '${_activeMode!.refreshRate.round()} Hz (${_activeMode!.width}x${_activeMode!.height})' : '...'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text('refreshRateHint'.tr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 20, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'refreshRateSecurityHint'.tr,
                            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            for (DisplayMode mode in rateModes)
              _buildOption(
                context,
                value: mode.id.toString(),
                title: '${mode.refreshRate.round()} Hz',
                subtitle: '${mode.width}x${mode.height}',
              ),
          ],
        ).withListTileTheme(context),
      ),
    );
  }

  Widget _buildOption(BuildContext context, {required String value, required String title, String? subtitle}) {
    bool selected = _selection == value;
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: selected ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary) : null,
      onTap: () {
        if (selected) {
          return;
        }
        setState(() => _selection = value);
        frameRateService.setSelection(value);
        // the system may switch the actual mode with a short delay
        Future.delayed(const Duration(milliseconds: 200), _loadActiveMode);
      },
    );
  }
}
