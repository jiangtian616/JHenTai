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
import 'package:jhentai/src/model/base_gallery.dart';
import 'package:jhentai/src/model/gallery_comment.dart';
import 'package:jhentai/src/model/gallery_detail.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_stats.dart';
import 'package:jhentai/src/model/gallery_tag.dart';
import 'package:jhentai/src/model/gallery_thumbnail.dart';
import 'package:jhentai/src/model/gallery_torrent.dart';
import 'package:jhentai/src/model/tag_set.dart';
import 'package:jhentai/src/setting/site_setting.dart';
import 'package:jhentai/src/utils/color_util.dart';

import '../database/database.dart';
import '../model/gallery.dart';
import '../pages/home/tab_view/ranklist/ranklist_view_state.dart';

T noOpParser<T>(v) => v as T;

class EHSpiderParser {
  static Map<String, dynamic> loginPage2UserInfoOrErrorMsg(Response response) {
    Map<String, dynamic> map = {};

    /// if login success, cookieHeaders's length = 4or5, otherwise 1.
    List<String>? cookieHeaders = response.headers['set-cookie'];
    bool success = cookieHeaders != null && cookieHeaders.length > 2;
    if (success) {
      map['ipbMemberId'] = int.parse(
        RegExp(r'ipb_member_id=(\d+);')
            .firstMatch(cookieHeaders.firstWhere((header) => header.contains('ipb_member_id')))!
            .group(1)!,
      );
      map['ipbPassHash'] = RegExp(r'ipb_pass_hash=(\w+);')
          .firstMatch(cookieHeaders.firstWhere((header) => header.contains('ipb_pass_hash')))!
          .group(1)!;
    } else {
      map['errorMsg'] = _parseLoginErrorMsg(response.data!);
    }
    return map;
  }

  static List<dynamic> galleryPage2GalleryList(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    String inlineType = document.querySelector('#dms > div > select > option[selected=selected]')?.text ?? '';

    switch (inlineType) {
      case 'Minimal':
        return _compactGalleryPage2GalleryList(response);
      case 'Minimal+':
        return _compactGalleryPage2GalleryList(response);
      case 'Compact':
        return _compactGalleryPage2GalleryList(response);
      case 'Extended':
        return _extendedGalleryPage2GalleryList(response);
      case 'Thumbnail':
        return _thumbnailGalleryPage2GalleryList(response);
      default:
        return _compactGalleryPage2GalleryList(response);
    }
  }

  static Gallery detailPage2Gallery(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    String galleryUrl = document.querySelector('#gd5 > p > a')!.attributes['href']!.split('?')[0];
    List<String>? parts = galleryUrl.split('/');
    String coverStyle = document.querySelector('#gd1 > div')?.attributes['style'] ?? '';
    RegExpMatch coverMatch = RegExp(r'width:(\d+)px.*height:(\d+)px.*url\((.*)\)').firstMatch(coverStyle)!;
    LinkedHashMap<String, List<GalleryTag>> tags = detailPage2Tags(document);

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
      pageCount: int.parse(
          (document.querySelector('#gdd > table > tbody > tr:nth-child(5) > .gdt2')?.text ?? '').split(' ')[0]),
      rating: _parseGalleryRating(document.querySelector('#grt2')!),
      hasRated: document.querySelector('#grt2 > #rating_image .ir.irg') != null ? true : false,
      isFavorite: document.querySelector('#fav > .i') != null ? true : false,
      favoriteTagIndex: _parseFavoriteTagIndexByOffset(document),
      favoriteTagName: document.querySelector('#fav > .i')?.attributes['style'] == null
          ? null
          : document.querySelector('#favoritelink')?.text,
      galleryUrl: galleryUrl,
      tags: tags,
      language: tags['language']?[0].tagData.key,
      uploader: document.querySelector('#gdn > a')?.text ?? '',
      publishTime: document.querySelector('#gdd > table > tbody > tr > .gdt2')?.text ?? '',
    );

    return gallery;
  }

  static Map<String, dynamic> detailPage2DetailAndApikey(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    GalleryDetail galleryDetail = GalleryDetail(
      rawTitle: document.querySelector('#gn')!.text,
      ratingCount: int.parse(document.querySelector('#rating_count')?.text ?? '0'),
      realRating: _parseGalleryDetailsRealRating(document),
      size: document.querySelector('#gdd > table > tbody')?.children[4].children[1].text ?? '',
      pageCount: int.parse(
          (document.querySelector('#gdd > table > tbody > tr:nth-child(5) > .gdt2')?.text ?? '').split(' ')[0]),
      favoriteCount: _parseGalleryDetailsFavoriteCount(document),
      torrentCount: RegExp(r'\d+')
              .firstMatch(document.querySelector('#gd5')?.children[2].querySelector('a')?.text ?? '')
              ?.group(0) ??
          '0',
      torrentPageUrl:
          document.querySelector('#gd5')?.children[2].querySelector('a')?.attributes['onclick']?.split('\'')[1] ?? '',
      archivePageUrl:
          document.querySelector('#gd5')?.children[1].querySelector('a')?.attributes['onclick']?.split('\'')[1] ?? '',
      fullTags: detailPage2Tags(document),
      comments: _parseGalleryDetailsComments(document.querySelectorAll('#cdiv > .c1')),
      thumbnails: detailPage2Thumbnails(response),
    );

    return {'galleryDetails': galleryDetail, 'apikey': _galleryDetailDocument2Apikey(document)};
  }

  static Map<String, dynamic> detailPage2GalleryAndDetailAndApikey(Response response) {
    Map<String, dynamic> map = detailPage2DetailAndApikey(response);
    map['gallery'] = detailPage2Gallery(response);
    return map;
  }

  static LinkedHashMap<String, List<GalleryTag>> detailPage2Tags(Document document) {
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
        String key = list.length == 1 ? list[0].substring(3).replaceAll('\_', ' ') : list[1].replaceAll('\_', ' ');

        tags.putIfAbsent(namespace, () => []).add(GalleryTag(tagData: TagData(namespace: namespace, key: key)));
      }
    }
    return tags;
  }

  static List<GalleryThumbnail> detailPage2Thumbnails(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    List<Element> thumbNailElements = document.querySelectorAll('#gdt > .gdtm');
    if (thumbNailElements.isNotEmpty) {
      return _parseGalleryDetailsSmallThumbnails(thumbNailElements);
    }
    thumbNailElements = document.querySelectorAll('#gdt > .gdtl');
    return _parseGalleryDetailsLargeThumbnails(thumbNailElements);
  }

  static List<GalleryComment> detailPage2Comments(Response response) {
    String html = response.data! as String;
    Document document = parse(html);
    List<Element> commentElements = document.querySelectorAll('#cdiv > .c1');
    return _parseGalleryDetailsComments(commentElements);
  }

  static Map<RanklistType, List<BaseGallery>> rankPage2Ranklists(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    List<Element> rankLists = document.querySelectorAll('.dc > .tdo');

    return {
      RanklistType.allTime: _parseRanklist(rankLists[0]),
      RanklistType.year: _parseRanklist(rankLists[1]),
      RanklistType.month: _parseRanklist(rankLists[2]),
      RanklistType.day: _parseRanklist(rankLists[3]),
    };
  }

  static String? forumPage2UserInfo(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    /// cookie is wrong, not logged in
    if (document.querySelector('.pcen') != null) {
      return null;
    }

    return document.querySelector('.home > b > a')!.text;
  }

  static List<String> favoritePopup2FavoriteTagNames(Response response) {
    String html = response.data! as String;
    Document document = parse(html);
    List<Element> divs = document.querySelectorAll('.nosel > div');
    return divs.map((div) => div.querySelector('div:nth-child(5)')?.text ?? '').toList();
  }

  static LinkedHashMap<String, int> favoritePage2FavoriteTags(Response response) {
    String html = response.data! as String;
    Document document = parse(html);
    List<Element> divs = document.querySelectorAll('.nosel > .fp');

    /// not favorite tag
    divs.removeLast();
    LinkedHashMap<String, int> tagNames2Count = LinkedHashMap();

    for (Element div in divs) {
      String tagName = div.querySelector('div:last-child')?.text ?? '';
      int favoriteCount = int.parse(div.querySelector('div:first-child')?.text ?? '0');
      tagNames2Count.putIfAbsent(tagName, () => favoriteCount);
    }

    return tagNames2Count;
  }

  static GalleryImage imagePage2GalleryImage(Response response) {
    String html = response.data! as String;
    Document document = parse(html);
    Element img = document.querySelector('#img')!;

    /// height: 1600px; width: 1124px;
    String style = img.attributes['style']!;
    String url = img.attributes['src']!;

    if (url.contains('509.gif')) {
      throw DioError(
        requestOptions: response.requestOptions,
        error: EHException(type: EHExceptionType.exceedLimit, msg: 'exceedImageLimits'.tr),
      );
    }
    return GalleryImage(
      url: url,
      height: double.parse(RegExp(r'height:(\d+)px').firstMatch(style)!.group(1)!),
      width: double.parse(RegExp(r'width:(\d+)px').firstMatch(style)!.group(1)!),
    );
  }

  static String? sendComment2ErrorMsg(Response response) {
    String? html = response.data;
    if (html?.isEmpty ?? true) {
      return null;
    }
    Document document = parse(html);
    return document.querySelector('p.br')?.text;
  }

  static List<GalleryTorrent> torrentPage2GalleryTorrent(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

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
          magnetUrl:
              'magnet:?xt=urn:btih:${trs[2].querySelector('td > a')!.attributes['href']!.split('.')[1].split('/').last}',
        );
      },
    ).toList();
  }

  static Map<String, dynamic> settingPage2SiteSetting(Response response) {
    String html = response.data! as String;
    Document document = parse(html);
    List<Element> items = document.querySelectorAll('.optouter');
    Map<String, dynamic> map = {};

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

    Element thumbnailSetting = items[18];
    map['isLargeThumbnail'] =
        thumbnailSetting.querySelector('#tssel > div > label > input[checked=checked]')!.parent!.text == ' Large'
            ? true
            : false;
    map['thumbnailRows'] =
        int.parse(thumbnailSetting.querySelector('#trsel > div > label > input[checked=checked]')!.parent!.text);
    return map;
  }

  static Map<String, int> homePage2ImageLimit(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    Map<String, int> map = {
      'currentConsumption': int.parse(document.querySelector('.stuffbox > .homebox > p > strong:nth-child(1)')!.text),
      'totalLimit': int.parse(document.querySelector('.stuffbox > .homebox > p > strong:nth-child(3)')!.text),
      'resetCost': int.parse(document.querySelector('.stuffbox > .homebox > p:nth-child(3) > strong')!.text),
    };

    return map;
  }

  static Map<String, dynamic> myTagsPage2TagSetNamesAndTagSetsAndApikey(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    List<Element> options = document.querySelectorAll('#tagset_outer > div > select > option');
    List<String> tagSetNames = options.map((o) => o.text).toList();

    List<Element> tagDivs = document.querySelectorAll('#usertags_outer > div').sublist(1);
    List<TagSet> tagSets = tagDivs.map(
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
          color: aRGBString2Color(div.querySelector('div:nth-child(9) > input')?.attributes['value']),
          weight: int.parse(div.querySelector('div:nth-child(11) > input')!.attributes['value']!),
        );
      },
    ).toList();

    String apikey = RegExp(r'apikey = \"(.*)\"')
        .firstMatch(document.querySelector('#outer > script:nth-child(1)')!.text)!
        .group(1)!;

    return {
      'tagSetNames': tagSetNames,
      'tagSets': tagSets,
      'apikey': apikey,
    };
  }

  static GalleryStats statPage2GalleryStats(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    Element rankScoreTbody = document.querySelector('.stuffbox > div > div > table > tbody')!;
    Element yearlyStatTbody = document.querySelector('.stuffbox > div > div:nth-child(1) > table > tbody')!;
    Element monthlyStatTbody = document.querySelector('.stuffbox > div > div:nth-child(2) > table > tbody')!;
    Element dailyStatTbody = document.querySelector('.stuffbox > table > tbody')!;

    return GalleryStats(
      totalVisits: int.parse(
          document.querySelector('.stuffbox > div > div > p:nth-child(3) > strong')!.text.replaceAll(',', '')),
      allTimeRanking: int.tryParse(
          rankScoreTbody.querySelector('tr:nth-child(2) > td:nth-child(4)')?.text.replaceAll(',', '') ?? ''),
      allTimeScore: int.tryParse(
          rankScoreTbody.querySelector('tr:nth-child(2) > td:nth-child(5)')?.text.replaceAll(',', '') ?? ''),
      yearRanking: int.tryParse(
          rankScoreTbody.querySelector('tr:nth-child(4) > td:nth-child(4)')?.text.replaceAll(',', '') ?? ''),
      yearScore: int.tryParse(
          rankScoreTbody.querySelector('tr:nth-child(4) > td:nth-child(5)')?.text.replaceAll(',', '') ?? ''),
      monthRanking: int.tryParse(
          rankScoreTbody.querySelector('tr:nth-child(6) > td:nth-child(4)')?.text.replaceAll(',', '') ?? ''),
      monthScore: int.tryParse(
          rankScoreTbody.querySelector('tr:nth-child(6) > td:nth-child(5)')?.text.replaceAll(',', '') ?? ''),
      dayRanking: int.tryParse(
          rankScoreTbody.querySelector('tr:nth-child(8) > td:nth-child(4)')?.text.replaceAll(',', '') ?? ''),
      dayScore: int.tryParse(
          rankScoreTbody.querySelector('tr:nth-child(8) > td:nth-child(5)')?.text.replaceAll(',', '') ?? ''),
      yearlyStats: _parseStats(yearlyStatTbody),
      monthlyStats: _parseStats(monthlyStatTbody),
      dailyStats: _parseStats(dailyStatTbody),
    );
  }

  static String imageLookup2RedirectUrl(Response response) {
    return response.headers['Location']!.first;
  }

  static String _parseLoginErrorMsg(String html) {
    if (html.contains('The captcha was not entered correctly')) {
      return 'needCaptcha'.tr;
    }
    return 'userNameOrPasswordMismatch'.tr;
  }

  static List<dynamic> _compactGalleryPage2GalleryList(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    List<Element> galleryListElements = document.querySelectorAll('.itg.gltc > tbody > tr');

    /// no data
    if (galleryListElements.isEmpty) {
      return [<Gallery>[], 0];
    }

    /// remove table header
    galleryListElements.removeAt(0);

    /// remove ad or [no result row]
    galleryListElements.removeWhere((element) => element.children.length == 1);
    List<Gallery> gallerys = galleryListElements.map((e) => _parseCompactGallery(e)).toList();

    int pageCount = gallerys.isEmpty ? 0 : galleryPage2TotalPageCount(document);
    return [gallerys, pageCount];
  }

  static List<dynamic> _extendedGalleryPage2GalleryList(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    List<Element> galleryListElements = document.querySelectorAll('.itg.glte > tbody > tr');

    /// no data
    if (galleryListElements.isEmpty) {
      return [<Gallery>[], 0];
    }

    /// remove ad
    galleryListElements.removeWhere((element) => element.children.length == 1);
    List<Gallery> gallerys = galleryListElements.map((e) => _parseExtendedGallery(e)).toList();

    int pageCount = gallerys.isEmpty ? 0 : galleryPage2TotalPageCount(document);
    return [gallerys, pageCount];
  }

  static List<dynamic> _thumbnailGalleryPage2GalleryList(Response response) {
    String html = response.data! as String;
    Document document = parse(html);

    List<Element> galleryListElements = document.querySelectorAll('.itg.gld > div');

    /// no data
    if (galleryListElements.isEmpty) {
      return [<Gallery>[], 0];
    }

    List<Gallery> gallerys = galleryListElements.map((e) => _parseThumbnailGallery(e)).toList();

    int pageCount = gallerys.isEmpty ? 0 : galleryPage2TotalPageCount(document);
    return [gallerys, pageCount];
  }

  static int galleryPage2TotalPageCount(Document document) {
    Element? tr = document.querySelector('.ptt > tbody > tr');
    Element? td = tr?.children[tr.children.length - 2];
    return int.parse(td?.querySelector('a')?.text ?? '1');
  }

  static List<TagData> tagSuggestion2TagList(Response response) {
    Map resp = jsonDecode(response.data!);
    if (resp['tags'] is! Map) {
      return <TagData>[];
    }
    Map tags = resp['tags'];
    return tags.values.map((e) => TagData(namespace: e['ns'], key: e['tn'])).toList();
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
      hasRated: tr.querySelector('.gl2c > div:nth-child(2) > .ir.irb') != null ? true : false,
      isFavorite: tr.querySelector('.gl2c > div:nth-child(2) > [id][style]') != null ? true : false,
      favoriteTagIndex: _parseCompactGalleryFavoriteTagIndex(tr),
      favoriteTagName: tr.querySelector('.gl2c > div:nth-child(2) > [id][style]')?.attributes['title'],
      galleryUrl: galleryUrl,
      tags: tags,
      language: tags['language']?[0].tagData.key,
      uploader: tr.querySelector('.gl4c.glhide > div > a')?.text ?? '',
      publishTime: tr.querySelector('.gl2c > div:nth-child(2) > [id]')?.text ?? '',
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
      hasRated: tr.querySelector('.gl3e > .ir.irb') != null ? true : false,
      isFavorite: tr.querySelector('.gl3e > [id][style]') != null ? true : false,
      favoriteTagIndex: _parseExtendedGalleryFavoriteTagIndex(tr),
      favoriteTagName: tr.querySelector('.gl3e > [id][style]')?.attributes['title'],
      galleryUrl: galleryUrl,
      tags: tags,
      language: tags['language']?[0].tagData.key,
      uploader: tr.querySelector('.gl3e > div > a')?.text ?? '',
      publishTime: tr.querySelector('.gl3e > div[id]')?.text ?? '',
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
      hasRated: div.querySelector('.gl5t > div > .ir.irb') != null ? true : false,
      isFavorite: div.querySelector('.gl5t > div > [id][style]') != null ? true : false,
      favoriteTagIndex: _parseThumbnailGalleryFavoriteTagIndex(div),
      favoriteTagName: div.querySelector('.gl5t > div > [id][style]')?.attributes['title'],
      galleryUrl: galleryUrl,
      tags: LinkedHashMap(),
      publishTime: div.querySelector('.gl5t > div > div[id]')?.text ?? '',
    );

    return gallery;
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

  static LinkedHashMap<String, List<GalleryTag>> _parseExtendedGalleryTags(Element tr) {
    LinkedHashMap<String, List<GalleryTag>> tags = LinkedHashMap();
    List<Element> tagDivs =
        tr.querySelectorAll('.gl2e > div > a > div > div:nth-child(1) > table > tbody > tr > td > div').toList();
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

  static List<BaseGallery> _parseRanklist(Element ranklistDiv) {
    List<Element> trs = ranklistDiv.querySelectorAll('table > tbody > tr');
    return trs
        .map(
          (tr) => BaseGallery(
            galleryUrl: tr.querySelector('.tun > a')!.attributes['href']!,
            title: tr.querySelector('.tun > a')!.text,
          ),
        )
        .toList();
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
            userName: element.querySelector('.c2 > .c3')?.children[0].text ?? '',
            score: element.querySelector('.c2 > .c5.nosel > span')?.text ?? '',
            content: element.querySelector('.c6')?.outerHtml ?? '',
            time: _parsePostedLocalTime(element),
            lastEditTime: _parsePostedEditedTime(element),
          ),
        )
        .toList();
  }

  static String _parsePostedLocalTime(Element element) {
    /// eg: 'Posted on 10 March 2022, 03:49 by: hibiki'
    String postedTimeDesc = element.querySelector('.c2 > .c3')?.text ?? '';

    /// eg: '10 March 2022, 03:49'
    String postedTimeString = RegExp(r'Posted on (.+, .+) by:').firstMatch(postedTimeDesc)?.group(1) ?? '';
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

  static String _galleryDetailDocument2Apikey(Document document) {
    String script = document.querySelector('.gm')?.previousElementSibling?.text ?? '';
    return RegExp(r'var apikey = "(\w+)"').firstMatch(script)?.group(1) ?? '';
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
