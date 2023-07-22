import 'package:animate_do/animate_do.dart';
import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/consts/color_consts.dart';
import 'package:jhentai/src/extension/widget_extension.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/service/quick_search_service.dart';
import 'package:jhentai/src/service/tag_translation_service.dart';
import 'package:jhentai/src/setting/favorite_setting.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/toast_util.dart';
import 'package:jhentai/src/widget/eh_alert_dialog.dart';
import 'package:jhentai/src/widget/eh_wheel_speed_controller.dart';
import 'package:throttling/throttling.dart';

import '../config/ui_config.dart';
import '../consts/locale_consts.dart';
import '../database/database.dart';
import '../network/eh_request.dart';
import '../utils/eh_spider_parser.dart';
import '../utils/log.dart';
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
  final QuickSearchService quickSearchService = Get.find<QuickSearchService>();
  final TagTranslationService tagTranslationService = Get.find<TagTranslationService>();

  String? quickSearchName;
  late SearchConfig searchConfig;

  final ScrollController _bodyScrollController = ScrollController();
  final ScrollController _suggestionScrollController = ScrollController();

  bool _isShowingSuggestions = false;
  List<TagData> suggestions = [];
  Debouncing debouncing = Debouncing(duration: const Duration(milliseconds: 300));

  LayerLink layerLink = LayerLink();
  OverlayEntry? overlayEntry;
  FocusNode focusNode = FocusNode();
  bool isDoubleBackspace = false;

  @override
  void initState() {
    super.initState();

    if (widget.searchConfig == null) {
      searchConfig = SearchConfig();
    } else {
      searchConfig = widget.searchConfig!.copyWith();
    }

    quickSearchName = widget.quickSearchName;
  }

  @override
  void dispose() {
    super.dispose();
    _bodyScrollController.dispose();
    _suggestionScrollController.dispose();
    overlayEntry?.remove();
    overlayEntry?.dispose();
    focusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: UIConfig.scrollBehaviourWithoutScrollBar,
      child: Dialog(
        child: Container(
          height: searchConfig.searchType == SearchType.favorite ? 400 : 500,
          width: 200,
          padding: const EdgeInsets.only(top: 24, bottom: 24, left: 12, right: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildHeader(),
              Expanded(child: buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildHeader() {
    String title = () {
      switch (widget.type) {
        case EHSearchConfigDialogType.update:
          return 'updateQuickSearch'.tr;
        case EHSearchConfigDialogType.add:
          return 'addQuickSearch'.tr;
        case EHSearchConfigDialogType.filter:
          return 'filter'.tr;
      }
    }();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (widget.type == EHSearchConfigDialogType.update) IconButton(icon: const Icon(Icons.delete), onPressed: _handleDeleteConfig),
        if (widget.type == EHSearchConfigDialogType.filter) IconButton(icon: const Icon(Icons.refresh), onPressed: _resetAllConfig),
        if (widget.type == EHSearchConfigDialogType.add) const IconButton(icon: Icon(Icons.close), onPressed: backRoute),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        IconButton(icon: const Icon(Icons.check), onPressed: checkAndBack),
      ],
    );
  }

  Widget buildBody() {
    return EHWheelSpeedController(
      controller: _bodyScrollController,
      child: ListView(
        controller: _bodyScrollController,
        cacheExtent: 3000,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          if (widget.type != EHSearchConfigDialogType.filter) _buildSearchConfigName(),
          if (widget.type == EHSearchConfigDialogType.add) _buildSearchTypeSelector().marginOnly(top: 16),
          if (searchConfig.searchType == SearchType.favorite)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFavoriteTags().marginOnly(top: 20),
                _buildKeywordTextField().marginOnly(top: 20, bottom: 180),
              ],
            )
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCategoryTags().marginOnly(top: 20),
                _buildKeywordTextField().marginOnly(top: 12),
                _buildLanguageSelector().marginOnly(top: 20),
                _buildSearchExpungedGalleriesSwitch(),
                _buildOnlySearchGallerysWithTorrentsSwitch(),
                _buildSearchLowerTagsSwitch(),
                _buildPageRangeSelector(),
                _buildRatingSelector(),
                _buildDisableFilterForLanguageSwitch(),
                _buildDisableFilterForUploaderSwitch(),
                _buildDisableFilterForTagsSwitch(),
              ],
            ),
        ],
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
    return Center(
      child: CupertinoSlidingSegmentedControl<SearchType>(
        groupValue: searchConfig.searchType,
        children: {
          SearchType.gallery: ConstrainedBox(constraints: const BoxConstraints(minWidth: 44), child: Center(child: Text('gallery'.tr))),
          SearchType.favorite: ConstrainedBox(constraints: const BoxConstraints(minWidth: 44), child: Center(child: Text('favorite'.tr))),
          SearchType.watched: ConstrainedBox(constraints: const BoxConstraints(minWidth: 44), child: Center(child: Text('watched'.tr))),
        },
        onValueChanged: (type) => setState(() => searchConfig.searchType = type!),
      ),
    );
  }

  Widget _buildFavoriteTags() {
    return Column(
      children: [0, 2, 4, 6, 8]
          .map((tagIndex) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
    return CompositedTransformTarget(
      link: layerLink,
      child: KeyboardListener(
        focusNode: focusNode,
        onKeyEvent: _handleDeleteTag,
        child: TextField(
          decoration: InputDecoration(
            isDense: true,
            alignLabelWithHint: true,
            labelText: 'keyword'.tr,
            labelStyle: const TextStyle(fontSize: 12),
            helperText: searchConfig.computeTagKeywords(withTranslation: true, separator: '  /  '),
            helperMaxLines: 99,
            hintText: searchConfig.tags?.isEmpty ?? true ? null : 'backspace2DeleteTag'.tr,
            hintStyle: TextStyle(fontSize: 12, color: UIConfig.searchConfigDialogFieldHintTextColor(context)),
          ),
          controller: TextEditingController.fromValue(
            TextEditingValue(
              text: searchConfig.keyword ?? '',

              /// make cursor stay at last letter
              selection: TextSelection.fromPosition(TextPosition(offset: searchConfig.keyword?.length ?? 0)),
            ),
          ),
          onTap: hideSuggestions,
          enableSuggestions: false,
          onChanged: (keyword) {
            searchConfig.keyword = keyword;
            waitAndSearchTags(keyword);
          },
          onSubmitted: (keyword) {
            searchConfig.keyword = '';
            hideSuggestions();

            if (keyword.isEmpty) {
              return;
            }

            /// simulate a TagData
            addSearchTag(TagData(namespace: '', key: keyword));
          },
        ),
      ),
    );
  }

  OverlayEntry _buildSuggestions(String keyword) {
    return OverlayEntry(
      builder: (BuildContext overlayContext) => UnconstrainedBox(
        child: CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          child: Material(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280 - 24 - 20, maxHeight: 150),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: UIConfig.searchConfigDialogSuggestionShadowColor(overlayContext),
                    blurRadius: 4,
                    blurStyle: BlurStyle.outer,
                  )
                ],
              ),
              child: SearchSuggestionList(
                scrollController: _suggestionScrollController,
                currentKeyword: keyword,
                suggestions: suggestions,
                onTapSuggestion: (TagData tagData) {
                  hideSuggestions();
                  searchConfig.keyword = '';
                  addSearchTag(tagData);
                },
              ),
            ).fadeIn(),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTags() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  Widget _buildLanguageSelector() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('language'.tr, style: const TextStyle(fontSize: 15)),
      trailing: DropdownButton<String?>(
        value: searchConfig.language,
        elevation: 4,
        alignment: AlignmentDirectional.centerEnd,
        onChanged: (String? newValue) => setState(() => searchConfig.language = newValue),
        menuMaxHeight: 200,
        items: [
          DropdownMenuItem(child: Text('nope'.tr), value: null),
          ...LocaleConsts.language2Abbreviation.keys
              .where((language) => language != 'japanese')
              .map((language) => DropdownMenuItem(child: Text(language.capitalizeFirst!), value: language))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildSearchExpungedGalleriesSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('onlySearchExpungedGalleries'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: searchConfig.onlySearchExpungedGalleries,
        onChanged: (bool value) => setState(() => searchConfig.onlySearchExpungedGalleries = value),
      ),
    );
  }

  Widget _buildOnlySearchGallerysWithTorrentsSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('onlyShowGalleriesWithTorrents'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: searchConfig.onlyShowGalleriesWithTorrents,
        onChanged: (bool value) => setState(() => searchConfig.onlyShowGalleriesWithTorrents = value),
      ),
    );
  }

  Widget _buildSearchLowerTagsSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('searchLowPowerTags'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: searchConfig.searchLowPowerTags,
        onChanged: (bool value) => setState(() => searchConfig.searchLowPowerTags = value),
      ),
    );
  }

  Widget _buildPageRangeSelector() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('pagesBetween'.tr, style: const TextStyle(fontSize: 15)),
          GestureDetector(
            child: const Icon(Icons.help, size: 15).marginOnly(left: 4),
            onTap: () => toast('pageRangeSelectHint'.tr, isShort: false),
          ),
        ],
      ),
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
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
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
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('minimumRating'.tr, style: const TextStyle(fontSize: 15)),
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
            DropdownMenuItem(child: Text('1'), value: 1),
            DropdownMenuItem(child: Text('2'), value: 2),
            DropdownMenuItem(child: Text('3'), value: 3),
            DropdownMenuItem(child: Text('4'), value: 4),
            DropdownMenuItem(child: Text('5'), value: 5),
          ],
        ),
      ),
    );
  }

  Widget _buildDisableFilterForLanguageSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('disableFilterForLanguage'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: searchConfig.disableFilterForLanguage,
        onChanged: (bool value) => setState(() => searchConfig.disableFilterForLanguage = value),
      ),
    );
  }

  Widget _buildDisableFilterForUploaderSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('disableFilterForUploader'.tr, style: const TextStyle(fontSize: 15)),
      trailing: Switch(
        value: searchConfig.disableFilterForUploader,
        onChanged: (bool value) => setState(() => searchConfig.disableFilterForUploader = value),
      ),
    );
  }

  Widget _buildDisableFilterForTagsSwitch() {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('disableFilterForTags'.tr, style: const TextStyle(fontSize: 15)),
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
      textStyle: const TextStyle(height: 1, fontSize: 16, color: UIConfig.galleryCategoryTagTextColor),
      onTap: onTap,
    );
  }

  void _resetAllConfig() {
    setState(() {
      searchConfig = SearchConfig(searchType: searchConfig.searchType);
      suggestions.clear();
      isDoubleBackspace = false;
    });
  }

  Future<void> _handleDeleteConfig() async {
    bool? result = await Get.dialog(EHDialog(title: 'delete'.tr + '?'));

    if (result == true) {
      quickSearchService.removeQuickSearch(quickSearchName!);
      backRoute();
    }
  }

  /// double backspace to delete last selected tag
  void _handleDeleteTag(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return;
    }
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return;
    }
    if (searchConfig.keyword?.isNotEmpty ?? false) {
      return;
    }
    if (searchConfig.tags?.isEmpty ?? true) {
      return;
    }
    if (!isDoubleBackspace) {
      isDoubleBackspace = true;
      return;
    }
    isDoubleBackspace = false;
    setState(() => searchConfig.tags!.removeLast());
  }

  /// search only if there's no timer active (300ms)
  Future<void> waitAndSearchTags(String keyword) async {
    if (keyword.isEmpty) {
      hideSuggestions();
      return;
    }

    /// only search after 300ms
    debouncing.debounce(() => searchTags(keyword));
  }

  Future<void> searchTags(String keyword) async {
    Log.info('search for ${searchConfig.keyword}');

    /// chinese => database
    /// other => EH api
    if (tagTranslationService.isReady) {
      suggestions = await tagTranslationService.searchTags(keyword);
    } else {
      try {
        suggestions = await EHRequest.requestTagSuggestion(keyword, EHSpiderParser.tagSuggestion2TagList);
      } on DioError catch (e) {
        Log.error('Request tag suggestion failed', e);
      }
    }

    showSuggestions(keyword);
  }

  void showSuggestions(String keyword) {
    if (_isShowingSuggestions) {
      overlayEntry?.remove();
    }

    overlayEntry = _buildSuggestions(keyword);
    Overlay.of(context).insert(overlayEntry!);

    _isShowingSuggestions = true;
  }

  void hideSuggestions() {
    overlayEntry?.remove();
    overlayEntry = null;
    _isShowingSuggestions = false;
  }

  void addSearchTag(TagData tag) {
    searchConfig.tags ??= [];
    if (searchConfig.tags!.singleWhereOrNull((t) => t.namespace == tag.namespace && t.key == tag.key) != null) {
      return;
    }

    setState(() {
      searchConfig.tags!.add(tag);
    });
  }

  void checkAndBack() {
    if (widget.type == EHSearchConfigDialogType.filter) {
      backRoute(result: {'searchConfig': searchConfig, 'quickSearchName': quickSearchName});
      return;
    }

    if (quickSearchName?.isEmpty ?? true) {
      toast('pleaseInputValidName'.tr);
      return;
    }

    backRoute(result: {'searchConfig': searchConfig, 'quickSearchName': quickSearchName});
  }
}

class SearchSuggestionList extends StatelessWidget {
  final String currentKeyword;
  final List<TagData> suggestions;
  final ValueChanged<TagData> onTapSuggestion;
  final ScrollController scrollController;

  const SearchSuggestionList({
    Key? key,
    required this.currentKeyword,
    required this.suggestions,
    required this.onTapSuggestion,
    required this.scrollController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EHWheelSpeedController(
      controller: scrollController,
      child: ListView.builder(
        itemCount: suggestions.length,
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        controller: scrollController,
        itemBuilder: (_, index) {
          TagData tagData = suggestions[index];
          return FadeIn(
            duration: const Duration(milliseconds: 400),
            child: ListTile(
              dense: true,
              visualDensity: const VisualDensity(vertical: -4),
              minVerticalPadding: 0,
              title: RichText(
                text: highlightKeyword(context, '${tagData.namespace} : ${tagData.key}', currentKeyword, false),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: tagData.tagName == null
                  ? null
                  : RichText(
                      text: highlightKeyword(context, '${tagData.namespace.tr} : ${tagData.tagName}', currentKeyword, true),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => onTapSuggestion(tagData),
            ),
          );
        },
      ),
    );
  }

  /// highlight keyword in rawText
  TextSpan highlightKeyword(BuildContext context, String rawText, String currentKeyword, bool isSubTitle) {
    List<TextSpan> children = <TextSpan>[];

    List<int> matchIndexes = currentKeyword.allMatches(rawText).map((match) => match.start).toList();

    int indexHandling = 0;
    for (int index in matchIndexes) {
      if (index > indexHandling) {
        children.add(
          TextSpan(
            text: rawText.substring(indexHandling, index),
            style: TextStyle(
              fontSize: isSubTitle ? UIConfig.searchDialogSuggestionSubTitleTextSize : UIConfig.searchDialogSuggestionTitleTextSize,
              color: isSubTitle ? UIConfig.searchPageSuggestionSubTitleColor(context) : UIConfig.searchPageSuggestionTitleColor(context),
            ),
          ),
        );
      }

      children.add(
        TextSpan(
          text: currentKeyword,
          style: TextStyle(
            fontSize: isSubTitle ? UIConfig.searchDialogSuggestionSubTitleTextSize : UIConfig.searchDialogSuggestionTitleTextSize,
            color: UIConfig.searchPageSuggestionHighlightColor,
          ),
        ),
      );

      indexHandling = index + currentKeyword.length;
    }

    if (rawText.length > indexHandling) {
      children.add(
        TextSpan(
          text: rawText.substring(indexHandling, rawText.length),
          style: TextStyle(
            fontSize: isSubTitle ? UIConfig.searchDialogSuggestionSubTitleTextSize : UIConfig.searchDialogSuggestionTitleTextSize,
            color: isSubTitle ? UIConfig.searchPageSuggestionSubTitleColor(context) : UIConfig.searchPageSuggestionTitleColor(context),
          ),
        ),
      );
    }

    return TextSpan(children: children);
  }
}
