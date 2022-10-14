import 'package:jhentai/src/consts/eh_consts.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:json_annotation/json_annotation.dart';

enum SearchType {
  gallery,
  popular,
  favorite,
  watched,
  history,
}

@JsonSerializable()
class SearchConfig {
  SearchType searchType = SearchType.gallery;

  bool includeDoujinshi = true;
  bool includeManga = true;
  bool includeArtistCG = true;
  bool includeGameCg = true;
  bool includeWestern = true;
  bool includeNonH = true;
  bool includeImageSet = true;
  bool includeCosplay = true;
  bool includeAsianPorn = true;
  bool includeMisc = true;

  String? keyword;
  List<TagData>? tags;

  bool searchGalleryName = true;
  bool searchGalleryTags = true;
  bool searchGalleryDescription = false;
  bool searchExpungedGalleries = false;
  bool onlyShowGalleriesWithTorrents = false;
  bool searchLowPowerTags = false;
  bool searchDownVotedTags = false;

  int? pageAtLeast;
  int? pageAtMost;

  int minimumRating = 1;

  bool disableFilterForLanguage = false;
  bool disableFilterForUploader = false;
  bool disableFilterForTags = false;

  /// Favorite
  int? searchFavoriteCategoryIndex;
  bool searchFavoriteName = true;
  bool searchFavoriteTags = true;
  bool searchFavoriteNote = true;

  SearchConfig({
    this.searchType = SearchType.gallery,
    this.includeDoujinshi = true,
    this.includeManga = true,
    this.includeArtistCG = true,
    this.includeGameCg = true,
    this.includeWestern = true,
    this.includeNonH = true,
    this.includeImageSet = true,
    this.includeCosplay = true,
    this.includeAsianPorn = true,
    this.includeMisc = true,
    this.keyword,
    this.tags,
    this.searchGalleryName = true,
    this.searchGalleryTags = true,
    this.searchGalleryDescription = false,
    this.searchExpungedGalleries = false,
    this.onlyShowGalleriesWithTorrents = false,
    this.searchLowPowerTags = false,
    this.searchDownVotedTags = false,
    this.pageAtLeast,
    this.pageAtMost,
    this.minimumRating = 1,
    this.disableFilterForLanguage = false,
    this.disableFilterForUploader = false,
    this.disableFilterForTags = false,
    this.searchFavoriteCategoryIndex,
    this.searchFavoriteName = true,
    this.searchFavoriteTags = true,
    this.searchFavoriteNote = true,
  });

  /// search path
  String toPath() {
    switch (searchType) {
      case SearchType.gallery:
        return EHConsts.EIndex;
      case SearchType.popular:
        return EHConsts.EPopular;
      case SearchType.favorite:
        return EHConsts.EFavorite;
      case SearchType.watched:
        return EHConsts.EWatched;
      case SearchType.history:
        return '';
    }
  }

  /// search params
  Map<String, dynamic> toQueryParameters() {
    Map<String, dynamic> params = {};

    if (searchType == SearchType.gallery) {
      params['advsearch'] = 1;
      params['f_cats'] = _computeFCats();
      if (keyword != null || (tags?.isNotEmpty ?? false)) {
        params['f_search'] = computeKeywords();
      }
      if (searchGalleryName) {
        params['f_sname'] = 'on';
      }
      if (searchGalleryTags) {
        params['f_stags'] = 'on';
      }
      if (searchGalleryDescription) {
        params['f_sdesc'] = 'on';
      }
      if (searchExpungedGalleries) {
        params['f_sh'] = 'on';
      }
      if (onlyShowGalleriesWithTorrents) {
        params['f_sto'] = 'on';
      }
      if (searchLowPowerTags) {
        params['f_sdt1'] = 'on';
      }
      if (searchDownVotedTags) {
        params['f_sdt2'] = 'on';
      }
      if (pageAtLeast != null) {
        params['f_spf'] = pageAtLeast;
      }
      if (pageAtMost != null && (pageAtLeast == null || pageAtMost! >= pageAtLeast!)) {
        params['f_spt'] = pageAtMost;
      }
      if (minimumRating > 1) {
        params['f_sr'] = 'on';
        params['f_srdd'] = minimumRating;
      }
      if (disableFilterForLanguage) {
        params['f_sfl'] = 'on';
      }
      if (disableFilterForUploader) {
        params['f_sfu'] = 'on';
      }
      if (disableFilterForTags) {
        params['f_sft'] = 'on';
      }
    }

    if (searchType == SearchType.favorite) {
      if (keyword != null) {
        params['f_search'] = keyword;
      }

      if (searchFavoriteCategoryIndex != null) {
        params['favcat'] = searchFavoriteCategoryIndex;
      }
      if (searchFavoriteName) {
        params['sn'] = 'on';
      }
      if (searchFavoriteTags) {
        params['st'] = 'on';
      }
      if (searchFavoriteNote) {
        params['sf'] = 'on';
      }
    }

    return params;
  }

  String computeKeywords() {
    return (keyword ?? '') + toTagKeywords(withTranslation: false, separator: ' ');
  }

  String toTagKeywords({required bool withTranslation, required String separator}) {
    List<String> strs = [];

    tags?.forEach((tag) {
      /// manual input
      if (tag.namespace.isEmpty) {
        strs.add(tag.key);
        return;
      }

      if (withTranslation && tag.tagName != null) {
        strs.add('${tag.translatedNamespace}:${tag.tagName}');
        return;
      }

      strs.add('${tag.namespace}:${tag.key}');
    });

    return strs.join(separator);
  }

  int _computeFCats() {
    int fCats = 0;
    if (!includeMisc) {
      fCats += 1;
    }
    if (!includeDoujinshi) {
      fCats += 2;
    }
    if (!includeManga) {
      fCats += 4;
    }
    if (!includeArtistCG) {
      fCats += 8;
    }
    if (!includeGameCg) {
      fCats += 16;
    }
    if (!includeImageSet) {
      fCats += 32;
    }
    if (!includeCosplay) {
      fCats += 64;
    }
    if (!includeAsianPorn) {
      fCats += 128;
    }
    if (!includeNonH) {
      fCats += 256;
    }
    if (!includeWestern) {
      fCats += 512;
    }
    return fCats;
  }

  factory SearchConfig.fromJson(Map<String, dynamic> json) {
    return SearchConfig(
      searchType: SearchType.values[json["searchType"]],
      includeDoujinshi: json["includeDoujinshi"],
      includeManga: json["includeManga"],
      includeArtistCG: json["includeArtistCG"],
      includeGameCg: json["includeGameCg"],
      includeWestern: json["includeWestern"],
      includeNonH: json["includeNonH"],
      includeImageSet: json["includeImageSet"],
      includeCosplay: json["includeCosplay"],
      includeAsianPorn: json["includeAsianPorn"],
      includeMisc: json["includeMisc"],
      keyword: json["keyword"],
      tags: (json["tags"] as List?)?.map((e) => TagData.fromJson(e)).toList(),
      searchGalleryName: json["searchGalleryName"],
      searchGalleryTags: json["searchGalleryTags"],
      searchGalleryDescription: json["searchGalleryDescription"],
      searchExpungedGalleries: json["searchExpungedGalleries"],
      onlyShowGalleriesWithTorrents: json["onlyShowGalleriesWithTorrents"],
      searchLowPowerTags: json["searchLowPowerTags"],
      searchDownVotedTags: json["searchDownVotedTags"],
      pageAtLeast: json["pageAtLeast"],
      pageAtMost: json["pageAtMost"],
      minimumRating: json["minimumRating"],
      disableFilterForLanguage: json["disableFilterForLanguage"],
      disableFilterForUploader: json["disableFilterForUploader"],
      disableFilterForTags: json["disableFilterForTags"],
      searchFavoriteCategoryIndex: json["searchFavoriteCategoryIndex"],
      searchFavoriteName: json["searchFavoriteName"],
      searchFavoriteTags: json["searchFavoriteTags"],
      searchFavoriteNote: json["searchFavoriteNote"],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "searchType": searchType.index,
      "includeDoujinshi": includeDoujinshi,
      "includeManga": includeManga,
      "includeArtistCG": includeArtistCG,
      "includeGameCg": includeGameCg,
      "includeWestern": includeWestern,
      "includeNonH": includeNonH,
      "includeImageSet": includeImageSet,
      "includeCosplay": includeCosplay,
      "includeAsianPorn": includeAsianPorn,
      "includeMisc": includeMisc,
      "keyword": keyword,
      "tags": tags,
      "searchGalleryName": searchGalleryName,
      "searchGalleryTags": searchGalleryTags,
      "searchGalleryDescription": searchGalleryDescription,
      "searchExpungedGalleries": searchExpungedGalleries,
      "onlyShowGalleriesWithTorrents": onlyShowGalleriesWithTorrents,
      "searchLowPowerTags": searchLowPowerTags,
      "searchDownVotedTags": searchDownVotedTags,
      "pageAtLeast": pageAtLeast,
      "pageAtMost": pageAtMost,
      "minimumRating": minimumRating,
      "disableFilterForLanguage": disableFilterForLanguage,
      "disableFilterForUploader": disableFilterForUploader,
      "disableFilterForTags": disableFilterForTags,
      "searchFavoriteCategoryIndex": searchFavoriteCategoryIndex,
      "searchFavoriteName": searchFavoriteName,
      "searchFavoriteTags": searchFavoriteTags,
      "searchFavoriteNote": searchFavoriteNote,
    };
  }

  SearchConfig copyWith({
    SearchType? searchType,
    bool? includeDoujinshi,
    bool? includeManga,
    bool? includeArtistCG,
    bool? includeGameCg,
    bool? includeWestern,
    bool? includeNonH,
    bool? includeImageSet,
    bool? includeCosplay,
    bool? includeAsianPorn,
    bool? includeMisc,
    String? keyword,
    List<TagData>? tags,
    bool? searchGalleryName,
    bool? searchGalleryTags,
    bool? searchGalleryDescription,
    bool? searchExpungedGalleries,
    bool? onlyShowGalleriesWithTorrents,
    bool? searchLowPowerTags,
    bool? searchDownVotedTags,
    int? pageAtLeast,
    int? pageAtMost,
    int? minimumRating,
    bool? disableFilterForLanguage,
    bool? disableFilterForUploader,
    bool? disableFilterForTags,
    bool? searchFavoriteName,
    bool? searchFavoriteTags,
    bool? searchFavoriteNote,
  }) {
    return SearchConfig(
      searchType: searchType ?? this.searchType,
      includeDoujinshi: includeDoujinshi ?? this.includeDoujinshi,
      includeManga: includeManga ?? this.includeManga,
      includeArtistCG: includeArtistCG ?? this.includeArtistCG,
      includeGameCg: includeGameCg ?? this.includeGameCg,
      includeWestern: includeWestern ?? this.includeWestern,
      includeNonH: includeNonH ?? this.includeNonH,
      includeImageSet: includeImageSet ?? this.includeImageSet,
      includeCosplay: includeCosplay ?? this.includeCosplay,
      includeAsianPorn: includeAsianPorn ?? this.includeAsianPorn,
      includeMisc: includeMisc ?? this.includeMisc,
      keyword: keyword ?? this.keyword,
      tags: tags ?? this.tags?.map((tag) => tag.copyWith()).toList(),
      searchGalleryName: searchGalleryName ?? this.searchGalleryName,
      searchGalleryTags: searchGalleryTags ?? this.searchGalleryTags,
      searchGalleryDescription: searchGalleryDescription ?? this.searchGalleryDescription,
      searchExpungedGalleries: searchExpungedGalleries ?? this.searchExpungedGalleries,
      onlyShowGalleriesWithTorrents: onlyShowGalleriesWithTorrents ?? this.onlyShowGalleriesWithTorrents,
      searchLowPowerTags: searchLowPowerTags ?? this.searchLowPowerTags,
      searchDownVotedTags: searchDownVotedTags ?? this.searchDownVotedTags,
      pageAtLeast: pageAtLeast ?? this.pageAtLeast,
      pageAtMost: pageAtMost ?? this.pageAtMost,
      minimumRating: minimumRating ?? this.minimumRating,
      disableFilterForLanguage: disableFilterForLanguage ?? this.disableFilterForLanguage,
      disableFilterForUploader: disableFilterForUploader ?? this.disableFilterForUploader,
      disableFilterForTags: disableFilterForTags ?? this.disableFilterForTags,
      searchFavoriteCategoryIndex: searchFavoriteCategoryIndex ?? searchFavoriteCategoryIndex,
      searchFavoriteName: searchFavoriteName ?? this.searchFavoriteName,
      searchFavoriteTags: searchFavoriteTags ?? this.searchFavoriteTags,
      searchFavoriteNote: searchFavoriteNote ?? this.searchFavoriteNote,
    );
  }

  @override
  String toString() {
    return 'SearchConfig{searchType: $searchType, includeDoujinshi: $includeDoujinshi, includeManga: $includeManga, includeArtistCG: $includeArtistCG, includeGameCg: $includeGameCg, includeWestern: $includeWestern, includeNonH: $includeNonH, includeImageSet: $includeImageSet, includeCosplay: $includeCosplay, includeAsianPorn: $includeAsianPorn, includeMisc: $includeMisc, keyword: $keyword, tags: $tags, searchGalleryName: $searchGalleryName, searchGalleryTags: $searchGalleryTags, searchGalleryDescription: $searchGalleryDescription, searchExpungedGalleries: $searchExpungedGalleries, onlyShowGalleriesWithTorrents: $onlyShowGalleriesWithTorrents, searchLowPowerTags: $searchLowPowerTags, searchDownVotedTags: $searchDownVotedTags, pageAtLeast: $pageAtLeast, pageAtMost: $pageAtMost, minimumRating: $minimumRating, disableFilterForLanguage: $disableFilterForLanguage, disableFilterForUploader: $disableFilterForUploader, disableFilterForTags: $disableFilterForTags, searchFavoriteCategoryIndex: $searchFavoriteCategoryIndex, searchFavoriteName: $searchFavoriteName, searchFavoriteTags: $searchFavoriteTags, searchFavoriteNote: $searchFavoriteNote}';
  }
}
