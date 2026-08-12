import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/config/theme_config.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/model/lan_unified_state.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/service/lan_unified_state_service.dart';
import 'package:jhentai/src/setting/advanced_setting.dart';
import 'package:jhentai/src/utils/byte_util.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';
import 'package:jhentai/src/widget/eh_apple_settings_list_view.dart';
import 'package:jhentai/src/widget/lan_trust_dialog.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

class SettingLanSharingPage extends StatelessWidget {
  const SettingLanSharingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(centerTitle: true, title: Text('lanSharing'.tr)),
      body: GetBuilder<LanDeviceTrustService>(
        id: LanDeviceTrustService.identityChangedId,
        builder: (service) {
          if (!service.isEnabled) {
            return EHAppleSettingsListView(
              groups: [
                EHAppleSettingsGroup(
                  children: [
                    ListTile(
                      title: Text('lanSharingDisabled'.tr),
                      subtitle: Text('lanSharingDisabledHint'.tr),
                      leading: const Icon(Icons.wifi_off),
                    ),
                  ],
                ),
              ],
            );
          }
          return GetBuilder<LanDeviceTrustService>(
            id: LanDeviceTrustService.devicesChangedId,
            builder:
                (service) => EHAppleSettingsListView(
                  groups: [
                    EHAppleSettingsGroup(
                      title: 'lanLocalDevice'.tr,
                      children: [
                        ListTile(
                          title: Text(service.localDisplayName),
                          subtitle: Text(
                            '${'lanDeviceId'.tr}: ${_shortId(service.localDeviceId)}',
                          ),
                          leading: const Icon(Icons.devices),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: () => _editLocalDeviceName(context, service),
                        ),
                        ListTile(
                          title: Text('lanTrustReady'.tr),
                          subtitle: Text('lanTrustReadyHint'.tr),
                          leading: const Icon(Icons.verified_user_outlined),
                        ),
                      ],
                    ),
                    EHAppleSettingsGroup(
                      children: [
                        Obx(
                          () => EHAppleSwitchListTile(
                            title: Text('lanLocalTabAsLan'.tr),
                            subtitle: Text('lanLocalTabAsLanHint'.tr),
                            value: advancedSetting.lanLocalTabAsLan.value,
                            onChanged: advancedSetting.saveLanLocalTabAsLan,
                          ),
                        ),
                        if (GetPlatform.isDesktop)
                          Obx(
                            () => EHAppleSwitchListTile(
                              title: Text('lanServerMode'.tr),
                              subtitle: Text('lanServerModeHint'.tr),
                              value: advancedSetting.lanServerMode.value,
                              onChanged: advancedSetting.saveLanServerMode,
                            ),
                          ),
                        Obx(
                          () => EHAppleSwitchListTile(
                            title: Text('lanActiveBroadcast'.tr),
                            subtitle: Text('lanActiveBroadcastHint'.tr),
                            value: advancedSetting.lanActiveBroadcast.value,
                            onChanged: advancedSetting.saveLanActiveBroadcast,
                          ),
                        ),
                        Obx(
                          () => advancedSetting.lanServerMode.value
                              ? const SizedBox.shrink()
                              : GetBuilder<LanDeviceTrustService>(
                                  id: LanDeviceTrustService.devicesChangedId,
                                  builder: (service) => ListTile(
                                    leading: const Icon(Icons.dns_outlined),
                                    title: Text('lanPreferredServer'.tr),
                                    subtitle: Text(
                                      _preferredServerLabel(service),
                                    ),
                                    trailing: const Icon(Icons.chevron_right),
                                    onTap: () => _selectPreferredServer(
                                      context,
                                      service,
                                    ),
                                  ),
                                ),
                        ),
                        if (GetPlatform.isDesktop)
                          Obx(
                            () => EHAppleSwitchListTile(
                              title: Text('lanStayResident'.tr),
                              subtitle: Text('lanStayResidentHint'.tr),
                              value: advancedSetting.lanStayResident.value,
                              onChanged: advancedSetting.saveLanStayResident,
                            ),
                          ),
                      ],
                    ),
                    EHAppleSettingsGroup(
                      title: 'lanTrafficStats'.tr,
                      children: [
                        GetBuilder<LanDeviceTrustService>(
                          id: LanDeviceTrustService.trafficChangedId,
                          builder:
                              (service) => ListTile(
                                leading: const Icon(
                                  Icons.swap_vert_circle_outlined,
                                ),
                                title: Text(
                                  '${'lanTrafficTotal'.tr}: ${byte2String(service.totalTransferredBytes.toDouble())}',
                                ),
                                subtitle: Text(
                                  '${'lanTrafficSent'.tr}: ${byte2String(service.sentBytes.toDouble())}  ·  '
                                  '${'lanTrafficReceived'.tr}: ${byte2String(service.receivedBytes.toDouble())}\n'
                                  '${'lanTrafficCurrentRunHint'.tr}',
                                ),
                              ),
                        ),
                      ],
                    ),
                    EHAppleSettingsGroup(
                      title: 'lanUnifiedState'.tr,
                      children: [
                        GetBuilder<LanUnifiedStateService>(
                          id: LanUnifiedStateService.statusChangedId,
                          builder: (sync) {
                            LanUnifiedSyncStatus? login;
                            LanUnifiedSyncStatus? history;
                            for (final LanUnifiedSyncStatus status
                                in sync.statuses) {
                              if (status.type == 'loginState' && login == null) {
                                login = status;
                              }
                              if (status.type == 'applicationHistory' &&
                                  history == null) {
                                history = status;
                              }
                            }
                            if (login == null && history == null) {
                              return ListTile(
                                title: Text('lanUnifiedStateEmpty'.tr),
                                subtitle: Text('lanUnifiedStateHint'.tr),
                              );
                            }
                            return Column(
                              children: [
                                _buildUnifiedStateRow(
                                  context,
                                  login,
                                  'lanUnifiedStateLogin'.tr,
                                  countIsRecords: false,
                                ),
                                _buildUnifiedStateRow(
                                  context,
                                  history,
                                  'lanUnifiedStateHistory'.tr,
                                  countIsRecords: true,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                    EHAppleSettingsGroup(
                      title: 'lanNearbyDevices'.tr,
                      children: [
                        GetBuilder<LanDeviceTrustService>(
                          id: LanDeviceTrustService.discoveredDevicesChangedId,
                          builder: (service) {
                            final peers =
                                service.discoveredPeers
                                    .where(
                                      (peer) =>
                                          service.deviceById(peer.deviceId) ==
                                          null,
                                    )
                                    .toList();
                            if (peers.isEmpty) {
                              return ListTile(
                                title: Text('lanSearchingDevices'.tr),
                                subtitle: Text('lanSearchingDevicesHint'.tr),
                                leading: const Icon(Icons.radar),
                              );
                            }
                            return Column(
                              children:
                                  peers
                                      .map(
                                        (peer) =>
                                            _DiscoveredDeviceTile(peer: peer),
                                      )
                                      .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                    EHAppleSettingsGroup(
                      title: 'lanIncomingPairingRequests'.tr,
                      children: [
                        GetBuilder<LanDeviceTrustService>(
                          id: LanDeviceTrustService.incomingPairingsChangedId,
                          builder: (service) {
                            if (service.incomingPairingRequests.isEmpty) {
                              return ListTile(
                                title: Text('lanNoIncomingPairingRequests'.tr),
                                leading: const Icon(
                                  Icons.mark_email_read_outlined,
                                ),
                              );
                            }
                            return Column(
                              children:
                                  service.incomingPairingRequests
                                      .map(
                                        (request) => _IncomingPairingTile(
                                          request: request,
                                        ),
                                      )
                                      .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                    EHAppleSettingsGroup(
                      title: 'lanTrustedDevices'.tr,
                      children:
                          service.trustedDevices.isEmpty
                              ? [
                                ListTile(
                                  title: Text('lanNoTrustedDevices'.tr),
                                  subtitle: Text('lanNoTrustedDevicesHint'.tr),
                                  leading: const Icon(Icons.phonelink_off),
                                ),
                              ]
                              : service.trustedDevices
                                  .map(
                                    (device) => _TrustedDeviceTile(
                                      key: ValueKey(device.deviceId),
                                      device: device,
                                    ),
                                  )
                                  .toList(),
                    ),
                  ],
                ),
          );
        },
      ),
    );
  }

  static String _shortId(String value) {
    if (value.length <= 14) {
      return value;
    }
    return '${value.substring(0, 7)}…${value.substring(value.length - 6)}';
  }

  static Widget _buildUnifiedStateRow(
    BuildContext context,
    LanUnifiedSyncStatus? status,
    String label, {
    required bool countIsRecords,
  }) {
    if (status == null) {
      return ListTile(
        title: Text(label),
        subtitle: Text('lanUnifiedStateNotSynced'.tr),
      );
    }
    final String result = status.count > 0
        ? (countIsRecords
              ? '${status.count} ${'lanUnifiedStateRecords'.tr}'
              : 'lanUnifiedStateSynced'.tr)
        : 'lanUnifiedStateNotSynced'.tr;
    final String failure = status.failureReason == null
        ? ''
        : ' · ${'lanUnifiedStateFailed'.tr}: ${status.failureReason}';
    return ListTile(
      title: Text(label),
      trailing: Text(
        DateFormat('HH:mm').format(status.at.toLocal()),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      subtitle: Text('$result$failure'),
    );
  }

  static String _preferredServerLabel(LanDeviceTrustService service) {
    final String id = advancedSetting.lanPreferredServerDeviceId.value;
    if (id.isEmpty) {
      return 'lanNoPreferredServer'.tr;
    }
    final TrustedLanDevice? device = service.deviceById(id);
    return device == null
        ? '${'lanUnknownDevice'.tr}: ${_shortId(id)}'
        : device.displayName;
  }

  Future<void> _selectPreferredServer(
    BuildContext context,
    LanDeviceTrustService service,
  ) async {
    final String? selected = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => SimpleDialog(
            title: Text('lanPreferredServer'.tr),
            children: [
              SimpleDialogOption(
                onPressed: () => Navigator.of(dialogContext).pop(''),
                child: Text('lanNoPreferredServer'.tr),
              ),
              ...service.trustedDevices.map(
                (TrustedLanDevice device) => SimpleDialogOption(
                  onPressed:
                      () => Navigator.of(dialogContext).pop(device.deviceId),
                  child: Text(device.displayName),
                ),
              ),
            ],
          ),
    );
    if (selected != null) {
      await advancedSetting.saveLanPreferredServerDeviceId(selected);
    }
  }

  /// Lets the user rename this device (persisted via the trust service).
  Future<void> _editLocalDeviceName(
    BuildContext context,
    LanDeviceTrustService service,
  ) async {
    final TextEditingController controller = TextEditingController(
      text: service.localDisplayName,
    );
    final String? name = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('lanEditDeviceName'.tr),
            content: EHAppleTextField(
              controller: controller,
              autofocus: true,
              maxLength: 128,
              decoration: const InputDecoration(isDense: true),
              onSubmitted:
                  (_) => Navigator.of(dialogContext).pop(controller.text),
            ),
            actions: [
              EHAppleTextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text('cancel'.tr),
              ),
              EHAppleTextButton(
                onPressed:
                    () => Navigator.of(dialogContext).pop(controller.text),
                child: Text('OK'.tr),
              ),
            ],
          ),
    );
    controller.dispose();
    if (name == null) {
      return;
    }
    final String? error = await service.setLocalDisplayName(name);
    if (error != null) {
      toast(error);
    }
  }
}

class _IncomingPairingTile extends StatelessWidget {
  final LanIncomingPairingRequest request;

  const _IncomingPairingTile({required this.request});

  @override
  Widget build(BuildContext context) {
    final LanDiscoveredPeer peer = request.peer;
    return ListTile(
      leading: const Icon(Icons.phonelink_ring),
      title: Text(
        peer.displayName.trim().isEmpty ? peer.deviceId : peer.displayName,
      ),
      subtitle: Text('lanIncomingPairingRequestHint'.tr),
      trailing: EHAppleFilledButton(
        onPressed: () => _review(context),
        child: Text('lanReviewDevice'.tr),
      ),
    );
  }

  Future<void> _review(BuildContext context) async {
    final LanTrustDecision? decision = await showLanTrustDialog(request.peer);
    if (decision == null) {
      return;
    }
    if (!decision.trust) {
      lanDeviceTrustService.declineIncomingPairing(request.peer.deviceId);
      return;
    }
    try {
      await lanDeviceTrustService.acceptIncomingPairing(
        deviceId: request.peer.deviceId,
        permissions: decision.permissions,
        autoConnect: decision.autoConnect,
      );
      toast('lanTrustGranted'.tr);
    } on Object {
      toast('lanPairingFailed'.tr);
    }
  }
}

class _DiscoveredDeviceTile extends StatelessWidget {
  final LanDiscoveredPeer peer;

  const _DiscoveredDeviceTile({required this.peer});

  @override
  Widget build(BuildContext context) {
    final bool isPairing = lanDeviceTrustService.isPairingWith(peer.deviceId);
    return ListTile(
      leading: const Icon(Icons.devices_other),
      title: Text(
        peer.displayName.trim().isEmpty ? peer.deviceId : peer.displayName,
      ),
      subtitle: Text('${peer.host}:${peer.port}'),
      trailing: EHAppleFilledButton.tonal(
        onPressed: isPairing ? null : () => _chooseTrust(context),
        child: Text(isPairing ? 'lanPairingWaiting'.tr : 'lanReviewDevice'.tr),
      ),
    );
  }

  Future<void> _chooseTrust(BuildContext context) async {
    final LanTrustDecision? decision = await showLanTrustDialog(peer);
    if (decision == null) {
      return;
    }
    if (!decision.trust) {
      lanDeviceTrustService.ignoreDiscoveredDevice(peer.deviceId);
      return;
    }
    try {
      await lanDeviceTrustService.trustDiscoveredDevice(
        deviceId: peer.deviceId,
        permissions: decision.permissions,
        autoConnect: decision.autoConnect,
      );
      toast('lanTrustGranted'.tr);
    } on Object {
      toast('lanPairingFailed'.tr);
    }
  }
}

class _TrustedDeviceTile extends StatelessWidget {
  final TrustedLanDevice device;

  const _TrustedDeviceTile({super.key, required this.device});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<LanDeviceTrustService>(
      id: lanDeviceTrustService.connectionId(device.deviceId),
      builder: (service) {
        final LanConnectionSnapshot connection = service.connectionFor(
          device.deviceId,
        );
        final String? errorMessage = connection.errorMessage;
        return ExpansionTile(
          leading: Icon(_statusIcon(connection.state)),
          title: Text(device.displayName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_statusLabel(connection.state)),
              if (errorMessage != null && errorMessage.isNotEmpty)
                Text(
                  errorMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
          childrenPadding: const EdgeInsets.only(left: 16, right: 8, bottom: 8),
          children: [
            EHAppleSwitchListTile(
              title: Text('lanAutoConnect'.tr),
              subtitle: Text('lanAutoConnectHint'.tr),
              value: device.autoConnect,
              onChanged:
                  (value) => lanDeviceTrustService.setAutoConnect(
                    device.deviceId,
                    value,
                  ),
            ),
            ListTile(
              title: Text('lanFingerprint'.tr),
              subtitle: SelectableText(
                formatLanFingerprint(device.identityFingerprint),
              ),
            ),
            ListTile(
              title: Text('lanLastSeen'.tr),
              trailing: Text(
                DateFormat(
                  'yyyy-MM-dd HH:mm',
                ).format(device.lastSeenAt.toLocal()),
              ),
            ),
            ListTile(
              title: Text('lanPermissions'.tr),
              subtitle: Wrap(
                spacing: 6,
                runSpacing: 4,
                children:
                    device.permissions
                        .map(
                          (permission) => Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(_permissionLabel(permission)),
                          ),
                        )
                        .toList(),
              ),
            ),
            ...[
              LanSharePermission.translationCompute,
              LanSharePermission.ocrCompute,
              LanSharePermission.loginState,
              LanSharePermission.applicationHistory,
            ].map(
              (permission) => EHAppleSwitchListTile(
                title: Text('lanPermission_${permission.name}'.tr),
                subtitle: Text('lanPermissionRevokeHint'.tr),
                value: device.permissions.contains(permission),
                onChanged: (value) {
                  final Set<LanSharePermission> updated =
                      Set<LanSharePermission>.from(device.permissions);
                  if (value) {
                    updated.add(permission);
                  } else {
                    updated.remove(permission);
                  }
                  lanDeviceTrustService.setPermissions(
                    device.deviceId,
                    updated,
                  );
                },
              ),
            ),
            ListTile(
              title: Text(
                'lanRevokeTrust'.tr,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              leading: Icon(
                Icons.link_off,
                color: Theme.of(context).colorScheme.error,
              ),
              onTap: () => _confirmRevoke(context),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmRevoke(BuildContext context) async {
    final bool? confirmed =
        ThemeConfig.isApple
            ? await GlassDialog.show<bool>(
              context: context,
              settings: UIConfig.glassDialogSettings(context),
              title: 'lanRevokeTrust'.tr,
              message: 'lanRevokeTrustHint'.trParams({
                'name': device.displayName,
              }),
              actions: [
                GlassDialogAction(
                  label: 'cancel'.tr,
                  onPressed: () => backRoute(result: false),
                ),
                GlassDialogAction(
                  label: 'OK'.tr,
                  onPressed: () => backRoute(result: true),
                  isPrimary: true,
                ),
              ],
            )
            : await showDialog<bool>(
              context: context,
              builder:
                  (dialogContext) => AlertDialog(
                    title: Text('lanRevokeTrust'.tr),
                    content: Text(
                      'lanRevokeTrustHint'.trParams({
                        'name': device.displayName,
                      }),
                    ),
                    actions: [
                      EHAppleTextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        child: Text('cancel'.tr),
                      ),
                      EHAppleFilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        child: Text('OK'.tr),
                      ),
                    ],
                  ),
            );
    if (confirmed == true) {
      await lanDeviceTrustService.revokeTrust(device.deviceId);
    }
  }

  IconData _statusIcon(LanPeerConnectionState state) {
    switch (state) {
      case LanPeerConnectionState.connected:
        return Icons.link;
      case LanPeerConnectionState.connecting:
        return Icons.sync;
      case LanPeerConnectionState.discovered:
        return Icons.wifi;
      case LanPeerConnectionState.failed:
        return Icons.error_outline;
      case LanPeerConnectionState.identityMismatch:
        return Icons.gpp_bad_outlined;
      case LanPeerConnectionState.offline:
        return Icons.devices_other;
    }
  }

  String _statusLabel(LanPeerConnectionState state) =>
      'lanConnection_${state.name}'.tr;

  String _permissionLabel(LanSharePermission permission) =>
      'lanPermission_${permission.name}'.tr;
}
