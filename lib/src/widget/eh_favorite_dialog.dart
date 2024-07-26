import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/extension/dio_exception_extension.dart';
import 'package:jhentai/src/model/gallery_note.dart';
import 'package:jhentai/src/setting/preference_setting.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/loading_state_indicator.dart';

import '../exception/eh_site_exception.dart';
import '../setting/favorite_setting.dart';
import '../service/log.dart';
import '../utils/route_util.dart';
import '../utils/snack_util.dart';

typedef GalleryNoteFetchFunction = Future<GalleryNote> Function();

class EHFavoriteDialog extends StatefulWidget {
  final int? selectedIndex;
  final bool needInitNote;
  final GalleryNoteFetchFunction? initNoteFuture;

  const EHFavoriteDialog({
    Key? key,
    this.selectedIndex,
    this.needInitNote = false,
    this.initNoteFuture,
  })  : assert(needInitNote == false || initNoteFuture != null),
        super(key: key);

  @override
  State<EHFavoriteDialog> createState() => _EHFavoriteDialogState();
}

class _EHFavoriteDialogState extends State<EHFavoriteDialog> {
  int? selectedIndex;

  final TextEditingController _controller = TextEditingController();

  bool remember = false;

  bool inNoteMode = false;

  LoadingState _loadingState = LoadingState.idle;

  @override
  void initState() {
    selectedIndex = widget.selectedIndex;
    if (widget.needInitNote) {
      _initFavoriteNote();
    } else {
      _loadingState = LoadingState.success;
    }

    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Center(child: Text('chooseFavorite'.tr)),
      children: [
        LoadingStateIndicator(
          loadingState: _loadingState,
          errorTapCallback: _initFavoriteNote,
          successWidgetBuilder: () => Obx(
            () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...FavoriteSetting.favoriteTagNames
                    .mapIndexed(
                      (index, tagName) => ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        selected: selectedIndex == index,
                        selectedTileColor: UIConfig.favoriteDialogTileColor(context),
                        leading: Text(
                          tagName,
                          style: const TextStyle(fontSize: UIConfig.favoriteDialogLeadingTextSize),
                        ),
                        trailing: Text(
                          FavoriteSetting.favoriteCounts[index].toString(),
                          style: TextStyle(fontSize: UIConfig.favoriteDialogTrailingTextSize, color: UIConfig.favoriteDialogCountTextColor(context)),
                        ),
                        onTap: () {
                          backRoute(
                            result: (
                              isDelete: index == selectedIndex,
                              favIndex: index,
                              note: _controller.text,
                              remember: remember,
                            ),
                          );
                        },
                      ),
                    )
                    .toList(),
                const Divider(height: 12),
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 12, right: 12),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (PreferenceSetting.enableDefaultFavorite.isTrue) Text('asYourDefault'.tr),
                      if (PreferenceSetting.enableDefaultFavorite.isTrue) Checkbox(value: remember, onChanged: (value) => setState(() => remember = value!)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_note),
                    onPressed: () {
                      setState(() {
                        inNoteMode = !inNoteMode;
                      });
                    },
                  ),
                ).marginOnly(top: 4),
                if (inNoteMode)
                  Row(
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 160),
                          child: TextField(
                            controller: _controller,
                            inputFormatters: [LengthLimitingTextInputFormatter(200)],
                            style: const TextStyle(fontSize: 12),
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(isDense: true),
                          ),
                        ).paddingOnly(left: 8),
                      ),
                      TextButton(
                        child: Text('OK'.tr),
                        onPressed: () {
                          if (selectedIndex == null) {
                            toast('addNoteHint'.tr);
                            return;
                          }

                          backRoute(
                            result: (
                              isDelete: false,
                              favIndex: selectedIndex,
                              note: _controller.text,
                              remember: remember,
                            ),
                          );
                        },
                      ),
                    ],
                  ).marginOnly(top: 4, bottom: 4),
              ],
            ),
          ),
        ),
      ],
      contentPadding: const EdgeInsets.only(top: 18, left: 12, right: 12, bottom: 12),
    );
  }

  Future<void> _initFavoriteNote() async {
    assert(widget.initNoteFuture != null);

    if (_loadingState == LoadingState.loading) {
      return;
    }
    setState(() => _loadingState = LoadingState.loading);

    log.info('Get gallery favorite info');
    GalleryNote note;
    try {
      note = await widget.initNoteFuture!();
      _controller.text = note.note;
      setState(() {
        if (_controller.text.isNotEmpty) {
          inNoteMode = true;
        }
        _loadingState = LoadingState.success;
      });
    } on DioException catch (e) {
      log.error('getGalleryFavoriteInfoFailed'.tr, e.errorMsg);
      snack('getGalleryFavoriteInfoFailed'.tr, e.errorMsg ?? '', isShort: true);
      setState(() => _loadingState = LoadingState.error);
      return;
    } on EHSiteException catch (e) {
      log.error('getGalleryFavoriteInfoFailed'.tr, e.message);
      snack('getGalleryFavoriteInfoFailed'.tr, e.message, isShort: true);
      setState(() => _loadingState = LoadingState.error);
      return;
    } catch (e, s) {
      log.error('getGalleryFavoriteInfoFailed'.tr, e, s);
      snack('getGalleryFavoriteInfoFailed'.tr, e.toString(), isShort: true);
      setState(() => _loadingState = LoadingState.error);
      return;
    }
  }
}
