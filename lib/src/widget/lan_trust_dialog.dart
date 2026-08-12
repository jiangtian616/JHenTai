import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';

/// Result of a LAN trust decision.
class LanTrustDecision {
  final bool trust;
  final Set<LanSharePermission> permissions;
  final bool autoConnect;

  const LanTrustDecision({
    required this.trust,
    this.permissions = const {},
    this.autoConnect = true,
  });
}

/// Shows the trust/pair dialog for a discovered LAN peer on the global GetX
/// navigator, so a newly broadcast device can be reviewed from anywhere in the
/// app (not just the LAN sharing page). Returns null when dismissed.
Future<LanTrustDecision?> showLanTrustDialog(LanDiscoveredPeer peer) async {
  try {
    // Get.context resolves the navigator; it can throw before the widgets
    // binding is ready (e.g. during early startup or in headless tests).
    final BuildContext? context = Get.context;
    if (context == null) {
      return null;
    }
    return Get.dialog<LanTrustDecision>(
      LanTrustDialog(peer: peer),
      barrierDismissible: true,
    );
  } on Object {
    return null;
  }
}

/// Review-a-peer dialog: grants the selected capabilities and starts pairing,
/// or declines the device.
class LanTrustDialog extends StatefulWidget {
  final LanDiscoveredPeer peer;

  const LanTrustDialog({super.key, required this.peer});

  @override
  State<LanTrustDialog> createState() => _LanTrustDialogState();
}

class _LanTrustDialogState extends State<LanTrustDialog> {
  final Set<LanSharePermission> _permissions = {
    LanSharePermission.downloads,
    LanSharePermission.imageCache,
    LanSharePermission.translationResults,
    LanSharePermission.loginState,
    LanSharePermission.applicationHistory,
    LanSharePermission.applicationSettings,
  };
  bool _autoConnect = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'lanTrustDeviceQuestion'.trParams({'name': widget.peer.displayName}),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('lanTrustDeviceWarning'.tr),
            const SizedBox(height: 12),
            SelectableText(
              formatLanFingerprint(widget.peer.identityFingerprint),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...LanSharePermission.values.map(
              (permission) => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text('lanPermission_${permission.name}'.tr),
                value: _permissions.contains(permission),
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _permissions.add(permission);
                    } else {
                      _permissions.remove(permission);
                    }
                  });
                },
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('lanAutoConnect'.tr),
              value: _autoConnect,
              onChanged: (value) {
                if (ThemeConfig.isApple) {
                  HapticFeedback.mediumImpact();
                }
                setState(() => _autoConnect = value);
              },
            ),
          ],
        ),
      ),
      actions: [
        EHAppleTextButton(
          onPressed:
              () => Navigator.pop(context, const LanTrustDecision(trust: false)),
          child: Text('lanDoNotTrust'.tr),
        ),
        EHAppleFilledButton(
          onPressed:
              _permissions.isEmpty
                  ? null
                  : () => Navigator.pop(
                    context,
                    LanTrustDecision(
                      trust: true,
                      permissions: Set.unmodifiable(_permissions),
                      autoConnect: _autoConnect,
                    ),
                  ),
          child: Text('lanTrustAndPair'.tr),
        ),
      ],
    );
  }
}

/// Formats an identity fingerprint in readable 8-char groups.
String formatLanFingerprint(String fingerprint) {
  final List<String> chunks = [];
  for (int index = 0; index < fingerprint.length; index += 8) {
    chunks.add(fingerprint.substring(index, index + 8));
  }
  return chunks.join(' ');
}
