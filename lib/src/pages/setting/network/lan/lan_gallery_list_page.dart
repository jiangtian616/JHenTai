import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/model/lan_device_trust.dart';
import 'package:jhentai/src/model/read_page_info.dart';
import 'package:jhentai/src/pages/download/download_base_page.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/lan_device_trust_service.dart';
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
              leading: LanGalleryCover(coverUrl: gallery.coverUrl),
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
              trailing: const Icon(Icons.chevron_right, size: 18),
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

  const LanGalleryCover({super.key, required this.coverUrl});

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

  @override
  void didUpdateWidget(covariant LanGalleryCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverUrl != widget.coverUrl) {
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
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
          return _placeholder(context, retryable: _controller.failed);
        },
      ),
    );
  }

  Widget _placeholder(BuildContext context, {required bool retryable}) {
    final Widget icon = Icon(
      retryable ? Icons.refresh : Icons.image_not_supported_outlined,
      size: 24,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final Widget child =
        retryable
            ? IconButton(
              key: const ValueKey('lanGalleryCoverRetry'),
              tooltip: 'retry'.tr,
              onPressed: () => setState(_controller.retry),
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
