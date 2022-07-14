import 'package:flukit/flukit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/color_consts.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';

import 'eh_gallery_category_tag.dart';

enum EHSearchConfigDialogType { update, add, filter }

class EHSearchConfigDialog extends StatefulWidget {
  final EHSearchConfigDialogType type;
  final String? quickSearchName;
  final SearchConfig? searchConfig;

  const EHSearchConfigDialog({Key? key, required this.type, this.quickSearchName, this.searchConfig}) : super(key: key);

  @override
  _EHSearchConfigDialogState createState() => _EHSearchConfigDialogState();
}

class _EHSearchConfigDialogState extends State<EHSearchConfigDialog> {
  final ScrollController _scrollController = ScrollController();

  late final SearchConfig searchConfig;

  String? quickSearchName;

  @override
  void initState() {
    if (widget.searchConfig == null) {
      searchConfig = SearchConfig();
    } else {
      searchConfig = widget.searchConfig!.copyWith();
    }
    quickSearchName = widget.quickSearchName;
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 60.0, vertical: 24.0),
      child: Container(
        height: 500,
        width: 200,
        margin: const EdgeInsets.symmetric(vertical: 22),
        child: Column(
          children: [
            buildTitle(),
            Expanded(child: buildBody()),
          ],
        ),
      ),
    );
  }

  Widget buildTitle() {
    return AppBar(
      title: Text(_buildTitleText(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      centerTitle: true,
      automaticallyImplyLeading: false,
      toolbarHeight: 48,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => back(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.check),
          onPressed: checkAndBack,
        ).marginOnly(right: 16),
      ],
    );
  }

  String _buildTitleText() {
    switch (widget.type) {
      case EHSearchConfigDialogType.update:
        return 'updateQuickSearch'.tr;
      case EHSearchConfigDialogType.add:
        return 'addQuickSearch'.tr;
      case EHSearchConfigDialogType.filter:
        return 'filter'.tr;
    }
  }

  Widget buildBody() {
    return EHWheelSpeedController(
      scrollController: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            if (widget.type != EHSearchConfigDialogType.filter) _buildSearchConfigName().marginOnly(left: 16, right: 16),
            if (widget.type == EHSearchConfigDialogType.add) _buildSearchTypeSelector().marginOnly(top: 12),
            if (searchConfig.searchType == SearchType.favorite)
              Column(
                children: [
                  _buildFavoriteTags().marginOnly(top: 20).paddingSymmetric(horizontal: 16),
                  _buildKeywordTextField().marginOnly(left: 16, right: 16, top: 16),
                  _buildSearchNameForFavoriteSwitch().marginOnly(top: 24),
                  _buildSearchTagsForFavoriteSwitch(),
                  _buildSearchNoteForFavoriteSwitch(),
                ],
              )
            else
              Column(
                children: [
                  _buildCategoryTags().marginOnly(top: 20).paddingSymmetric(horizontal: 16),
                  _buildKeywordTextField().marginOnly(left: 16, right: 16, top: 16),
                  _buildSearchNameSwitch().marginOnly(top: 24),
                  _buildSearchTagsSwitch(),
                  _buildSearchDescriptionSwitch(),
                  _buildSearchExpungedGalleriesSwitch(),
                  _buildPageRangeSelector(),
                  _buildRatingSelector(),
                  _buildDisableFilterForLanguageSwitch(),
                  _buildDisableFilterForUploaderSwitch(),
                  _buildDisableFilterForTagsSwitch(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchConfigName() {
    return TextField(
      decoration: InputDecoration(
        isDense: true,
        alignLabelWithHint: true,
        labelText: 'quickSearchName'.tr,
        labelStyle: const TextStyle(fontSize: 12),
      ),
      controller: TextEditingController(text: quickSearchName),
      onChanged: (title) => quickSearchName = title,
    );
  }

  Widget _buildSearchTypeSelector() {
    return CupertinoSlidingSegmentedControl<SearchType>(
      groupValue: searchConfig.searchType,
      children: {
        SearchType.gallery: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Center(child: Text('gallery'.tr)),
        ),
        SearchType.favorite: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Center(child: Text('favorite'.tr)),
        ),
        SearchType.watched: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Center(child: Text('watched'.tr)),
        ),
      },
      onValueChanged: (type) => setState(() => searchConfig.searchType = type!),
    );
  }

  Widget _buildFavoriteTags() {
    return Column(
      children: [0, 2, 4, 6, 8]
          .map((tagIndex) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTag(
                    category: FavoriteSetting.favoriteTagNames[tagIndex],
                    enabled: (searchConfig.searchFavoriteCategoryIndex ?? tagIndex) == tagIndex,
                    color: ColorConsts.favoriteTagColor[tagIndex],
                    onTap: () => setState(() {
                      if (searchConfig.searchFavoriteCategoryIndex == tagIndex) {
                        searchConfig.searchFavoriteCategoryIndex = null;
                      } else {
                        searchConfig.searchFavoriteCategoryIndex = tagIndex;
                      }
                    }),
                  ),
                  _buildTag(
                    category: FavoriteSetting.favoriteTagNames[tagIndex + 1],
                    enabled: (searchConfig.searchFavoriteCategoryIndex ?? tagIndex + 1) == tagIndex + 1,
                    color: ColorConsts.favoriteTagColor[tagIndex + 1],
                    onTap: () {
                      setState(() {
                        if (searchConfig.searchFavoriteCategoryIndex == tagIndex + 1) {
                          searchConfig.searchFavoriteCategoryIndex = null;
                        } else {
                          searchConfig.searchFavoriteCategoryIndex = tagIndex + 1;
                        }
                      });
                    },
                  ),
                ],
              ).marginOnly(top: tagIndex == 0 ? 0 : 4))
          .toList(),
    );
  }

  Widget _buildKeywordTextField() {
    return TextField(
      decoration: InputDecoration(
        isDense: true,
        alignLabelWithHint: true,
        labelText: 'keyword'.tr,
        labelStyle: const TextStyle(fontSize: 12),
      ),
      controller: TextEditingController(text: searchConfig.keyword),
      onChanged: (keyword) => searchConfig.keyword = keyword,
    );
  }

  Widget _buildSearchNameForFavoriteSwitch() {
    return ListTile(
      key: const Key('searchName'),
      title: Text('searchName'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: KeepAliveWrapper(
        child: Switch(
          value: searchConfig.searchFavoriteName,
          onChanged: (bool value) => setState(() => searchConfig.searchFavoriteName = value),
        ),
      ),
    );
  }

  Widget _buildSearchTagsForFavoriteSwitch() {
    return ListTile(
      key: const Key('searchTags'),
      title: Text('searchTags'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: KeepAliveWrapper(
        child: Switch(
          value: searchConfig.searchFavoriteTags,
          onChanged: (bool value) => setState(() => searchConfig.searchFavoriteTags = value),
        ),
      ),
    );
  }

  Widget _buildSearchNoteForFavoriteSwitch() {
    return ListTile(
      key: const Key('searchNote'),
      title: Text('searchNote'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: KeepAliveWrapper(
        child: Switch(
          value: searchConfig.searchFavoriteNote,
          onChanged: (bool value) => setState(() => searchConfig.searchFavoriteNote = value),
        ),
      ),
    );
  }

  Widget _buildCategoryTags() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTag(
              category: 'Doujinshi',
              enabled: searchConfig.includeDoujinshi,
              onTap: () => setState(() => searchConfig.includeDoujinshi = !searchConfig.includeDoujinshi),
            ),
            _buildTag(
              category: 'Manga',
              enabled: searchConfig.includeManga,
              onTap: () => setState(() => searchConfig.includeManga = !searchConfig.includeManga),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTag(
              category: 'Image Set',
              enabled: searchConfig.includeImageSet,
              onTap: () => setState(() => searchConfig.includeImageSet = !searchConfig.includeImageSet),
            ),
            _buildTag(
              category: 'Game CG',
              enabled: searchConfig.includeGameCg,
              onTap: () => setState(() => searchConfig.includeGameCg = !searchConfig.includeGameCg),
            ),
          ],
        ).marginOnly(top: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTag(
              category: 'Artist CG',
              enabled: searchConfig.includeArtistCG,
              onTap: () => setState(() => searchConfig.includeArtistCG = !searchConfig.includeArtistCG),
            ),
            _buildTag(
              category: 'Cosplay',
              enabled: searchConfig.includeCosplay,
              onTap: () => setState(() => searchConfig.includeCosplay = !searchConfig.includeCosplay),
            ),
          ],
        ).marginOnly(top: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTag(
              category: 'Non-H',
              enabled: searchConfig.includeNonH,
              onTap: () => setState(() => searchConfig.includeNonH = !searchConfig.includeNonH),
            ),
            _buildTag(
              category: 'Asian Porn',
              enabled: searchConfig.includeAsianPorn,
              onTap: () => setState(() => searchConfig.includeAsianPorn = !searchConfig.includeAsianPorn),
            ),
          ],
        ).marginOnly(top: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTag(
              category: 'Western',
              enabled: searchConfig.includeWestern,
              onTap: () => setState(() => searchConfig.includeWestern = !searchConfig.includeWestern),
            ),
            _buildTag(
              category: 'Misc',
              enabled: searchConfig.includeMisc,
              onTap: () => setState(() => searchConfig.includeMisc = !searchConfig.includeMisc),
            ),
          ],
        ).marginOnly(top: 4),
      ],
    );
  }

  Widget _buildSearchNameSwitch() {
    return ListTile(
      title: Text('searchName'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: Switch(
        value: searchConfig.searchGalleryName,
        onChanged: (bool value) => setState(() => searchConfig.searchGalleryName = value),
      ),
    );
  }

  Widget _buildSearchTagsSwitch() {
    return ListTile(
      key: const Key('searchTags'),
      title: Text('searchTags'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: Switch(
        value: searchConfig.searchFavoriteTags,
        onChanged: (bool value) => setState(() => searchConfig.searchFavoriteTags = value),
      ),
    );
  }

  Widget _buildSearchDescriptionSwitch() {
    return ListTile(
      title: Text('searchGalleryDescription'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: Switch(
        value: searchConfig.searchGalleryDescription,
        onChanged: (bool value) => setState(() => searchConfig.searchGalleryDescription = value),
      ),
    );
  }

  Widget _buildSearchExpungedGalleriesSwitch() {
    return ListTile(
      title: Text('searchExpungedGalleries'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: Switch(
        value: searchConfig.searchExpungedGalleries,
        onChanged: (bool value) => setState(() => searchConfig.searchExpungedGalleries = value),
      ),
    );
  }

  Widget _buildPageRangeSelector() {
    return ListTile(
      title: Text('pagesBetween'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: SizedBox(
        width: 110,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SizedBox(
              width: 40,
              child: CupertinoTextField(
                controller: TextEditingController(text: searchConfig.pageAtLeast?.toString()),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodyText1?.color),
                onChanged: (value) => searchConfig.pageAtLeast = value.isEmpty ? null : int.parse(value),
              ),
            ),
            Text('to'.tr),
            SizedBox(
              width: 40,
              child: CupertinoTextField(
                controller: TextEditingController(text: searchConfig.pageAtMost?.toString()),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).textTheme.bodyText1?.color),
                onChanged: (value) => searchConfig.pageAtMost = value.isEmpty ? null : int.parse(value),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingSelector() {
    return ListTile(
      title: Text('minimumRating'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: SizedBox(
        width: 50,
        child: DropdownButton<int>(
          value: searchConfig.minimumRating,
          elevation: 4,
          onChanged: (int? newValue) {
            setState(() {
              searchConfig.minimumRating = newValue!;
            });
          },
          items: const [
            DropdownMenuItem(
              child: Text('1'),
              value: 1,
            ),
            DropdownMenuItem(
              child: Text('2'),
              value: 2,
            ),
            DropdownMenuItem(
              child: Text('3'),
              value: 3,
            ),
            DropdownMenuItem(
              child: Text('4'),
              value: 4,
            ),
            DropdownMenuItem(
              child: Text('5'),
              value: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisableFilterForLanguageSwitch() {
    return ListTile(
      title: Text('disableFilterForLanguage'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: Switch(
        value: searchConfig.disableFilterForLanguage,
        onChanged: (bool value) => setState(() => searchConfig.disableFilterForLanguage = value),
      ),
    );
  }

  Widget _buildDisableFilterForUploaderSwitch() {
    return ListTile(
      title: Text('disableFilterForUploader'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: Switch(
        value: searchConfig.disableFilterForUploader,
        onChanged: (bool value) => setState(() => searchConfig.disableFilterForUploader = value),
      ),
    );
  }

  Widget _buildDisableFilterForTagsSwitch() {
    return ListTile(
      title: Text('disableFilterForTags'.tr, style: const TextStyle(fontSize: 15)),
      dense: true,
      trailing: Switch(
        value: searchConfig.disableFilterForTags,
        onChanged: (bool value) => setState(() => searchConfig.disableFilterForTags = value),
      ),
    );
  }

  Widget _buildTag({required String category, required bool enabled, Color? color, VoidCallback? onTap}) {
    return EHGalleryCategoryTag(
      category: category,
      width: 115,
      height: 30,
      enabled: enabled,
      color: color,
      textStyle: const TextStyle(height: 1, fontSize: 16, color: Colors.white),
      onTap: onTap,
    );
  }

  void checkAndBack() {
    if (widget.type == EHSearchConfigDialogType.filter) {
      back(result: {'searchConfig': searchConfig, 'quickSearchName': quickSearchName});
      return;
    }

    if (quickSearchName?.isEmpty ?? true) {
      toast('pleaseInputValidName'.tr);
      return;
    }

    back(result: {'searchConfig': searchConfig, 'quickSearchName': quickSearchName});
  }
}
