import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
import 'package:jhentai/src/service/lan_sharing_runtime.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_apple_button.dart';
import 'package:jhentai/src/widget/eh_apple_controls.dart';

/// The download page's "Local" tab content when [advancedSetting.lanLocalTabAsLan]
/// is on: a browsable list of galleries downloaded on connected trusted LAN
/// devices.
///
/// Only devices that granted *us* the `downloads` permission contribute here.
/// Tapping a gallery opens it online; each page's image bytes then come from
/// the host's downloaded copy over LAN instead of the internet.
class LanGalleryListPage extends StatefulWidget {
  const LanGalleryListPage({super.key});

  @override
  State<LanGalleryListPage> createState() => _LanGalleryListPageState();
}

class _LanGalleryListPageState extends State<LanGalleryListPage> {
  List<LanSharedGallerySummary> _galleries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<LanSharedGallerySummary> galleries = await lanDeviceTrustService
          .listDownloadedGalleries();
      if (!mounted) {
        return;
      }
      setState(() {
        _galleries = galleries;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Groups the flat list by source device, preserving first-seen order.
  List<(String, List<LanSharedGallerySummary>)> _groupByDevice() {
    final List<(String, List<LanSharedGallerySummary>)> groups = [];
    final Map<String, int> deviceIndex = {};
    for (final LanSharedGallerySummary gallery in _galleries) {
      final int index = deviceIndex.putIfAbsent(
        gallery.deviceId,
        () {
          groups.add((gallery.deviceName, <LanSharedGallerySummary>[]));
          return groups.length - 1;
        },
      );
      groups[index].$2.add(gallery);
    }
    return groups;
  }

  void _openGallery(LanSharedGallerySummary gallery) {
    toRoute(
      Routes.read,
      arguments: ReadPageInfo(
        mode: ReadMode.online,
        gid: gallery.gid,
        token: gallery.token,
        galleryTitle: gallery.title,
        galleryUrl: gallery.galleryUrl,
        sourceDeviceId: gallery.deviceId,
        initialIndex: 0,
        pageCount: gallery.pageCount,
        readProgressRecordStorageKey: gallery.gid.toString(),
        useSuperResolution: false,
      ),
    );
  }

  /// Asks the host device to download this gallery locally (LAN remote
  /// download), so an offline peer can queue downloads that run on the
  /// internet-connected desktop.
  Future<void> _downloadToDevice(LanSharedGallerySummary gallery) async {
    if (gallery.galleryUrl.isEmpty) {
      toast('lanGalleryOpenFailed'.tr);
      return;
    }
    final bool accepted = await lanDeviceTrustService.requestDownloadGallery(
      gallery.deviceId,
      LanRemoteDownloadRequest(
        gid: gallery.gid,
        galleryUrl: gallery.galleryUrl,
        token: gallery.token,
        title: gallery.title,
        category: gallery.category,
        pageCount: gallery.pageCount,
        publishTime: gallery.publishTime,
      ),
    );
    toast(accepted ? 'lanDownloadToDeviceSent'.tr : 'lanDownloadToDeviceFailed'.tr);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        titleSpacing: 0,
        title: const DownloadPageSegmentControl(
          galleryType: DownloadPageGalleryType.local,
        ),
        actions: [
          EHAppleIconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('lanGalleryListFailed'.tr, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            EHAppleFilledButton(
              onPressed: _load,
              child: Text('retry'.tr),
            ),
          ],
        ),
      );
    }
    if (_galleries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off, size: 40),
              const SizedBox(height: 12),
              Text(
                'lanGalleryListEmpty'.tr,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'lanGalleryListEmptyHint'.tr,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
    }
    return ListView(
      children: [
        for (final (String deviceName, List<LanSharedGallerySummary> galleries)
            in _groupByDevice()) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                const Icon(Icons.devices, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    deviceName.isEmpty ? 'lanUnknownDevice'.tr : deviceName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${galleries.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          for (final LanSharedGallerySummary gallery in galleries)
            ListTile(
              key: ValueKey('${gallery.deviceId}:${gallery.gid}'),
              leading: LanGalleryCover(
                coverUrl: gallery.coverUrl,
                galleryUrl: gallery.galleryUrl,
                sourceDeviceId: gallery.deviceId,
              ),
              title: Text(
                gallery.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                'lanGalleryPageCount'.trParams({
                  'count': '${gallery.pageCount}',
                }),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download_outlined, size: 20),
                    tooltip: 'lanDownloadToDevice'.tr,
                    onPressed: () => _downloadToDevice(gallery),
                  ),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              onTap: () {
                if (gallery.galleryUrl.isEmpty) {
                  toast('lanGalleryOpenFailed'.tr);
                  return;
                }
                _openGallery(gallery);
              },
            ),
        ],
      ],
    );
  }
}

class LanGalleryCover extends StatefulWidget {
  final String? coverUrl;
  final String? galleryUrl;
  final String? sourceDeviceId;

  const LanGalleryCover({
    super.key,
    required this.coverUrl,
    this.galleryUrl,
    this.sourceDeviceId,
  });

  @override
  State<LanGalleryCover> createState() => _LanGalleryCoverState();
}

class LanGalleryCoverController {
  int attempt = 0;
  bool failed = false;

  void markFailed() => failed = true;

  void reset() {
    failed = false;
    attempt = 0;
  }

  void retry() {
    failed = false;
    attempt++;
  }
}

class _LanGalleryCoverState extends State<LanGalleryCover> {
  final LanGalleryCoverController _controller = LanGalleryCoverController();
  String? _lanPath;
  bool _lanLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchLanCover();
  }

  @override
  void didUpdateWidget(covariant LanGalleryCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl ||
        oldWidget.galleryUrl != widget.galleryUrl ||
        oldWidget.sourceDeviceId != widget.sourceDeviceId) {
      _controller.reset();
      _lanPath = null;
      _fetchLanCover();
    }
  }

  /// Pulls the cover from the host's downloaded copy over LAN. A plain
  /// Image.network on [coverUrl] fails for exhentai images because it carries
  /// no cookies, so the cover reuses the reader's LAN image path (galleryUrl +
  /// page 0) instead of hitting E-Hentai directly.
  Future<void> _fetchLanCover() async {
    final String? galleryUrl = widget.galleryUrl?.trim();
    final String? deviceId = widget.sourceDeviceId;
    if (galleryUrl == null ||
        galleryUrl.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty) {
      return;
    }
    setState(() => _lanLoading = true);
    try {
      final GalleryImage? image = await lanSharingRuntime.fetchCachedImage(
        '',
        galleryUrl: galleryUrl,
        pageIndex: 0,
        sourceDeviceId: deviceId,
      );
      if (!mounted) {
        return;
      }
      final String? path = image?.path;
      setState(() {
        _lanPath = path;
        _lanLoading = false;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _lanLoading = false);
    }
  }

  void _retry() {
    setState(() {
      _lanPath = null;
      _controller.retry();
    });
    _fetchLanCover();
  }

  @override
  Widget build(BuildContext context) {
    final String? path = _lanPath;
    if (path != null && path.isNotEmpty) {
      return SizedBox(
        width: 56,
        height: 80,
        child: Image.file(
          File(path),
          key: ValueKey('$path:${_controller.attempt}'),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            _controller.markFailed();
            return _placeholder(context, retryable: true);
          },
        ),
      );
    }
    if (_lanLoading) {
      return _placeholder(context, retryable: false, loading: true);
    }
    final String? url = widget.coverUrl?.trim();
    if (url == null || url.isEmpty) {
      return _placeholder(context, retryable: false);
    }
    return SizedBox(
      width: 56,
      height: 80,
      child: Image.network(
        url,
        key: ValueKey('$url:${_controller.attempt}'),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          _controller.markFailed();
          return _placeholder(context, retryable: true);
        },
      ),
    );
  }

  Widget _placeholder(
    BuildContext context, {
    required bool retryable,
    bool loading = false,
  }) {
    final Widget icon = loading
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            retryable ? Icons.refresh : Icons.image_not_supported_outlined,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          );
    final Widget child =
        retryable
            ? IconButton(
              key: const ValueKey('lanGalleryCoverRetry'),
              tooltip: 'retry'.tr,
              onPressed: _retry,
              icon: icon,
            )
            : icon;
    return SizedBox(
      width: 56,
      height: 80,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(child: child),
      ),
    );
  }
}
