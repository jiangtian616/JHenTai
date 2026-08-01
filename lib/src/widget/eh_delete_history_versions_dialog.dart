import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/network/eh_request.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/gallery_download_service.dart';
import 'package:jhentai/src/service/local_config_service.dart';
import 'package:jhentai/src/service/log.dart';
import 'package:jhentai/src/utils/eh_spider_parser.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:retry/retry.dart';

enum _DialogPhase { scanning, reviewing, deepScanning, deleting, completed }

class EHDeleteHistoryVersionsDialog extends StatefulWidget {
  const EHDeleteHistoryVersionsDialog({Key? key}) : super(key: key);

  @override
  State<EHDeleteHistoryVersionsDialog> createState() =>
      _EHDeleteHistoryVersionsDialogState();
}

class _EHDeleteHistoryVersionsDialogState
    extends State<EHDeleteHistoryVersionsDialog> {
  _DialogPhase phase = _DialogPhase.scanning;

  List<List<GalleryDownloadedData>> versionGroups = [];
  Set<int> selectedGids = {};
  Set<int> expandedGroups = {};

  int deleteTotal = 0;
  int deleteCurrent = 0;
  int deleteSuccess = 0;

  int deepScanTotal = 0;
  int deepScanCurrent = 0;
  int deepScanNewLinks = 0;

  List<GalleryDownloadedData> ungroupedGallerys = [];
  List<GalleryDownloadedData> failedGallerys = [];

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    await Future.delayed(Duration.zero);

    try {
      List<GalleryDownloadedData> allGallerys =
          List.of(galleryDownloadService.gallerys);

      Map<String, GalleryDownloadedData> url2Gallery = {
        for (GalleryDownloadedData g in allGallerys) g.galleryUrl: g,
      };

      _UnionFind<int> uf =
          _UnionFind<int>(allGallerys.map((g) => g.gid).toSet());

      for (GalleryDownloadedData g in allGallerys) {
        if (g.oldVersionGalleryUrl != null) {
          GalleryDownloadedData? parent = url2Gallery[g.oldVersionGalleryUrl];
          if (parent != null) {
            uf.union(g.gid, parent.gid);
          }
        }
      }

      Map<int, List<GalleryDownloadedData>> groupMap = {};
      for (GalleryDownloadedData g in allGallerys) {
        int root = uf.find(g.gid);
        groupMap.putIfAbsent(root, () => []).add(g);
      }

      List<List<GalleryDownloadedData>> groups =
          groupMap.values.where((list) => list.length > 1).map((list) {
        list.sort((a, b) => b.publishTime.compareTo(a.publishTime));
        return list;
      }).toList();

      groups.sort((a, b) => b.length.compareTo(a.length));

      Set<int> groupedGids =
          groups.expand((list) => list).map((g) => g.gid).toSet();
      List<GalleryDownloadedData> ungrouped =
          allGallerys.where((g) => !groupedGids.contains(g.gid)).toList();

      Set<int> defaultSelected = {};
      for (List<GalleryDownloadedData> group in groups) {
        for (int i = 1; i < group.length; i++) {
          defaultSelected.add(group[i].gid);
        }
      }

      if (!mounted) return;
      setState(() {
        versionGroups = groups;
        ungroupedGallerys = ungrouped;
        selectedGids = defaultSelected;
        phase = _DialogPhase.reviewing;
      });
    } catch (e) {
      log.error('scan history versions failed', e);
      if (mounted) {
        toast('scanFailed'.tr);
        backRoute();
      }
    }
  }

  Future<void> _deepScan() async {
    if (ungroupedGallerys.isEmpty) {
      toast('noGalleriesToDeepScan'.tr);
      return;
    }

    ({Map<int, Set<int>> newLinks, List<int> failedGids})? saved =
        await _loadSavedScanResult();
    if (saved != null) {
      bool? choice = await _showScanChoiceDialog();
      if (choice == null) return;
      if (choice) {
        _mergeNewLinks(saved.newLinks, saved.newLinks.keys.toSet());
        // Restore failed galleries from saved gids
        Set<int> failedGidSet = saved.failedGids.toSet();
        failedGallerys = galleryDownloadService.gallerys
            .where((g) => failedGidSet.contains(g.gid))
            .toList();
        if (mounted) {
          setState(() {
            deepScanNewLinks = saved.newLinks.length;
            phase = _DialogPhase.reviewing;
          });
        }
        toast('deepScanCompleted'
            .tr
            .replaceAll('\$n', saved.newLinks.length.toString()));
        return;
      }
    }

    await _executeDeepScan(ungroupedGallerys);
  }

  Future<bool?> _showScanChoiceDialog() {
    return Get.dialog<bool>(
      AlertDialog(
        title: Text('deepScan'.tr),
        content: Text('deepScanChoiceHint'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('newDeepScan'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('useHistoryScanResult'.tr),
          ),
        ],
      ),
      barrierDismissible: false,
    );
  }

  Future<({Map<int, Set<int>> newLinks, List<int> failedGids})?>
      _loadSavedScanResult() async {
    try {
      String? json = await localConfigService.read(
        configKey: ConfigEnum.deepScanResult,
      );
      if (json == null) return null;

      Map<String, dynamic> data = jsonDecode(json);
      String timestampStr = data['timestamp'] as String;
      DateTime timestamp = DateTime.parse(timestampStr);

      if (DateTime.now().difference(timestamp).inHours >= 24) {
        await localConfigService.delete(
          configKey: ConfigEnum.deepScanResult,
        );
        return null;
      }

      Map<int, Set<int>> newLinks = {};
      Map<String, dynamic> links = data['newLinks'] as Map<String, dynamic>;
      links.forEach((key, value) {
        int gid = int.parse(key);
        Set<int> neighbors = (value as List).map((e) => e as int).toSet();
        newLinks[gid] = neighbors;
      });

      List<int> failedGids =
          (data['failedGids'] as List?)?.map((e) => e as int).toList() ?? [];

      return (newLinks: newLinks, failedGids: failedGids);
    } catch (e) {
      log.error('load saved deep scan result failed', e.toString());
      return null;
    }
  }

  Future<void> _saveScanResult(
      Map<int, Set<int>> newLinks, List<int> failedGids) async {
    try {
      Map<String, dynamic> data = {
        'timestamp': DateTime.now().toIso8601String(),
        'newLinks': newLinks.map((k, v) => MapEntry(k.toString(), v.toList())),
        'failedGids': failedGids,
      };
      await localConfigService.write(
        configKey: ConfigEnum.deepScanResult,
        value: jsonEncode(data),
      );
    } catch (e) {
      log.error('save deep scan result failed', e.toString());
    }
  }

  Future<void> _executeDeepScan(
      List<GalleryDownloadedData> galleriesToScan) async {
    setState(() {
      phase = _DialogPhase.deepScanning;
      deepScanTotal = galleriesToScan.length;
      deepScanCurrent = 0;
      deepScanNewLinks = 0;
    });

    Map<String, GalleryDownloadedData> url2Gallery = {
      for (GalleryDownloadedData g in galleryDownloadService.gallerys)
        g.galleryUrl: g,
    };

    // Load previously saved links to accumulate across scans (initial + retries)
    ({Map<int, Set<int>> newLinks, List<int> failedGids})? saved =
        await _loadSavedScanResult();
    Map<int, Set<int>> allNewLinks = saved?.newLinks ?? {};

    Set<int> newlyLinked = {};
    Map<int, Set<int>> newLinks = {};
    List<GalleryDownloadedData> newlyFailed = [];

    for (int i = 0; i < galleriesToScan.length; i += 5) {
      int batchEnd = min(i + 5, galleriesToScan.length);
      List<Future<bool>> futures = [];
      for (int j = i; j < batchEnd; j++) {
        futures.add(_deepScanSingleGallery(
          galleriesToScan[j],
          url2Gallery,
          newLinks,
          newlyLinked,
        ));
      }
      List<bool> results = await Future.wait(futures);

      for (int j = 0; j < results.length; j++) {
        if (!results[j]) {
          newlyFailed.add(galleriesToScan[i + j]);
        }
      }

      deepScanCurrent = batchEnd;
      if (mounted) setState(() {});

      if (batchEnd < galleriesToScan.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // Merge this scan's new links into accumulated links
    newLinks.forEach((g1, neighbors) {
      allNewLinks.putIfAbsent(g1, () => {}).addAll(neighbors);
      for (int g2 in neighbors) {
        allNewLinks.putIfAbsent(g2, () => {}).add(g1);
      }
    });

    if (newlyLinked.isNotEmpty) {
      _mergeNewLinks(allNewLinks, newlyLinked);
    }

    failedGallerys = newlyFailed;

    await _saveScanResult(
        allNewLinks, failedGallerys.map((g) => g.gid).toList());

    if (!mounted) return;
    setState(() {
      deepScanNewLinks = newlyLinked.length;
      phase = _DialogPhase.reviewing;
    });

    if (deepScanNewLinks > 0) {
      toast('deepScanCompleted'
          .tr
          .replaceAll('\$n', deepScanNewLinks.toString()));
    } else {
      toast('deepScanNoNewLinks'.tr);
    }
  }

  Future<void> _retryFailed() async {
    if (failedGallerys.isEmpty) return;
    await _executeDeepScan(failedGallerys);
  }

  Future<bool> _deepScanSingleGallery(
    GalleryDownloadedData gallery,
    Map<String, GalleryDownloadedData> url2Gallery,
    Map<int, Set<int>> newLinks,
    Set<int> newlyLinked,
  ) async {
    GalleryUrl? galleryUrl = GalleryUrl.tryParse(gallery.galleryUrl);
    if (galleryUrl == null) return false;

    // Phase 1: try original site (5 retries)
    bool success = await _fetchAndProcessDetail(
      galleryUrl.url,
      gallery,
      url2Gallery,
      newLinks,
      newlyLinked,
    );
    if (success) return true;

    // Phase 2: fallback to opposite site (5 retries)
    GalleryUrl altUrl = galleryUrl.copyWith(isEH: !galleryUrl.isEH);
    log.warning(
        'deep scan: gallery ${gallery.gid} failed on ${galleryUrl.isEH ? "e-hentai" : "exhentai"}, trying ${altUrl.isEH ? "e-hentai" : "exhentai"}');
    return _fetchAndProcessDetail(
      altUrl.url,
      gallery,
      url2Gallery,
      newLinks,
      newlyLinked,
    );
  }

  /// Fetch detail page from the given URL and process parent/child links.
  /// Returns true on success, false on failure (after all retries).
  Future<bool> _fetchAndProcessDetail(
    String url,
    GalleryDownloadedData gallery,
    Map<String, GalleryDownloadedData> url2Gallery,
    Map<int, Set<int>> newLinks,
    Set<int> newlyLinked,
  ) async {
    try {
      ({GalleryDetail galleryDetails, String apikey}) result = await retry(
        () => ehRequest.requestDetailPage(
          galleryUrl: url,
          useCacheIfAvailable: true,
          parser: EHSpiderParser.detailPage2GalleryAndDetailAndApikey,
        ),
        retryIf: (e) => e is DioException,
        maxAttempts: 5,
      );
      GalleryDetail detail = result.galleryDetails;

      if (detail.parentGalleryUrl != null) {
        GalleryDownloadedData? parent =
            url2Gallery[detail.parentGalleryUrl!.url];
        if (parent != null && parent.gid != gallery.gid) {
          int g1 = gallery.gid;
          int g2 = parent.gid;
          newLinks.putIfAbsent(g1, () => {}).add(g2);
          newLinks.putIfAbsent(g2, () => {}).add(g1);
          newlyLinked.add(g1);
          if (ungroupedGallerys.any((g) => g.gid == g2)) {
            newlyLinked.add(g2);
          }
        }
      }

      if (detail.childrenGallerys != null) {
        for (var child in detail.childrenGallerys!) {
          GalleryDownloadedData? childGallery =
              url2Gallery[child.galleryUrl.url];
          if (childGallery != null && childGallery.gid != gallery.gid) {
            int g1 = gallery.gid;
            int g2 = childGallery.gid;
            newLinks.putIfAbsent(g1, () => {}).add(g2);
            newLinks.putIfAbsent(g2, () => {}).add(g1);
            newlyLinked.add(g1);
            if (ungroupedGallerys.any((g) => g.gid == g2)) {
              newlyLinked.add(g2);
            }
          }
        }
      }
      return true;
    } catch (e) {
      log.error('deep scan failed for gallery ${gallery.gid}', e.toString());
      return false;
    }
  }

  void _mergeNewLinks(Map<int, Set<int>> newLinks, Set<int> newlyLinked) {
    List<GalleryDownloadedData> allGallerys =
        List.of(galleryDownloadService.gallerys);
    Map<String, GalleryDownloadedData> url2Gallery = {
      for (GalleryDownloadedData g in allGallerys) g.galleryUrl: g,
    };

    _UnionFind<int> uf = _UnionFind<int>(allGallerys.map((g) => g.gid).toSet());

    for (GalleryDownloadedData g in allGallerys) {
      if (g.oldVersionGalleryUrl != null) {
        GalleryDownloadedData? parent = url2Gallery[g.oldVersionGalleryUrl];
        if (parent != null) {
          uf.union(g.gid, parent.gid);
        }
      }
    }

    newLinks.forEach((g1, neighbors) {
      for (int g2 in neighbors) {
        uf.union(g1, g2);
      }
    });

    Map<int, List<GalleryDownloadedData>> groupMap = {};
    for (GalleryDownloadedData g in allGallerys) {
      int root = uf.find(g.gid);
      groupMap.putIfAbsent(root, () => []).add(g);
    }

    List<List<GalleryDownloadedData>> groups =
        groupMap.values.where((list) => list.length > 1).map((list) {
      list.sort((a, b) => b.publishTime.compareTo(a.publishTime));
      return list;
    }).toList();

    groups.sort((a, b) => b.length.compareTo(a.length));

    Set<int> groupedGids =
        groups.expand((list) => list).map((g) => g.gid).toSet();
    for (List<GalleryDownloadedData> group in groups) {
      bool isNewGroup = !versionGroups.any((existing) =>
          existing.any((g) => group.any((g2) => g2.gid == g.gid)));
      if (isNewGroup) {
        for (int i = 1; i < group.length; i++) {
          selectedGids.add(group[i].gid);
        }
      }
    }

    ungroupedGallerys =
        allGallerys.where((g) => !groupedGids.contains(g.gid)).toList();

    versionGroups = groups;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Text('deleteHistoryVersions'.tr),
          const Spacer(),
          if (phase == _DialogPhase.reviewing &&
              ungroupedGallerys.isNotEmpty &&
              versionGroups.isNotEmpty)
            TextButton.icon(
              onPressed: _deepScan,
              icon: const Icon(Icons.travel_explore, size: 18),
              label: Text('deepScan'.tr, style: const TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
      content: SizedBox(
        width: 480,
        height: 520,
        child: _buildContent(),
      ),
      actions: _buildActions(),
      actionsPadding: const EdgeInsets.only(left: 24, right: 24, bottom: 12),
    );
  }

  Widget _buildContent() {
    switch (phase) {
      case _DialogPhase.scanning:
        return _buildScanning();
      case _DialogPhase.reviewing:
        return _buildReviewing();
      case _DialogPhase.deepScanning:
        return _buildDeepScanning();
      case _DialogPhase.deleting:
        return _buildDeleting();
      case _DialogPhase.completed:
        return _buildCompleted();
    }
  }

  Widget _buildScanning() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('scanningHistoryVersions'.tr),
        ],
      ),
    );
  }

  Widget _buildDeepScanning() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: deepScanTotal > 0 ? deepScanCurrent / deepScanTotal : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$deepScanCurrent / $deepScanTotal',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'deepScanning'.tr,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewing() {
    if (versionGroups.isEmpty && failedGallerys.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('noHistoryVersionsToDelete'.tr),
            if (ungroupedGallerys.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                '${ungroupedGallerys.length} ${'ungroupedGalleriesHint'.tr}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _deepScan,
                icon: const Icon(Icons.travel_explore, size: 18),
                label: Text('deepScan'.tr),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        _buildSelectAllBar(),
        const Divider(height: 1),
        Expanded(child: _buildGroupList()),
        if (ungroupedGallerys.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${ungroupedGallerys.length} ${'ungroupedGalleriesHint'.tr}',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSelectAllBar() {
    bool allSelected =
        _allSelectableGids.every((gid) => selectedGids.contains(gid));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: (_) => _toggleAll(),
          ),
          GestureDetector(
            onTap: _toggleAll,
            child: Text(
              allSelected ? 'deselectAll'.tr : 'selectAll'.tr,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const Spacer(),
          Text(
            '${'selected'.tr}: ${selectedGids.length}',
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupList() {
    int totalItems = versionGroups.length + (failedGallerys.isNotEmpty ? 1 : 0);

    return ListView.builder(
      itemCount: totalItems,
      itemBuilder: (context, index) {
        if (index == versionGroups.length && failedGallerys.isNotEmpty) {
          return _buildFailedGroup();
        }

        List<GalleryDownloadedData> gallerys = versionGroups[index];
        String title = gallerys.first.title;

        return ExpansionTile(
          key: ValueKey('group_$index'),
          initiallyExpanded: expandedGroups.contains(index),
          onExpansionChanged: (expanded) {
            setState(() {
              if (expanded) {
                expandedGroups.add(index);
              } else {
                expandedGroups.remove(index);
              }
            });
          },
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            '${gallerys.length} ${'versions'.tr} · ${'selected'.tr}: ${gallerys.where((g) => selectedGids.contains(g.gid)).length}',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          children: gallerys
              .map((g) => _buildGalleryItem(g, isFirst: g == gallerys.first))
              .toList(),
        );
      },
    );
  }

  Widget _buildFailedGroup() {
    return ExpansionTile(
      key: const ValueKey('failed_group'),
      initiallyExpanded: expandedGroups.contains(-1),
      onExpansionChanged: (expanded) {
        setState(() {
          if (expanded) {
            expandedGroups.add(-1);
          } else {
            expandedGroups.remove(-1);
          }
        });
      },
      title: Row(
        children: [
          Icon(Icons.error_outline,
              size: 18, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 8),
          Text(
            'failedGallerys'.tr,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${failedGallerys.length} ${'failedCount'.tr}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      children: failedGallerys
          .map((g) => _buildGalleryItem(g, isFirst: false, isFailed: true))
          .toList(),
    );
  }

  Widget _buildGalleryItem(GalleryDownloadedData gallery,
      {required bool isFirst, bool isFailed = false}) {
    bool isSelected = selectedGids.contains(gallery.gid);
    return CheckboxListTile(
      dense: true,
      value: isSelected,
      onChanged: isFailed
          ? null
          : (v) {
              setState(() {
                if (v == true) {
                  selectedGids.add(gallery.gid);
                } else {
                  selectedGids.remove(gallery.gid);
                }
              });
            },
      title: Row(
        children: [
          if (isFirst)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'newest'.tr,
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToDetails(gallery),
              child: Text(
                '${gallery.publishTime} · ${gallery.gid}',
                style: TextStyle(
                  fontSize: 13,
                  color: isFailed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: isFailed
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        '${gallery.pageCount} ${'pages'.tr}'
        '${gallery.oldVersionGalleryUrl != null ? ' · ${'linkedVersion'.tr}' : ''}',
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  void _navigateToDetails(GalleryDownloadedData gallery) {
    GalleryUrl? galleryUrl = GalleryUrl.tryParse(gallery.galleryUrl);
    if (galleryUrl == null) return;
    backRoute();
    toRoute(
      Routes.details,
      arguments: DetailsPageArgument(galleryUrl: galleryUrl),
      offAllBefore: false,
      preventDuplicates: false,
    );
  }

  Widget _buildDeleting() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator(
              value: deleteTotal > 0 ? deleteCurrent / deleteTotal : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '$deleteCurrent / $deleteTotal',
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'deletingHistoryVersions'.tr,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleted() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            '${'deleteHistoryVersionsCompleted'.tr}\n($deleteSuccess / $deleteTotal)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    switch (phase) {
      case _DialogPhase.scanning:
        return [
          TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        ];
      case _DialogPhase.reviewing:
        bool canConfirm = selectedGids.isNotEmpty;
        return [
          TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
          if (failedGallerys.isNotEmpty)
            TextButton.icon(
              onPressed: _retryFailed,
              icon: const Icon(Icons.refresh, size: 18),
              label: Text('retryFailed'.tr),
            ),
          TextButton(
            onPressed: canConfirm ? _executeDeletion : null,
            child: Text('confirm'.tr),
          ),
        ];
      case _DialogPhase.deepScanning:
        return [
          TextButton(onPressed: backRoute, child: Text('cancel'.tr)),
        ];
      case _DialogPhase.deleting:
        return [];
      case _DialogPhase.completed:
        return [
          TextButton(
              onPressed: () => backRoute(result: true), child: Text('OK'.tr)),
        ];
    }
  }

  List<int> get _allSelectableGids {
    List<int> result = [];
    for (List<GalleryDownloadedData> group in versionGroups) {
      for (int i = 1; i < group.length; i++) {
        result.add(group[i].gid);
      }
    }
    return result;
  }

  void _toggleAll() {
    setState(() {
      bool allSelected =
          _allSelectableGids.every((gid) => selectedGids.contains(gid));
      if (allSelected) {
        selectedGids.clear();
      } else {
        selectedGids = Set.from(_allSelectableGids);
      }
    });
  }

  Future<void> _executeDeletion() async {
    List<GalleryDownloadedData> toDelete = versionGroups
        .expand((list) => list)
        .where((g) => selectedGids.contains(g.gid))
        .toList();

    setState(() {
      phase = _DialogPhase.deleting;
      deleteTotal = toDelete.length;
      deleteCurrent = 0;
      deleteSuccess = 0;
    });

    for (int i = 0; i < toDelete.length; i++) {
      try {
        await galleryDownloadService.deleteGallery(toDelete[i],
            deleteImages: true);
        deleteSuccess++;
      } catch (e) {
        log.error('delete history version failed: ${toDelete[i].gid}', e);
      }
      deleteCurrent = i + 1;
      if (mounted) setState(() {});
    }

    if (mounted) {
      setState(() => phase = _DialogPhase.completed);
    }
  }
}

class _UnionFind<T> {
  final Map<T, T> _parent = {};
  final Map<T, int> _rank = {};

  _UnionFind(Set<T> elements) {
    for (T e in elements) {
      _parent[e] = e;
      _rank[e] = 0;
    }
  }

  T find(T x) {
    if (_parent[x] != x) {
      _parent[x] = find(_parent[x]!);
    }
    return _parent[x]!;
  }

  void union(T x, T y) {
    T rootX = find(x);
    T rootY = find(y);
    if (rootX == rootY) return;

    if (_rank[rootX]! < _rank[rootY]!) {
      _parent[rootX] = rootY;
    } else if (_rank[rootX]! > _rank[rootY]!) {
      _parent[rootY] = rootX;
    } else {
      _parent[rootY] = rootX;
      _rank[rootX] = _rank[rootX]! + 1;
    }
  }
}
