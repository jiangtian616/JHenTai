import 'package:collection/collection.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/utils/string_uril.dart';
import 'package:xml/xml.dart';

abstract interface class ComicInfo {
  String? get title => null;

  /// Title of the series the book is part of
  String? get series => null;

  String? get alternateSeries => null;

  /// Number of the book in the series
  String? get number => null;

  String? get alternateNumber => null;

  /// The total number of books in the series
  int? get count => null;

  int? get alternateCount => null;

  /// Volume containing the book. Volume is a notion that is specific to US Comics, where the same series can have multiple volumes.
  /// Volumes can be referenced by numer (1, 2, 3…) or by year (2018, 2020…)
  int? get volume => null;

  /// A description or summary of the book
  String? get summary => null;

  /// A free text field, usually used to store information about the application that created the ComicInfo.xml file
  String? get notes => null;

  /// Usually contains the release date of the book
  int? get year => null;

  /// Usually contains the release date of the book
  int? get month => null;

  /// Usually contains the release date of the book
  int? get day => null;

  /// Person or organization responsible for creating the scenario.
  String? get writer => null;

  /// Person or organization responsible for drawing the art.
  String? get penciller => null;

  /// Person or organization responsible for inking the pencil art.
  String? get inker => null;

  /// Person or organization responsible for applying color to drawings.
  String? get colorist => null;

  /// Person or organization responsible for drawing text and speech bubbles.
  String? get letterer => null;

  /// Person or organization responsible for drawing the cover art.
  String? get coverArtist => null;

  /// A person or organization contributing to a resource by revising or elucidating the content
  /// e.g., adding an introduction, notes, or other critical matter. An editor may also prepare a resource for production, publication, or distribution.
  String? get editor => null;

  /// A person or organization who renders a text from one language into another, or from an older form of a language into the modern form.
  String? get translator => null;

  /// A person or organization responsible for publishing, releasing, or issuing a resource.
  String? get publisher => null;

  /// An imprint is a group of publications under the umbrella of a larger imprint or a Publisher. For example, Vertigo is an Imprint of DC Comics.
  String? get imprint => null;

  /// Genre of the book or series. For example, Science-Fiction or Shonen.
  String? get genre => null;

  String? get tags => null;

  /// A URL pointing to a reference website for the book.
  String? get web => null;

  /// The number of pages in the book.
  int? get pageCount => null;

  /// A language code describing the language of the book.
  String? get languageISO => null;

  /// The original publication's binding format for scanned physical books or presentation format for digital sources.
  /// "TBP", "HC", "Web", "Digital" are common designators.
  String? get format => null;

  YesEnum? get blackAndWhite => null;

  MangaEnum? get manga => null;

  /// Characters present in the book.
  String? get characters => null;

  /// Teams present in the book. Usually refer to super-hero teams (e.g. Avengers).
  String? get teams => null;

  /// Locations mentioned in the book.
  String? get locations => null;

  /// Main character or team mentioned in the book.
  String? get mainCharacterOrTeam => null;

  /// A free text field, usually used to store information about who scanned the book.
  String? get scanInformation => null;

  /// The story arc that books belong to.
  /// For example, for Undiscovered Country, issues 1-6 are part of the Destiny story arc, issues 7-12 are part of the Unity story arc.
  String? get storyArc => null;

  String? get storyArcNumber => null;

  /// A group or collection the series belongs to.
  String? get seriesGroup => null;

  AgeRatingEnum? get ageRating => null;

  double? get communityRating => null;

  String? get review => null;

  String? get GTIN => null;

  List<ComicPageInfo>? get pages => null;

  XmlDocument toXmlDocument();
}

class ComicPageInfo {
  /// Page number
  int? get image => null;

  String? get type => null;

  bool? get doublePage => null;

  int? get imageSize => null;

  String? get key => null;

  /// ComicRack uses this field when adding a bookmark in a book.
  String? get bookmark => null;

  int? get imageWidth => null;

  int? get imageHeight => null;
}

enum YesEnum {
  no('No'),
  yes('Yes'),
  yesAndRightToLeft('YesAndRightToLeft'),
  ;

  final String desc;

  const YesEnum(this.desc);

  static YesEnum fromString(String value) {
    switch (value) {
      case 'No':
        return no;
      case 'Yes':
        return yes;
      case 'YesAndRightToLeft':
        return yesAndRightToLeft;
      default:
        return no;
    }
  }
}

enum MangaEnum {
  unknown('Unknown'),
  no('No'),
  yes('Yes'),
  yesAndRightToLeft('YesAndRightToLeft'),
  ;

  final String desc;

  const MangaEnum(this.desc);

  static MangaEnum fromString(String value) {
    switch (value) {
      case 'Unknown':
        return unknown;
      case 'No':
        return no;
      case 'Yes':
        return yes;
      case 'YesAndRightToLeft':
        return yesAndRightToLeft;
      default:
        return unknown;
    }
  }
}

enum AgeRatingEnum {
  unknown('Unknown'),
  adults('Adults Only 18+'),
  earlyChildhood('Early Childhood'),
  everyone('Everyone'),
  everyone10Plus('Everyone 10+'),
  g('G'),
  kidsToAdults('Kids to Adults'),
  m('M'),
  mA15Plus('MA15+'),
  mature17Plus('Mature 17+'),
  pg('PG'),
  r18Plus('R18+'),
  ratingPending('Rating Pending'),
  teen('Teen'),
  x18Plus('X18+'),
  ;

  final String desc;

  const AgeRatingEnum(this.desc);

  static AgeRatingEnum fromString(String value) {
    switch (value) {
      case 'Unknown':
        return unknown;
      case 'Adults Only 18+':
        return adults;
      case 'Early Childhood':
        return earlyChildhood;
      case 'Everyone':
        return everyone;
      case 'Everyone 10+':
        return everyone10Plus;
      case 'G':
        return g;
      case 'Kids to Adults':
        return kidsToAdults;
      case 'M':
        return m;
      case 'MA15+':
        return mA15Plus;
      case 'Mature 17+':
        return mature17Plus;
      case 'PG':
        return pg;
      case 'R18+':
        return r18Plus;
      case 'Rating Pending':
        return ratingPending;
      case 'Teen':
        return teen;
      case 'X18+':
        return x18Plus;
      default:
        return unknown;
    }
  }
}

enum ComicPageTypeEnum {
  frontCover('FrontCover'),
  innerCover('InnerCover'),
  roundup('Roundup'),
  story('Story'),
  advertisement('Advertisement'),
  editorial('Editorial'),
  letters('Letters'),
  preview('Preview'),
  backCover('BackCover'),
  other('Other'),
  deleted('Deleted'),
  ;

  final String desc;

  const ComicPageTypeEnum(this.desc);

  static ComicPageTypeEnum fromString(String value) {
    switch (value) {
      case 'FrontCover':
        return frontCover;
      case 'InnerCover':
        return innerCover;
      case 'Roundup':
        return roundup;
      case 'Story':
        return story;
      case 'Advertisement':
        return advertisement;
      case 'Editorial':
        return editorial;
      case 'Letters':
        return letters;
      case 'Preview':
        return preview;
      case 'BackCover':
        return backCover;
      case 'Other':
        return other;
      case 'Deleted':
        return deleted;
      default:
        return other;
    }
  }
}

class EHGalleryComicInfo extends ComicInfo {
  String rawTitle;
  String? japaneseTitle;
  final String category;
  @override
  final int pageCount;
  final String galleryUrl;
  final String? uploader;
  final String publishTime;
  final String? languageAbbreviation;
  @override
  final List<TagData> tagDatas;
  final double rating;

  @override
  String get title => rawTitle;

  @override
  String get series => rawTitle;

  @override
  String? get alternateSeries => japaneseTitle;

  @override
  String? get writer => tagDatas.where((tagData) => tagData.namespace == 'artist').map((tagData) => tagData.key).join(',');

  @override
  String? get penciller => tagDatas.where((tagData) => tagData.namespace == 'artist').map((tagData) => tagData.key).join(',');

  @override
  String get genre => category;

  @override
  String? get tags => tagDatas.map((tagData) => '${tagData.namespace}:${tagData.key}').join(',');

  @override
  String get web => galleryUrl;

  @override
  String? get languageISO => languageAbbreviation;

  @override
  YesEnum get blackAndWhite => tagDatas.none((tagData) => tagData.key == 'full color') ? YesEnum.yes : YesEnum.no;

  @override
  MangaEnum get manga => category == 'Manga' ? MangaEnum.yes : MangaEnum.no;

  @override
  String get characters => tagDatas.where((tagData) => tagData.namespace == 'character').map((tagData) => tagData.key).join(',');

  @override
  AgeRatingEnum get ageRating => category == 'Non-H' ? AgeRatingEnum.kidsToAdults : AgeRatingEnum.adults;

  @override
  double get communityRating => rating;
  
  @override
  String get locations => tagDatas.where((tagData) => tagData.namespace == 'location').map((tagData) => tagData.key).join(',');

  EHGalleryComicInfo({
    required this.rawTitle,
    this.japaneseTitle,
    required this.category,
    required this.pageCount,
    required this.galleryUrl,
    this.uploader,
    required this.publishTime,
    this.languageAbbreviation,
    required this.tagDatas,
    required this.rating,
  });

  @override
  XmlDocument toXmlDocument() {
    XmlBuilder builder = XmlBuilder();

    builder.processing('xml', 'version="1.0"');

    builder.element(
      'ComicInfo',
      nest: () {
        builder.attribute('xmlns:xsi', 'http://www.w3.org/2001/XMLSchema-instance');
        builder.attribute('xmlns:xsn', 'http://www.w3.org/2001/XMLSchema');

        builder.element('Title', nest: title);
        builder.element('Series', nest: series);
        if (!isEmptyOrNull(alternateSeries)) {
          builder.element('AlternateSeries', nest: alternateSeries);
        }
        if (!isEmptyOrNull(writer)) {
          builder.element('Writer', nest: writer);
        }
        if (!isEmptyOrNull(penciller)) {
          builder.element('Penciller', nest: penciller);
        }
        builder.element('Genre', nest: genre);
        builder.element('Tags', nest: tags);
        builder.element('Web', nest: web);
        builder.element('PageCount', nest: pageCount);
        if (!isEmptyOrNull(languageISO)) {
          builder.element('LanguageISO', nest: languageISO);
        }
        builder.element('BlackAndWhite', nest: blackAndWhite.desc);
        builder.element('Manga', nest: manga.desc);
        if (!isEmptyOrNull(characters)) {
          builder.element('Characters', nest: characters);
        }
        if (!isEmptyOrNull(locations)) {
          builder.element('Locations', nest: locations);
        }
        builder.element('AgeRating', nest: ageRating.desc);
        builder.element('CommunityRating', nest: communityRating.toStringAsFixed(1));
      },
    );

    return builder.buildDocument();
  }
}
