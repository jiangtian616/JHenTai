import 'package:json_annotation/json_annotation.dart';

enum SearchType {
  gallery,
  popular,
  favorite,
  ranklist,
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
  });

  Map<String, dynamic> toQueryParameters() {
    Map<String, dynamic> params = {
      'advsearch': 1,
    };

    params['f_cats'] = _computeFCats();
    if (keyword != null) {
      params['f_search'] = keyword;
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

    return params;
  }

  int _computeFCats() {
    int f_cats = 0;
    if (!includeDoujinshi) {
      f_cats += 2;
    }
    if (!includeManga) {
      f_cats += 4;
    }
    if (!includeArtistCG) {
      f_cats += 8;
    }
    if (!includeGameCg) {
      f_cats += 16;
    }
    if (!includeWestern) {
      f_cats += 32;
    }
    if (!includeNonH) {
      f_cats += 64;
    }
    if (!includeImageSet) {
      f_cats += 128;
    }
    if (!includeCosplay) {
      f_cats += 256;
    }
    if (!includeAsianPorn) {
      f_cats += 512;
    }
    if (!includeMisc) {
      f_cats += 1024;
    }
    return f_cats;
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "searchType": this.searchType.index,
      "includeDoujinshi": this.includeDoujinshi,
      "includeManga": this.includeManga,
      "includeArtistCG": this.includeArtistCG,
      "includeGameCg": this.includeGameCg,
      "includeWestern": this.includeWestern,
      "includeNonH": this.includeNonH,
      "includeImageSet": this.includeImageSet,
      "includeCosplay": this.includeCosplay,
      "includeAsianPorn": this.includeAsianPorn,
      "includeMisc": this.includeMisc,
      "keyword": this.keyword,
      "searchGalleryName": this.searchGalleryName,
      "searchGalleryTags": this.searchGalleryTags,
      "searchGalleryDescription": this.searchGalleryDescription,
      "searchExpungedGalleries": this.searchExpungedGalleries,
      "onlyShowGalleriesWithTorrents": this.onlyShowGalleriesWithTorrents,
      "searchLowPowerTags": this.searchLowPowerTags,
      "searchDownVotedTags": this.searchDownVotedTags,
      "pageAtLeast": this.pageAtLeast,
      "pageAtMost": this.pageAtMost,
      "minimumRating": this.minimumRating,
      "disableFilterForLanguage": this.disableFilterForLanguage,
      "disableFilterForUploader": this.disableFilterForUploader,
      "disableFilterForTags": this.disableFilterForTags,
    };
  }
}
