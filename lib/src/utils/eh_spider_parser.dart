import 'dart:collection';
import 'dart:convert';
import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:dio/dio.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart';
import 'package:intl/intl.dart';
import 'package:jhentai/src/consts/color_consts.dart';
import 'package:jhentai/src/exception/eh_exception.dart';
import 'package:jhentai/src/model/gallery_archive.dart';
import 'package:jhentai/src/model/gallery_comment.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_hh_archive.dart';
import 'package:jhentai/src/model/gallery_hh_info.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_page.dart';
import 'package:jhentai/src/model/gallery_stats.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/gallery_torrent.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/color_util.dart';
import 'package:jhentai/src/utils/string_uril.dart';

import '../database/database.dart';
import '../model/gallery.dart';
import 'check_util.dart';
import 'log.dart';

typedef EHHtmlParser<T> = T Function(Headers headers, dynamic data);

class EHSpiderParser {
  static Map<String, dynamic> loginPage2UserInfoOrErrorMsg(Headers headers, dynamic data) {
    Map<String, dynamic> map = {};

    /// if login success, cookieHeaders's length = 4or5, otherwise 1.
    List<String>? cookieHeaders = headers['set-cookie'];
    bool success = cookieHeaders != null && cookieHeaders.length > 2;
    if (success) {
      map['ipbMemberId'] = int.parse(
        RegExp(r'ipb_member_id=(\d+);').firstMatch(cookieHeaders.firstWhere((header) => header.contains('ipb_member_id')))!.group(1)!,
      );
      map['ipbPassHash'] =
          RegExp(r'ipb_pass_hash=(\w+);').firstMatch(cookieHeaders.firstWhere((header) => header.contains('ipb_pass_hash')))!.group(1)!;
    } else {
      map['errorMsg'] = _parseLoginErrorMsg(data);
    }
    return map;
  }

  /// [gallerys, pageCount, prevPageIndex, nextPageIndex]
  static GalleryPageInfo galleryPage2GalleryPageInfo(Headers headers, dynamic data) {
    String html = data as String;
    Document document = parse(data);

    if (document.querySelector('.itg.gltm') != null) {
      return _minimalGalleryPageDocument2GalleryPageInfo(document);
    }
    if (document.querySelector('.itg.gltc') != null) {
      return _compactGalleryPageDocument2GalleryPageInfo(document);
    }
    if (document.querySelector('.itg.glte') != null) {
      return _extendedGalleryPageDocument2GalleryListAndPageInfo(document);
    }
    if (document.querySelector('.itg.gld') != null) {
      return _thumbnailGalleryPageDocument2GalleryListAndPageInfo(document);
    }

    if (!html.contains('No hits found')) {
      Log.error('Parse gallery inline type failed');
      Log.upload(Exception('Parse gallery inline type failed'), extraInfos: {'html': html});
    }
    return _compactGalleryPageDocument2GalleryPageInfo(document);
  }

  static GalleryPageInfo _minimalGalleryPageDocument2GalleryPageInfo(Document document) {
    List<Element> galleryListElements = document.querySelectorAll('.itg.gltm > tbody > tr');
    String? sortOrderText = document.querySelector('.searchnav > div > select > option[selected]')?.text;

    return GalleryPageInfo(
      gallerys: galleryListElements

          /// remove ad and table header
          .where((element) => element.children.length != 1 && element.querySelector('th') == null)
          .map((e) => _parseMinimalGallery(e))
          .toList(),
      prevGid: _galleryPageDocument2PrevGid(document),
      nextGid: _galleryPageDocument2NextGid(document),
      favoriteSortOrder: sortOrderText == 'Published Time'
          ? FavoriteSortOrder.publishedTime
          : sortOrderText == 'Favorited Time'
              ? FavoriteSortOrder.favoritedTime
              : null,
    );
  }

  static GalleryPageInfo _extendedGalleryPageDocument2GalleryListAndPageInfo(Document document) {
    List<Element> galleryListElements = document.querySelectorAll('.itg.glte > tbody > tr');
    String? sortOrderText = document.querySelector('.searchnav > div > select > option[selected]')?.text;

    return GalleryPageInfo(
      gallerys: galleryListElements

          /// remove ad
          .where((element) => element.children.length != 1)
          .map((e) => _parseExtendedGallery(e))
          .toList(),
      prevGid: _galleryPageDocument2PrevGid(document),
      nextGid: _galleryPageDocument2NextGid(document),
      favoriteSortOrder: sortOrderText == 'Published Time'
          ? FavoriteSortOrder.publishedTime
          : sortOrderText == 'Favorited Time'
              ? FavoriteSortOrder.favoritedTime
              : null,
    );
  }

  static GalleryPageInfo _compactGalleryPageDocument2GalleryPageInfo(Document document) {
    List<Element> galleryListElements = document.querySelectorAll('.itg.gltc > tbody > tr');
    String? sortOrderText = document.querySelector('.searchnav > div > select > option[selected]')?.text;

    return GalleryPageInfo(
      gallerys: galleryListElements

          /// remove ad and table header
          .where((element) => element.children.length != 1 && element.querySelector('th') == null)
          .map((e) => _parseCompactGallery(e))
          .toList(),
      prevGid: _galleryPageDocument2PrevGid(document),
      nextGid: _galleryPageDocument2NextGid(document),
      favoriteSortOrder: sortOrderText == 'Published Time'
          ? FavoriteSortOrder.publishedTime
          : sortOrderText == 'Favorited Time'
              ? FavoriteSortOrder.favoritedTime
              : null,
    );
  }

  static GalleryPageInfo _thumbnailGalleryPageDocument2GalleryListAndPageInfo(Document document) {
    List<Element> galleryListElements = document.querySelectorAll('.itg.gld > div');
    String? sortOrderText = document.querySelector('.searchnav > div > select > option[selected]')?.text;

    return GalleryPageInfo(
      gallerys: galleryListElements.map((e) => _parseThumbnailGallery(e)).toList(),
      prevGid: _galleryPageDocument2PrevGid(document),
      nextGid: _galleryPageDocument2NextGid(document),
      favoriteSortOrder: sortOrderText == 'Published Time'
          ? FavoriteSortOrder.publishedTime
          : sortOrderText == 'Favorited Time'
              ? FavoriteSortOrder.favoritedTime
              : null,
    );
  }

  static String? _galleryPageDocument2NextGid(Document document) {
    /// https://exhentai.org/?next=2367467
    String? href = document.querySelector('#unext')?.attributes['href'];

    return RegExp(r'next=([\d-]+)').firstMatch(href ?? '')?.group(1);
  }

  static String? _galleryPageDocument2PrevGid(Document document) {
    /// https://exhentai.org/?prev=2367467
    String? href = document.querySelector('#uprev')?.attributes['href'];

    return RegExp(r'prev=([\d-]+)').firstMatch(href ?? '')?.group(1);
  }

  static List<dynamic> ranklistPage2GalleryPageInfo(Headers headers, dynamic data) {
    String html = data as String;
    Document document = parse(html);

    List<Element> galleryListElements = document.querySelectorAll('.itg.gltc > tbody > tr');

    List<Gallery> gallerys = galleryListElements

        /// remove ad and table header
        .where((element) => element.children.length != 1 && element.querySelector('th') == null)
        .map((e) => _parseCompactGallery(e))
        .toList();

    int pageCount = _ranklistPageDocument2TotalPageCount(document);
    int? prevPageIndex = _ranklistPageDocument2PrevPageIndex(document);
    int? nextPageIndex = _ranklistPageDocument2NextPageIndex(document);

    return [gallerys, pageCount, prevPageIndex, nextPageIndex];
  }

  static int _ranklistPageDocument2TotalPageCount(Document document) {
    Element? tr = document.querySelector('.ptt > tbody > tr');
    if (tr == null || tr.children.isEmpty) {
      return 0;
    }
    Element td = tr.children[tr.children.length - 2];
    return int.parse(td.querySelector('a')!.text);
  }

  static int? _ranklistPageDocument2NextPageIndex(Document document) {
    Element? tr = document.querySelector('.ptt > tbody > tr');
    Element? td = tr?.children[tr.children.length - 1];
    return int.tryParse(RegExp(r'p(age)?=(\d+)').firstMatch(td?.querySelector('a')?.attributes['href'] ?? '')?.group(2) ?? '');
  }

  static int? _ranklistPageDocument2PrevPageIndex(Document document) {
    Element? a = document.querySelector('.ptt > tbody > tr')?.children[0].querySelector('a');
    if (a == null) {
      return null;
    }

    return int.tryParse(RegExp(r'p(age)?=(\d+)').firstMatch(a.attributes['href'] ?? '')?.group(2) ?? '0');
  }

  // In some page like favorite page or ranklist page, infos like uploader, pageCount, favorited info, rated info is
  // missing. So we need to extract these infos in details page.
  static Map<String, dynamic> detailPage2GalleryAndDetailAndApikey(Headers headers, dynamic data) {
    Document document = parse(data as String);

    String galleryUrl = document.querySelector('#gd5 > p > a')!.attributes['href']!.split('?')[0];
    List<String>? parts = galleryUrl.split('/');
    String coverStyle = document.querySelector('#gd1 > div')?.attributes['style'] ?? '';
    RegExpMatch coverMatch = RegExp(r'width:(\d+)px.*height:(\d+)px.*url\((.*)\)').firstMatch(coverStyle)!;
    LinkedHashMap<String, List<GalleryTag>> tags = _detailPageDocument2Tags(document);

    Gallery gallery = Gallery(
      gid: int.parse(parts[4]),
      token: parts[5],
      title: document.querySelector('#gn')?.text ?? '',
      category: document.querySelector('#gdc > .cs')?.text ?? '',
      cover: GalleryImage(
        url: coverMatch.group(3)!,
        height: double.parse(coverMatch.group(2)!),
        width: double.parse(coverMatch.group(1)!),
      ),
      pageCount: int.parse((document.querySelector('#gdd > table > tbody > tr:nth-child(5) > .gdt2')?.text ?? '').split(' ')[0]),
      rating: _parseGalleryRating(document.querySelector('#grt2')!),
      hasRated: document.querySelector('#rating_image.ir')!.attributes['class']!.split(' ').length > 1 ? true : false,
      isFavorite: document.querySelector('#fav > .i') != null ? true : false,
      favoriteTagIndex: _parseFavoriteTagIndexByOffset(document),
      favoriteTagName: document.querySelector('#fav > .i')?.attributes['style'] == null ? null : document.querySelector('#favoritelink')?.text,
      galleryUrl: galleryUrl,
      tags: tags,
      language: tags['language']?[0].tagData.key,
      uploader: document.querySelector('#gdn > a')?.text ?? '',
      publishTime: document.querySelector('#gdd > table > tbody > tr > .gdt2')?.text ?? '',
      isExpunged: (document.querySelector('#gdd > table > tbody > tr:nth-child(2) > .gdt2')?.text ?? '').contains('Expunged'),
    );

    GalleryDetail galleryDetail = GalleryDetail(
      rawTitle: document.querySelector('#gn')!.text,
      japaneseTitle: document.querySelector('#gj')!.text,
      ratingCount: int.parse(document.querySelector('#rating_count')?.text ?? '0'),
      realRating: _parseGalleryDetailsRealRating(document),
      size: document.querySelector('#gdd > table > tbody')?.children[4].children[1].text ?? '',
      favoriteCount: _parseGalleryDetailsFavoriteCount(document),
      torrentCount: RegExp(r'\d+').firstMatch(document.querySelector('#gd5')?.children[2].querySelector('a')?.text ?? '')?.group(0) ?? '0',
      torrentPageUrl: document.querySelector('#gd5')?.children[2].querySelector('a')?.attributes['onclick']?.split('\'')[1] ?? '',
      archivePageUrl: document.querySelector('#gd5')?.children[1].querySelector('a')?.attributes['onclick']?.split('\'')[1] ?? '',
      newVersionGalleryUrl: document.querySelectorAll('#gnd > a').lastOrNull?.attributes['href'],
      fullTags: tags,
      comments: _parseGalleryDetailsComments(document.querySelectorAll('#cdiv > .c1')),
      thumbnails: _detailPageDocument2Thumbnails(document),
      thumbnailsPageCount: _detailPageDocument2ThumbnailsPageCount(document),
    );

    String script = document.querySelector('.gm')?.previousElementSibling?.previousElementSibling?.text ?? '';
    String apikey = RegExp(r'var apikey = "(\w+)"').firstMatch(script)?.group(1) ?? '';

    return {
      'gallery': gallery,
      'galleryDetails': galleryDetail,
      'apikey': apikey,
    };
  }

  static LinkedHashMap<String, List<GalleryTag>> _detailPageDocument2Tags(Document document) {
    LinkedHashMap<String, List<GalleryTag>> tags = LinkedHashMap();

    List<Element> trs = document.querySelectorAll('#taglist > table > tbody > tr').toList();
    for (Element tr in trs) {
      List<Element> tagDivs = tr.querySelectorAll('td:nth-child(1) > div').toList();
      for (Element tagDiv in tagDivs) {
        /// eg: language:english
        String pair = tagDiv.attributes['id'] ?? '';
        if (pair.isEmpty) {
          continue;
        }

        /// some tag doesn't has a type
        List<String> list = pair.split(':').toList();
        String namespace = list.length == 2 && list[0].isNotEmpty ? list[0].split('_')[1] : 'temp';
        String key = list.length == 1 ? list[0].substring(3).replaceAll('_', ' ') : list[1].replaceAll('_', ' ');

        String? tagClass = tagDiv.attributes['class'];
        EHTagStatus tagStatus = tagClass == 'gt'
            ? EHTagStatus.confidence
            : tagClass == 'gtl'
                ? EHTagStatus.skepticism
                : tagClass == 'gtw'
                    ? EHTagStatus.incorrect
                    : EHTagStatus.confidence;

        String? tagVoteClass = tagDiv.querySelector('a')?.attributes['class'];
        EHTagVoteStatus voteStatus = tagVoteClass == 'tup'
            ? EHTagVoteStatus.up
            : tagVoteClass == 'tdn'
                ? EHTagVoteStatus.down
                : EHTagVoteStatus.none;

        tags.putIfAbsent(namespace, () => []).add(
              GalleryTag(
                tagData: TagData(namespace: namespace, key: key),
                tagStatus: tagStatus,
                voteStatus: voteStatus,
              ),
            );
      }
    }
    return tags;
  }

  static List<GalleryThumbnail> detailPage2Thumbnails(Headers headers, dynamic data) {
    Document document = parse(data as String);
    return _detailPageDocument2Thumbnails(document);
  }

  static Map<String, dynamic> detailPage2RangeAndThumbnails(Headers headers, dynamic data) {
    Document document = parse(data as String);

    /// eg. Showing 161 - 200 of 680 images
    String desc = document.querySelector('.gtb > .gpc')!.text.replaceAll(',', '');
    RegExpMatch match = RegExp(r'Showing (\d+) - (\d+) of').firstMatch(desc)!;

    return {
      'rangeIndexFrom': int.parse(match.group(1)!) - 1,
      'rangeIndexTo': int.parse(match.group(2)!) - 1,
      'thumbnails': _detailPageDocument2Thumbnails(document),
    };
  }

  static List<GalleryThumbnail> _detailPageDocument2Thumbnails(Document document) {
    List<Element> thumbNailElements = document.querySelectorAll('#gdt > .gdtm');
    if (thumbNailElements.isNotEmpty) {
      return _parseGalleryDetailsSmallThumbnails(thumbNailElements);
    }
    thumbNailElements = document.querySelectorAll('#gdt > .gdtl');
    return _parseGalleryDetailsLargeThumbnails(thumbNailElements);
  }

  static int _detailPageDocument2ThumbnailsPageCount(Document document) {
    Element? tr = document.querySelector('.ptt > tbody > tr');
    if (tr == null || tr.children.isEmpty) {
      return 0;
    }
    Element td = tr.children[tr.children.length - 2];
    return int.parse(td.querySelector('a')!.text);
  }

  static List<GalleryComment> detailPage2Comments(Headers headers, dynamic data) {
    Document document = parse(data as String);
    List<Element> commentElements = document.querySelectorAll('#cdiv > .c1');
    return _parseGalleryDetailsComments(commentElements);
  }

  static Map<String, String?>? forumPage2UserInfo(Headers headers, dynamic data) {
    Document document = parse(data as String);

    /// cookie is wrong, not logged in
    if (document.querySelector('.pcen') != null) {
      return null;
    }

    String nickName = document.querySelector('#profilename')!.text;
    String userName = document.querySelector('.home > b > a')!.text;
    String? avatarImgUrl = document.querySelector('#profilename')?.nextElementSibling?.nextElementSibling?.querySelector('img')?.attributes['src'];

    return {'userName': userName, 'avatarImgUrl': avatarImgUrl, 'nickName': nickName};
  }

  static List<String> favoritePopup2FavoriteTagNames(Headers headers, dynamic data) {
    Document document = parse(data as String);
    List<Element> divs = document.querySelectorAll('.nosel > div');
    return divs.map((div) => div.querySelector('div:nth-child(5)')?.text ?? '').toList();
  }

  static Map<String, List> favoritePage2FavoriteTagsAndCounts(Headers headers, dynamic data) {
    String html = data as String;
    Document document = parse(html);
    List<Element> divs = document.querySelectorAll('.nosel > .fp');

    /// not favorite tag
    divs.removeLast();

    List<String> favoriteTagNames = [];
    List<int> favoriteCounts = [];

    for (Element div in divs) {
      String tagName = div.querySelector('div:last-child')?.text ?? '';
      int favoriteCount = int.parse(div.querySelector('div:first-child')?.text ?? '0');
      favoriteTagNames.add(tagName);
      favoriteCounts.add(favoriteCount);
    }

    if (favoriteTagNames.length < 10 || favoriteCounts.length < 10) {
      Log.upload(
        Exception('Favorites parsed error!'),
        extraInfos: {
          'html': html,
          'favoriteTagNames': favoriteTagNames,
          'favoriteCounts': favoriteCounts,
        },
      );
    }

    return {
      'favoriteTagNames': favoriteTagNames,
      'favoriteCounts': favoriteCounts,
    };
  }

  static GalleryImage imagePage2GalleryImage(Headers headers, dynamic data) {
    String html = data as String;
    Document document = parse(html);
    Element? img = document.querySelector('#img');
    if (img == null && document.querySelector('#pane_images') != null) {
      throw EHException(type: EHExceptionType.unsupportedImagePageStyle, message: 'unsupportedImagePageStyle'.tr);
    }
    Element a = document.querySelector('#i6 > a')!;

    /// height: 1600px; width: 1124px;
    String style = img!.attributes['style']!;
    String url = img.attributes['src']!;

    if (url.contains('509.gif')) {
      throw EHException(type: EHExceptionType.exceedLimit, message: 'exceedImageLimits'.tr);
    }

    Element? originalImg = document.querySelector('#i7 > a');
    String? originalImgHref = originalImg?.attributes['href'];
    RegExpMatch? originalImgWidthAndHeight = RegExp(r'(\d+) x (\d+)').firstMatch(originalImg?.text ?? '');
    double? originalImgWidth = double.tryParse(originalImgWidthAndHeight?.group(1) ?? '');
    double? originalImgHeight = double.tryParse(originalImgWidthAndHeight?.group(2) ?? '');

    return GalleryImage(
      url: url,
      height: double.parse(RegExp(r'height:(\d+)px').firstMatch(style)!.group(1)!),
      width: double.parse(RegExp(r'width:(\d+)px').firstMatch(style)!.group(1)!),
      originalImageUrl: originalImgHref,
      originalImageWidth: originalImgWidth,
      originalImageHeight: originalImgHeight,
      imageHash: RegExp(r'f_shash=(\w+)').firstMatch(a.attributes['href']!)!.group(1)!,
    );
  }

  static GalleryImage imagePage2OriginalGalleryImage(Headers headers, dynamic data) {
    Document document = parse(data as String);
    Element? img = document.querySelector('#img');
    if (img == null && document.querySelector('#pane_images') != null) {
      throw EHException(type: EHExceptionType.unsupportedImagePageStyle, message: 'unsupportedImagePageStyle'.tr);
    }
    Element a = document.querySelector('#i6 > a')!;

    /// height: 1600px; width: 1124px;
    String style = img!.attributes['style']!;
    String url = img.attributes['src']!;

    if (url.contains('509.gif')) {
      throw EHException(type: EHExceptionType.exceedLimit, message: 'exceedImageLimits'.tr);
    }

    Element? originalImg = document.querySelector('#i7 > a');
    String? originalImgHref = originalImg?.attributes['href'];
    RegExpMatch? originalImgWidthAndHeight = RegExp(r'(\d+) x (\d+)').firstMatch(originalImg?.text ?? '');
    double? originalImgWidth = double.tryParse(originalImgWidthAndHeight?.group(1) ?? '');
    double? originalImgHeight = double.tryParse(originalImgWidthAndHeight?.group(2) ?? '');

    return GalleryImage(
      url: originalImgHref ?? url,
      height: originalImgHeight ?? double.parse(RegExp(r'height:(\d+)px').firstMatch(style)!.group(1)!),
      width: originalImgWidth ?? double.parse(RegExp(r'width:(\d+)px').firstMatch(style)!.group(1)!),
      imageHash: RegExp(r'f_shash=(\w+)').firstMatch(a.attributes['href']!)!.group(1)!,
    );
  }

  static String? sendComment2ErrorMsg(Headers headers, dynamic data) {
    if (data?.isEmpty ?? true) {
      return null;
    }
    Document document = parse(data);
    return document.querySelector('p.br')?.text;
  }

  static List<GalleryTorrent> torrentPage2GalleryTorrent(Headers headers, dynamic data) {
    Document document = parse(data as String);

    List<Element> torrentForms = document.querySelectorAll('#torrentinfo > div > form');
    torrentForms.removeWhere((form) => form.querySelector('div > table > tbody > tr:nth-child(4) > td > a') == null);

    return torrentForms.map(
      (form) {
        List<Element> trs = form.querySelectorAll('div > table > tbody > tr');
        return GalleryTorrent(
          title: trs[2].querySelector('td > a')!.text,
          postTime: trs[0].querySelector('td:nth-child(1)')!.text.substring(8),
          size: trs[0].querySelector('td:nth-child(3)')!.text.substring(6),
          seeds: int.parse(trs[0].querySelector('td:nth-child(7)')!.text.substring(7)),
          peers: int.parse(trs[0].querySelector('td:nth-child(9)')!.text.substring(7)),
          downloads: int.parse(trs[0].querySelector('td:nth-child(11)')!.text.substring(11)),
          uploader: trs[1].querySelector('td:nth-child(1)')!.text.substring(10),
          torrentUrl: trs[2].querySelector('td > a')!.attributes['href']!,
          magnetUrl: 'magnet:?xt=urn:btih:${trs[2].querySelector('td > a')!.attributes['href']!.split('.')[1].split('/').last}',
        );
      },
    ).toList();
  }

  static Map<String, dynamic> settingPage2SiteSetting(Headers headers, dynamic data) {
    Document document = parse(data as String);
    List<Element> items = document.querySelectorAll('.optouter');
    Map<String, dynamic> map = {};

    List<Element> profiles = document.querySelectorAll('#profile_form > select > option');
    map['jHenTaiProfileNo'] = profiles.singleWhereOrNull((profile) => profile.text == 'JHenTai')?.attributes['value'];

    Element frontPageSetting = items[6];
    String type = frontPageSetting.querySelector('div > p > label > input[checked=checked]')!.parent!.text;

    switch (type) {
      case ' Minimal':
        map['frontPageDisplayType'] = FrontPageDisplayType.minimal;
        break;
      case ' Minimal+':
        map['frontPageDisplayType'] = FrontPageDisplayType.minimalPlus;
        break;
      case ' Compact':
        map['frontPageDisplayType'] = FrontPageDisplayType.compact;
        break;
      case ' Extended':
        map['frontPageDisplayType'] = FrontPageDisplayType.extended;
        break;
      case ' Thumbnail':
        map['frontPageDisplayType'] = FrontPageDisplayType.thumbnail;
        break;
    }

    Element thumbnailSetting = items[19];
    map['isLargeThumbnail'] =
        thumbnailSetting.querySelector('#tssel > div > label > input[checked=checked]')?.parent?.text == ' Large' ? true : false;
    map['thumbnailRows'] = int.parse(thumbnailSetting.querySelector('#trsel > div > label > input[checked=checked]')?.parent?.text ?? '4');
    return map;
  }

  static Map<String, int> homePage2ImageLimit(Headers headers, dynamic data) {
    Document document = parse(data as String);

    Map<String, int> map = {
      'currentConsumption': int.parse(document.querySelector('.stuffbox > .homebox > p > strong:nth-child(1)')!.text),
      'totalLimit': int.parse(document.querySelector('.stuffbox > .homebox > p > strong:nth-child(3)')!.text),
      'resetCost': int.parse(document.querySelector('.stuffbox > .homebox > p:nth-child(3) > strong')!.text),
    };

    return map;
  }

  static Map<String, dynamic> myTagsPage2TagSetNamesAndTagSetsAndApikey(Headers headers, dynamic data) {
    Document document = parse(data as String);

    List<Element> options = document.querySelectorAll('#tagset_outer > div > select > option');
    List<String> tagSetNames = options.map((o) => o.text).toList();

    List<Element> tagDivs = document.querySelectorAll('#usertags_outer > div');
    List<TagSet> tagSets = tagDivs.where((element) => element.id != 'usertag_0').map(
      (div) {
        String pair = div.querySelector('div:nth-child(1) > a > div')?.attributes['title'] ?? '';

        /// some tag doesn't has a namespace
        List<String> list = pair.split(':').toList();
        String namespace = list[0].isNotEmpty ? list[0] : 'temp';
        String key = list[1];
        TagData tagData = TagData(namespace: namespace, key: key);

        return TagSet(
          tagId: int.parse(div.querySelector('div:nth-child(1) > a > div')!.attributes['id']!.split('_')[1]),
          tagData: tagData,
          watched: div.querySelector('div:nth-child(3) > label > input[checked=checked]') != null,
          hidden: div.querySelector('div:nth-child(5) > label > input[checked=checked]') != null,
          backgroundColor: aRGBString2Color(div.querySelector('div:nth-child(9) > input')?.attributes['value']),
          weight: int.parse(div.querySelector('div:nth-child(11) > input')!.attributes['value']!),
        );
      },
    ).toList();

    String apikey = RegExp(r'apikey = \"(.*)\"').firstMatch(document.querySelector('#outer > script:nth-child(1)')!.text)!.group(1)!;

    return {
      'tagSetNames': tagSetNames,
      'tagSets': tagSets,
      'apikey': apikey,
    };
  }

  static GalleryStats statPage2GalleryStats(Headers headers, dynamic data) {
    Document document = parse(data as String);

    Element rankScoreTbody = document.querySelector('.stuffbox > div > div > table > tbody')!;
    Element yearlyStatTbody = document.querySelector('.stuffbox > div > div:nth-child(1) > table > tbody')!;
    Element monthlyStatTbody = document.querySelector('.stuffbox > div > div:nth-child(2) > table > tbody')!;
    Element dailyStatTbody = document.querySelector('.stuffbox > table > tbody')!;

    return GalleryStats(
      totalVisits: int.parse(document.querySelector('.stuffbox > div > div > p:nth-child(3) > strong')!.text.replaceAll(',', '')),
      allTimeRanking: int.tryParse(rankScoreTbody.querySelector('tr:nth-child(2) > td:nth-child(4)')?.text.replaceAll(',', '') ?? ''),
      allTimeScore: int.tryParse(rankScoreTbody.querySelector('tr:nth-child(2) > td:nth-child(5)')?.text.replaceAll(',', '') ?? ''),
      yearRanking: int.tryParse(rankScoreTbody.querySelector('tr:nth-child(4) > td:nth-child(4)')?.text.replaceAll(',', '') ?? ''),
      yearScore: int.tryParse(rankScoreTbody.querySelector('tr:nth-child(4) > td:nth-child(5)')?.text.replaceAll(',', '') ?? ''),
      monthRanking: int.tryParse(rankScoreTbody.querySelector('tr:nth-child(6) > td:nth-child(4)')?.text.replaceAll(',', '') ?? ''),
      monthScore: int.tryParse(rankScoreTbody.querySelector('tr:nth-child(6) > td:nth-child(5)')?.text.replaceAll(',', '') ?? ''),
      dayRanking: int.tryParse(rankScoreTbody.querySelector('tr:nth-child(8) > td:nth-child(4)')?.text.replaceAll(',', '') ?? ''),
      dayScore: int.tryParse(rankScoreTbody.querySelector('tr:nth-child(8) > td:nth-child(5)')?.text.replaceAll(',', '') ?? ''),
      yearlyStats: _parseStats(yearlyStatTbody),
      monthlyStats: _parseStats(monthlyStatTbody),
      dailyStats: _parseStats(dailyStatTbody),
    );
  }

  static String imageLookup2RedirectUrl(Headers headers, dynamic data) {
    return headers['Location']!.first;
  }

  static String? unlockArchivePage2DownloadArchivePageUrl(Headers headers, dynamic data) {
    Document document = parse(data as String);

    return document.querySelector('#continue > a')?.attributes['href'];
  }

  static String downloadArchivePage2DownloadUrl(Headers headers, dynamic data) {
    Document document = parse(data as String);

    return document.querySelector('#db > p > a')!.attributes['href']!;
  }

  static Map<String, dynamic> galleryRatingResponse2RatingInfo(Headers headers, dynamic data) {
    Map<String, dynamic> respMap = jsonDecode(data as String);

    return {
      'rating_usr': double.parse(respMap['rating_usr'].toString()),
      'rating_cnt': respMap['rating_cnt'],
      'rating_avg': double.parse(respMap['rating_avg'].toString()),
    };
  }

  static String? voteTagResponse2ErrorMessage(Headers headers, dynamic data) {
    Map<String, dynamic> respMap = jsonDecode(data as String);

    if (respMap['error'] != null) {
      return respMap['error'];
    }

    return null;
  }

  static int? votingCommentResponse2Score(Headers headers, dynamic data) {
    int? score = jsonDecode(data)['comment_score'];

    CheckUtil.build(() => score != null, errorMsg: "Voting comment result score shouldn't be null!").withUploadParam(data).check();

    return score;
  }

  static void addTagSetResponse2Result(Headers headers, dynamic data) {
    if (data is String && data.contains('No more tags can be added to this tagset')) {
      throw EHException(type: EHExceptionType.tagSetExceedLimit, message: 'tagSetExceedLimit'.tr);
    }
  }

  static String _parseLoginErrorMsg(String html) {
    if (html.contains('The captcha was not entered correctly')) {
      return 'needCaptcha';
    }
    return 'userNameOrPasswordMismatch';
  }

  static GalleryArchive archivePage2Archive(Headers headers, dynamic data) {
    Document document = parse(data as String);
    return GalleryArchive(
      gpCount: int.tryParse(
        RegExp(r'([\d,]+) GP').firstMatch(document.querySelector('#db > p:nth-child(4)')?.text ?? '')?.group(1)?.replaceAll(',', '') ?? '',
      ),
      creditCount: int.tryParse(
        RegExp(r'([\d,]+) Credits').firstMatch(document.querySelector('#db > p:nth-child(4)')?.text ?? '')?.group(1)?.replaceAll(',', '') ?? '',
      ),
      originalCost: document.querySelector('#db > div > div > div > strong')!.text.replaceAll(',', ''),
      originalSize: document.querySelector('#db > div > div > p > strong')!.text,
      downloadOriginalHint: document.querySelector('#db > div > div > form > div > input')!.attributes['value']!,
      resampleCost: document.querySelector('#db > div > div:nth-child(3) > div > strong')?.text.replaceAll(',', '') ?? '',
      resampleSize: document.querySelector('#db > div > div:nth-child(3) > p > strong')?.text,
      downloadResampleHint: document.querySelector('#db > div > div:nth-child(3) > form > div > input')!.attributes['value']!,
    );
  }

  static GalleryHHInfo archivePage2HHInfo(Headers headers, dynamic data) {
    Document document = parse(data as String);

    List<Element> tds = document.querySelectorAll('table > tbody > tr > td');

    List<GalleryHHArchive> archives = tds
        .map(
          (td) => GalleryHHArchive(
            resolutionDesc: td.querySelector('p:nth-child(1)')!.text,
            resolution: RegExp(r"'(\w+)'").firstMatch(td.querySelector('p:nth-child(1) > a')?.attributes['onclick'] ?? '')?.group(1),
            size: td.querySelector('p:nth-child(3)')!.text,
            cost: td.querySelector('p:nth-child(5)')!.text,
          ),
        )
        .toList();

    return GalleryHHInfo(
      gpCount: int.tryParse(
        RegExp(r'([\d,]+) GP').firstMatch(document.querySelector('#db > p:nth-child(4)')?.text ?? '')?.group(1)?.replaceAll(',', '') ?? '',
      ),
      creditCount: int.tryParse(
        RegExp(r'([\d,]+) Credits').firstMatch(document.querySelector('#db > p:nth-child(4)')?.text ?? '')?.group(1)?.replaceAll(',', '') ?? '',
      ),
      archives: archives,
    );
  }

  static String downloadHHPage2Result(Headers headers, dynamic data) {
    Document document = parse(data as String);

    return document.querySelector('#db > p')?.text ?? '';
  }

  static List<TagData> tagSuggestion2TagList(Headers headers, dynamic data) {
    Map resp = jsonDecode(data);
    if (resp['tags'] is! Map) {
      return <TagData>[];
    }
    Map tags = resp['tags'];
    return tags.values.map((e) => TagData(namespace: e['ns'], key: e['tn'])).toList();
  }

  static String? a404Page2GalleryDeletedHint(Headers headers, dynamic data) {
    Document document = parse(data as String);

    List<Node>? nodes = document.querySelector('.d > p')?.nodes;
    if (nodes == null || nodes.isEmpty) {
      return null;
    }

    String? detailPageHint = nodes.first.text;
    if (isEmptyOrNull(detailPageHint)) {
      return null;
    }

    if (detailPageHint!.contains('This gallery has been removed')) {
      return 'invisibleHints'.tr;
    }

    Match match = RegExp(r'This gallery is unavailable due to a copyright claim by (.*).$').firstMatch(detailPageHint)!;
    String copyRighter = match.group(1)!;
    return 'copyRightHints'.tr + copyRighter;
  }

  static Map<String, String> exchangePage2Assets(Headers headers, dynamic data) {
    Document document = parse(data as String);

    String? creditDesc = document.querySelector('#buyform')?.parent?.nextElementSibling?.text;
    String? gpCreditDesc = document.querySelector('#sellform')?.parent?.nextElementSibling?.text;

    String? credit = RegExp(r'([\d,k ]+)Credits').firstMatch(creditDesc ?? '')?.group(1);
    String? gp = RegExp(r'([\d,k ]+)GP').firstMatch(gpCreditDesc ?? '')?.group(1);

    return {'credit': credit?.trim() ?? '-1', 'gp': gp?.trim() ?? '-1'};
  }

  static String githubReleasePage2LatestVersion(Headers headers, dynamic data) {
    List releases = data;
    Map latestRelease = releases[0];
    return latestRelease['tag_name'];
  }

  static Gallery _parseMinimalGallery(Element tr) {
    GalleryImage? cover = _parseMinimalGalleryCover(tr);
    String galleryUrl = tr.querySelector('.gl3m.glname > a')?.attributes['href'] ?? '';
    List<String> parts = galleryUrl.split('/');

    Gallery gallery = Gallery(
      gid: int.parse(parts[4]),
      token: parts[5],
      title: tr.querySelector('.glink')?.text ?? '',
      category: tr.querySelector('.gl1m.glcat > div')?.text ?? '',
      cover: cover!,
      pageCount: null,
      rating: _parseGalleryRating(tr),
      hasRated: tr.querySelector('.gl4m > .ir')!.attributes['class']!.split(' ').length > 1 ? true : false,
      isFavorite: tr.querySelector('.gl2m > div:nth-child(2) > [id][style]') != null ? true : false,
      favoriteTagIndex: _parseMinimalGalleryFavoriteTagIndex(tr),
      favoriteTagName: tr.querySelector('.gl2m > div:nth-child(2) > [id][style]')?.attributes['title'],
      galleryUrl: galleryUrl,
      tags: LinkedHashMap<String, List<GalleryTag>>(),
      uploader: tr.querySelector('.gl5m.glhide > div > a')?.text ?? '',
      publishTime: tr.querySelector('.gl2m > div:nth-child(2)')?.text ?? '',
      isExpunged: tr.querySelector('.gl2m > div:nth-child(2) > s') != null,
    );

    return gallery;
  }

  static Gallery _parseCompactGallery(Element tr) {
    LinkedHashMap<String, List<GalleryTag>> tags = _parseCompactGalleryTags(tr);
    GalleryImage? cover = _parseCompactGalleryCover(tr);
    String galleryUrl = tr.querySelector('.gl3c.glname > a')?.attributes['href'] ?? '';
    List<String> parts = galleryUrl.split('/');

    Gallery gallery = Gallery(
      gid: int.parse(parts[4]),
      token: parts[5],
      title: tr.querySelector('.glink')?.text ?? '',
      category: tr.querySelector('.cn')?.text ?? '',
      cover: cover!,
      pageCount: _parseCompactGalleryPageCount(tr),
      rating: _parseGalleryRating(tr),
      hasRated: tr.querySelector('.gl2c > div:nth-child(2) > .ir')!.attributes['class']!.split(' ').length > 1 ? true : false,
      isFavorite: tr.querySelector('.gl2c > div:nth-child(2) > [id][style]') != null ? true : false,
      favoriteTagIndex: _parseCompactGalleryFavoriteTagIndex(tr),
      favoriteTagName: tr.querySelector('.gl2c > div:nth-child(2) > [id][style]')?.attributes['title'],
      galleryUrl: galleryUrl,
      tags: tags,
      language: tags['language']?[0].tagData.key,
      uploader: tr.querySelector('.gl4c.glhide > div > a')?.text ?? '',
      publishTime: tr.querySelector('.gl2c > div:nth-child(2) > [id]')?.text ?? '',
      isExpunged: tr.querySelector('.gl2c > div:nth-child(2) > [id] > s') != null,
    );

    return gallery;
  }

  static Gallery _parseExtendedGallery(Element tr) {
    LinkedHashMap<String, List<GalleryTag>> tags = _parseExtendedGalleryTags(tr);
    GalleryImage? cover = _parseExtendedGalleryCover(tr);
    String galleryUrl = tr.querySelector('.gl1e > div > a')?.attributes['href'] ?? '';
    List<String> parts = galleryUrl.split('/');

    Gallery gallery = Gallery(
      gid: int.parse(parts[4]),
      token: parts[5],
      title: tr.querySelector('.glink')?.text ?? '',
      category: tr.querySelector('.cn')?.text ?? '',
      cover: cover!,
      pageCount: _parseExtendedGalleryPageCount(tr),
      rating: _parseGalleryRating(tr),
      hasRated: tr.querySelector('.gl3e > .ir')!.attributes['class']!.split(' ').length > 1 ? true : false,
      isFavorite: tr.querySelector('.gl3e > [id][style]') != null ? true : false,
      favoriteTagIndex: _parseExtendedGalleryFavoriteTagIndex(tr),
      favoriteTagName: tr.querySelector('.gl3e > [id][style]')?.attributes['title'],
      galleryUrl: galleryUrl,
      tags: tags,
      language: tags['language']?[0].tagData.key,
      uploader: tr.querySelector('.gl3e > div > a')?.text ?? '',
      publishTime: tr.querySelector('.gl3e > div[id]')?.text ?? '',
      isExpunged: tr.querySelector('.gl3e > div[id] > s') != null,
    );

    return gallery;
  }

  static Gallery _parseThumbnailGallery(Element div) {
    GalleryImage? cover = _parseThumbnailGalleryCover(div);
    String galleryUrl = div.querySelector('a')?.attributes['href'] ?? '';
    List<String> parts = galleryUrl.split('/');

    Gallery gallery = Gallery(
      gid: int.parse(parts[4]),
      token: parts[5],
      title: div.querySelector('.glink')?.text ?? '',
      category: div.querySelector('.cs')?.text ?? '',
      cover: cover!,
      pageCount: _parseThumbnailGalleryPageCount(div),
      rating: _parseGalleryRating(div),
      hasRated: div.querySelector('.gl5t > div > .ir')!.attributes['class']!.split(' ').length > 1 ? true : false,
      isFavorite: div.querySelector('.gl5t > div > [id][style]') != null ? true : false,
      favoriteTagIndex: _parseThumbnailGalleryFavoriteTagIndex(div),
      favoriteTagName: div.querySelector('.gl5t > div > [id][style]')?.attributes['title'],
      galleryUrl: galleryUrl,
      tags: LinkedHashMap(),
      publishTime: div.querySelector('.gl5t > div > div[id]')?.text ?? '',
      isExpunged: div.querySelector('.gl5t > div > div[id] > s') != null,
    );

    return gallery;
  }

  static LinkedHashMap<String, List<GalleryTag>> _parseExtendedGalleryTags(Element tr) {
    LinkedHashMap<String, List<GalleryTag>> tags = LinkedHashMap();
    List<Element> tagDivs = tr.querySelectorAll('.gl2e > div > a > div > div:nth-child(1) > table > tbody > tr > td > div').toList();
    for (Element tagDiv in tagDivs) {
      /// eg: language:english
      String pair = tagDiv.attributes['title'] ?? '';
      if (pair.isEmpty) {
        continue;
      }

      /// some tag doesn't has a namespace
      List<String> list = pair.split(':').toList();
      String namespace = list[0].isNotEmpty ? list[0] : 'temp';
      String key = list[1];
      TagData tagData = TagData(namespace: namespace, key: key);

      String style = tagDiv.attributes['style'] ?? '';
      String? color = RegExp(r'color:#(.*?);').firstMatch(style)?.group(1);
      String? backgroundColor = RegExp(r'background:radial-gradient\(#.*,#(.*)\)').firstMatch(style)?.group(1);

      tags.putIfAbsent(namespace, () => []).add(GalleryTag(
            tagData: tagData,
            color: color == null ? null : Color(int.parse('FF$color', radix: 16)),
            backgroundColor: backgroundColor == null ? null : Color(int.parse('FF$backgroundColor', radix: 16)),
          ));
    }
    return tags;
  }

  static LinkedHashMap<String, List<GalleryTag>> _parseCompactGalleryTags(Element tr) {
    LinkedHashMap<String, List<GalleryTag>> tags = LinkedHashMap();
    List<Element> tagDivs = tr.querySelectorAll('.gt').toList();
    for (Element tagDiv in tagDivs) {
      /// eg: language:english
      String pair = tagDiv.attributes['title'] ?? '';
      if (pair.isEmpty) {
        continue;
      }

      /// some tag doesn't has a namespace
      List<String> list = pair.split(':').toList();
      String namespace = list[0].isNotEmpty ? list[0] : 'temp';
      String key = list[1];
      TagData tagData = TagData(namespace: namespace, key: key);

      String style = tagDiv.attributes['style'] ?? '';
      String? color = RegExp(r'color:#(.*?);').firstMatch(style)?.group(1);
      String? backgroundColor = RegExp(r'background:radial-gradient\(#.*,#(.*)\)').firstMatch(style)?.group(1);

      tags.putIfAbsent(namespace, () => []).add(GalleryTag(
            tagData: tagData,
            color: color == null ? null : Color(int.parse('FF$color', radix: 16)),
            backgroundColor: backgroundColor == null ? null : Color(int.parse('FF$backgroundColor', radix: 16)),
          ));
    }
    return tags;
  }

  static GalleryImage? _parseMinimalGalleryCover(Element tr) {
    Element? img = tr.querySelector('.gl2m > .glthumb > div > img');
    if (img == null) {
      return null;
    }
    String coverUrl = img.attributes['data-src'] ?? img.attributes['src'] ?? '';

    /// eg: height:296px;width:250px
    String? style = img.attributes['style'];
    if (style == null) {
      return null;
    }
    RegExp sizeReg = RegExp(r'(\d+)');
    List<RegExpMatch> sizes = sizeReg.allMatches(style).toList();

    String? height = sizes[0].group(0);
    String? width = sizes[1].group(0);
    if (height == null || width == null) {
      return null;
    }
    return GalleryImage(
      url: coverUrl,
      height: double.parse(height),
      width: double.parse(width),
    );
  }

  static GalleryImage? _parseCompactGalleryCover(Element tr) {
    Element? img = tr.querySelector('.gl2c > .glthumb > div > img');
    if (img == null) {
      return null;
    }
    String coverUrl = img.attributes['data-src'] ?? img.attributes['src'] ?? '';

    /// eg: height:296px;width:250px
    String? style = img.attributes['style'];
    if (style == null) {
      return null;
    }
    RegExp sizeReg = RegExp(r'(\d+)');
    List<RegExpMatch> sizes = sizeReg.allMatches(style).toList();

    String? height = sizes[0].group(0);
    String? width = sizes[1].group(0);
    if (height == null || width == null) {
      return null;
    }
    return GalleryImage(
      url: coverUrl,
      height: double.parse(height),
      width: double.parse(width),
    );
  }

  static GalleryImage? _parseExtendedGalleryCover(Element tr) {
    Element? img = tr.querySelector('.gl1e > div > a > img');
    if (img == null) {
      return null;
    }
    String coverUrl = img.attributes['data-src'] ?? img.attributes['src'] ?? '';

    /// eg: height:296px;width:250px
    String? style = img.attributes['style'];
    if (style == null) {
      return null;
    }
    RegExp sizeReg = RegExp(r'(\d+)');
    List<RegExpMatch> sizes = sizeReg.allMatches(style).toList();

    String? height = sizes[0].group(0);
    String? width = sizes[1].group(0);
    if (height == null || width == null) {
      return null;
    }
    return GalleryImage(
      url: coverUrl,
      height: double.parse(height),
      width: double.parse(width),
    );
  }

  static GalleryImage? _parseThumbnailGalleryCover(Element div) {
    Element? img = div.querySelector('.gl3t > a > img');
    if (img == null) {
      return null;
    }
    String coverUrl = img.attributes['data-src'] ?? img.attributes['src'] ?? '';

    /// eg: height:296px;width:250px
    String? style = img.attributes['style'];
    if (style == null) {
      return null;
    }
    RegExp sizeReg = RegExp(r'(\d+)');
    List<RegExpMatch> sizes = sizeReg.allMatches(style).toList();

    String? height = sizes[0].group(0);
    String? width = sizes[1].group(0);
    if (height == null || width == null) {
      return null;
    }
    return GalleryImage(
      url: coverUrl,
      height: double.parse(height),
      width: double.parse(width),
    );
  }

  static int? _parseCompactGalleryPageCount(Element tr) {
    List<Element> divs = tr.querySelectorAll('.gl4c.glhide > div');

    /// favorite page
    if (divs.isEmpty) {
      return null;
    }

    /// eg: '66 pages'
    String pageCountDesc = divs[1].text;
    return int.parse(pageCountDesc.split(' ')[0]);
  }

  static int? _parseExtendedGalleryPageCount(Element tr) {
    List<Element> divs = tr.querySelectorAll('.gl3e > div');

    /// favorite page
    if (divs.isEmpty) {
      return null;
    }

    /// eg: '66 pages'
    String pageCountDesc = divs[4].text;
    return int.parse(pageCountDesc.split(' ')[0]);
  }

  static int? _parseThumbnailGalleryPageCount(Element div) {
    List<Element> divs = div.querySelectorAll('.gl5t > div:nth-child(1) > div');

    /// favorite page
    if (divs.isEmpty) {
      return null;
    }

    /// eg: '66 pages'
    String pageCountDesc = divs[1].text;
    return int.parse(pageCountDesc.split(' ')[0]);
  }

  static double _parseGalleryRating(Element tr) {
    /// eg: style="background-position:-16px -1px;opacity:1"
    String style = tr.querySelector('.ir')?.attributes['style'] ?? '';
    if (style.isEmpty) {
      return 0;
    }

    RegExp offsetsReg = RegExp(r'-*(\d+)+px');
    List<RegExpMatch> offsets = offsetsReg.allMatches(style).toList();

    /// eg: '0px'  '-16px'  '-32px'
    String? xOffset = offsets[0].group(0);

    /// eg: '-1px'  '-21px'
    String? yOffset = offsets[1].group(0);

    if (xOffset == null || yOffset == null) {
      return 0;
    }

    int xOffsetInt = int.parse(xOffset.replaceAll('px', ''));
    int yOffsetInt = int.parse(yOffset.replaceAll('px', ''));

    double initValue = 5;
    initValue -= -xOffsetInt / 16;
    initValue -= yOffsetInt == -21 ? 0.5 : 0;

    return initValue;
  }

  static int? _parseMinimalGalleryFavoriteTagIndex(Element tr) {
    String? style = tr.querySelector('.gl2m > div:nth-child(2) > [id][style]')?.attributes['style'];
    if (style == null) {
      return null;
    }
    final String color = RegExp(r'border-color:#(\w{3});').firstMatch(style)?.group(1) ?? '';
    return ColorConsts.favoriteTagIndex[color]!;
  }

  static int? _parseCompactGalleryFavoriteTagIndex(Element tr) {
    String? style = tr.querySelector('.gl2c > div:nth-child(2) > [id][style]')?.attributes['style'];
    if (style == null) {
      return null;
    }
    final String color = RegExp(r'border-color:#(\w{3});').firstMatch(style)?.group(1) ?? '';
    return ColorConsts.favoriteTagIndex[color]!;
  }

  static int? _parseExtendedGalleryFavoriteTagIndex(Element tr) {
    String? style = tr.querySelector('.gl3e > [id][style]')?.attributes['style'];
    if (style == null) {
      return null;
    }
    final String color = RegExp(r'border-color:#(\w{3});').firstMatch(style)?.group(1) ?? '';
    return ColorConsts.favoriteTagIndex[color]!;
  }

  static int? _parseThumbnailGalleryFavoriteTagIndex(Element div) {
    String? style = div.querySelector('.gl5t > div > [id][style]')?.attributes['style'];
    if (style == null) {
      return null;
    }
    final String color = RegExp(r'border-color:#(\w{3});').firstMatch(style)?.group(1) ?? '';
    return ColorConsts.favoriteTagIndex[color]!;
  }

  static int? _parseFavoriteTagIndexByOffset(Document document) {
    String? style = document.querySelector('#fav > .i')?.attributes['style'];
    if (style == null) {
      return null;
    }
    int offset = int.parse(RegExp(r'background-position:0px -(\d+)px').firstMatch(style)!.group(1)!);
    return (offset - 2) ~/ 19;
  }

  static double _parseGalleryDetailsRealRating(Document document) {
    /// eg: 'Average: 4.76' 'Not Yet Rated'
    String raw = document.querySelector('#rating_label')?.text ?? '';
    return double.parse(RegExp(r'Average: (\d+.\d+\d+)').firstMatch(raw)?.group(1) ?? '0');
  }

  static int _parseGalleryDetailsFavoriteCount(Document document) {
    String? count = document.querySelector('#favcount')?.text;
    if (count == null || count == 'Never') {
      return 0;
    } else if (count == 'Once') {
      return 1;
    } else {
      return int.parse(count.split(' ')[0]);
    }
  }

  static List<GalleryComment> _parseGalleryDetailsComments(List<Element> commentElements) {
    return commentElements
        .map(
          (element) => GalleryComment(
            id: int.parse(element.querySelector('.c6')?.attributes['id']?.split('_')[1] ?? ''),
            username: element.querySelector('.c2 > .c3 > a')?.text,
            score: element.querySelector('.c2 > .c5.nosel > span')?.text ?? '',
            scoreDetails: element.querySelector('.c7')?.text.split(',').map((detail) => detail.trim()).toList() ?? [],
            content: element.querySelector('.c6')!,
            time: _parsePostedLocalTime(element),
            lastEditTime: _parsePostedEditedTime(element),
            fromMe: element.querySelector('.c2 > .c4.nosel > a')?.text == 'Edit',
          ),
        )
        .toList();
  }

  static String _parsePostedLocalTime(Element element) {
    /// eg: 'Posted on 10 March 2022, 03:49[ by: hibiki]'
    String postedTimeDesc = element.querySelector('.c2 > .c3')?.text ?? '';

    /// eg: '10 March 2022, 03:49'
    String postedTimeString = RegExp(r'Posted on (.+, .+)( by:)?').firstMatch(postedTimeDesc)?.group(1) ?? '';
    final DateTime postedUTCTime = DateFormat('dd MMMM yyyy, HH:mm', 'en_US').parseUtc(postedTimeString).toLocal();
    final String postedLocalTime = DateFormat('yyyy-MM-dd HH:mm').format(postedUTCTime);

    return postedLocalTime;
  }

  static String? _parsePostedEditedTime(Element element) {
    /// eg: '10 March 2022, 03:49'
    String? postedTimeString = element.querySelector('.c8 > strong')?.text;
    if (postedTimeString == null) {
      return null;
    }

    final DateTime postedUTCTime = DateFormat('dd MMMM yyyy, HH:mm', 'en_US').parseUtc(postedTimeString).toLocal();
    final String postedLocalTime = DateFormat('yyyy-MM-dd HH:mm').format(postedUTCTime);

    return postedLocalTime;
  }

  static List<GalleryThumbnail> _parseGalleryDetailsSmallThumbnails(List<Element> thumbNailElements) {
    return thumbNailElements.map((element) {
      String href = element.querySelector('div > a')?.attributes['href'] ?? '';
      String style = element.querySelector('div')?.attributes['style'] ?? '';

      return GalleryThumbnail(
        href: href,
        thumbUrl: RegExp(r'url\((.+)\)').firstMatch(style)?.group(1) ?? '',
        isLarge: false,
        thumbWidth: double.parse(RegExp(r'width:(\d+)?px').firstMatch(style)?.group(1) ?? '0'),
        thumbHeight: double.parse(RegExp(r'height:(\d+)?px').firstMatch(style)?.group(1) ?? '0') - 1,
        offSet: double.parse(RegExp(r'\) -(\d+)?px ').firstMatch(style)?.group(1) ?? '0'),
      );
    }).toList();
  }

  static List<GalleryThumbnail> _parseGalleryDetailsLargeThumbnails(List<Element> thumbNailElements) {
    return thumbNailElements.map((element) {
      String thumbUrl = element.querySelector('a > img')?.attributes['src'] ?? '';
      List<String> parts = thumbUrl.split('-');
      return GalleryThumbnail(
        href: element.querySelector('a')?.attributes['href'] ?? '',
        thumbUrl: thumbUrl,
        isLarge: true,
        thumbWidth: double.parse(parts[2]),
        thumbHeight: double.parse(parts[3]),
      );
    }).toList();
  }

  static List<VisitStat> _parseStats(Element tbody) {
    List<String> periods = tbody.querySelectorAll('tr:nth-child(4) > .stdk').map((e) => e.text).toList();
    List<String> visits = tbody.querySelectorAll('tr:nth-child(6) > .stdv').map((e) => e.text).toList();
    List<String> hits = tbody.querySelectorAll('tr:nth-child(8) > .stdv').map((e) => e.text).toList();

    double _parseNumber(String s) {
      if (s.endsWith('K')) {
        return double.parse(s.substring(0, s.length - 1)) * 1000;
      }
      if (s.endsWith('M')) {
        return double.parse(s.substring(0, s.length - 1)) * 1000 * 1000;
      }
      return double.parse(s);
    }

    List<VisitStat> stats = periods
        .mapIndexed(
          (index, period) => VisitStat(
            period: period,
            visits: _parseNumber(visits[index]),
            hits: _parseNumber(hits[index]),
          ),
        )
        .toList();

    /// remove empty data
    int beginIndex = stats.indexWhere((stat) => stat.visits > 0);
    return beginIndex == -1 ? [] : stats.sublist(beginIndex);
  }
}
