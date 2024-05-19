import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_disposable.dart';
import 'package:get/get_utils/get_utils.dart';
import 'package:get/instance_manager.dart';
import 'package:jhentai/src/database/dao/block_rule_dao.dart';
import 'package:jhentai/src/database/database.dart';
import 'package:jhentai/src/model/gallery.dart';

import '../model/gallery_comment.dart';
import '../model/gallery_tag.dart';
import '../utils/log.dart';

class LocalBlockRuleService extends GetxService {
  final List<LocalBlockRuleHandler> handlers = [];

  static void init() {
    Get.put(LocalBlockRuleService(), permanent: true);
  }

  @override
  void onInit() {
    handlers.addAll([
      GalleryTagEqualLocalBlockRuleHandler(),
      GalleryUploaderEqualLocalBlockRuleHandler(),
      CommentUsernameEqualLocalBlockRuleHandler(),
      CommentUserIdEqualLocalBlockRuleHandler(),
      CommentScoreGreaterThanLocalBlockRuleHandler(),
      CommentScoreGreaterThanEqualLocalBlockRuleHandler(),
      CommentScoreSmallerThanLocalBlockRuleHandler(),
      CommentScoreSmallerThanEqualLocalBlockRuleHandler(),
      GalleryTitleLikeLocalBlockRuleHandler(),
      GalleryTagLikeLocalBlockRuleHandler(),
      GalleryUploaderLikeLocalBlockRuleHandler(),
      CommentUserNameLikeLocalBlockRuleHandler(),
      GalleryTitleRegexLocalBlockRuleHandler(),
      GalleryTagRegexLocalBlockRuleHandler(),
      GalleryUploaderRegexLocalBlockRuleHandler(),
      CommentUserNameRegexLocalBlockRuleHandler(),
    ]);

    Log.debug('init LocalBlockRuleService success');
    super.onInit();
  }

  LocalBlockRuleHandler getHandlerByRule(LocalBlockRule rule) => handlers.where((h) => h.matchRule(rule)).sorted((a, b) => a.order - b.order).first;

  Future<List<LocalBlockRule>> getBlockRules() async {
    List<BlockRuleData> datas = await BlockRuleDao.selectBlockRules();
    return datas
        .map(
          (data) => LocalBlockRule(
            id: data.id,
            target: LocalBlockTargetEnum.fromCode(data.target),
            attribute: LocalBlockAttributeEnum.fromCode(data.attribute),
            pattern: LocalBlockPatternEnum.fromCode(data.pattern),
            expression: data.expression,
          ),
        )
        .toList();
  }

  Future<({bool success, String? msg})> upsertBlockRule(LocalBlockRule rule) async {
    Log.info('Upsert block rule: $rule');

    LocalBlockRuleHandler handler = getHandlerByRule(rule);
    ({bool success, String? msg}) validateResult = handler.validateRule(rule);
    if (!validateResult.success) {
      Log.info('Upsert block rule failed, result:$validateResult');
      return validateResult;
    }

    await BlockRuleDao.upsertBlockRule(
      BlockRuleCompanion(
        id: rule.id == null ? const Value.absent() : Value(rule.id!),
        target: Value(rule.target.code),
        attribute: Value(rule.attribute.code),
        pattern: Value(rule.pattern.code),
        expression: Value(rule.expression),
      ),
    );

    return Future.value((success: true, msg: null));
  }

  Future<({bool success, String? msg})> removeLocalBlockRule(int id) async {
    Log.info('Remove block rule: $id');

    bool success = await BlockRuleDao.deleteBlockRule(id) > 0;
    if (!success) {
      Log.error('Remove block rule failed, update database failed.');
      return Future.value((success: false, msg: 'Update database failed'));
    }

    return Future.value((success: true, msg: null));
  }

  Future<List<T>> executeRules<T>(List<T> items) async {
    List<T> results = List.of(items);

    LocalBlockTargetEnum? targetEnum = LocalBlockTargetEnum.values.where((e) => e.model == T).firstOrNull;
    if (targetEnum == null) {
      return results;
    }

    try {
      List<BlockRuleData> datas = await BlockRuleDao.selectBlockRulesByTarget(targetEnum.code);
      for (BlockRuleData data in datas) {
        LocalBlockRule rule = LocalBlockRule(
          target: LocalBlockTargetEnum.fromCode(data.target),
          attribute: LocalBlockAttributeEnum.fromCode(data.attribute),
          pattern: LocalBlockPatternEnum.fromCode(data.pattern),
          expression: data.expression,
        );

        LocalBlockRuleHandler handler = getHandlerByRule(rule);
        results.removeWhere((item) => handler.executeRule(item, rule));
      }
    } catch (e) {
      Log.error('executeRules failed, items:$items', e);
    }

    return results;
  }
}

abstract interface class LocalBlockRuleHandler<ITEM> {
  int get order;

  bool matchRule(LocalBlockRule rule);

  ({bool success, String? msg}) validateRule(LocalBlockRule rule);

  bool executeRule(ITEM item, LocalBlockRule rule);
}

abstract interface class AttributeGetter<ATTRIBUTE, I> extends LocalBlockRuleHandler<I> {
  bool matchRuleAttribute(LocalBlockAttributeEnum attribute);

  List<ATTRIBUTE> getItemAttributes(I item);
}

mixin GalleryTitleAttributeGetter on AttributeGetter<String, Gallery> {
  @override
  bool matchRuleAttribute(LocalBlockAttributeEnum attribute) {
    return attribute == LocalBlockAttributeEnum.title;
  }

  @override
  List<String> getItemAttributes(Gallery item) {
    return [item.title];
  }
}

mixin GalleryTagAttributeGetter on AttributeGetter<String, Gallery> {
  @override
  bool matchRuleAttribute(LocalBlockAttributeEnum attribute) {
    return attribute == LocalBlockAttributeEnum.tag;
  }

  @override
  List<String> getItemAttributes(Gallery item) {
    List<String> tagStrings = [];

    for (List<GalleryTag> tags in item.tags.values) {
      for (GalleryTag tag in tags) {
        tagStrings.add('${tag.tagData.namespace}:${tag.tagData.key}');
        if (tag.tagData.translatedNamespace != null && tag.tagData.tagName != null) {
          tagStrings.add('${tag.tagData.translatedNamespace}:${tag.tagData.tagName}');
        }
      }
    }

    return tagStrings;
  }
}

mixin GalleryUploaderAttributeGetter on AttributeGetter<String, Gallery> {
  @override
  bool matchRuleAttribute(LocalBlockAttributeEnum attribute) {
    return attribute == LocalBlockAttributeEnum.uploader;
  }

  @override
  List<String> getItemAttributes(covariant Gallery item) {
    return [if (item.uploader != null) item.uploader!];
  }
}

mixin CommentUsernameAttributeGetter on AttributeGetter<String, GalleryComment> {
  @override
  bool matchRuleAttribute(LocalBlockAttributeEnum attribute) {
    return attribute == LocalBlockAttributeEnum.userName;
  }

  @override
  List<String> getItemAttributes(covariant GalleryComment item) {
    return [if (item.username != null) item.username!];
  }
}

mixin CommentUserIdAttributeGetter on AttributeGetter<String, GalleryComment> {
  @override
  bool matchRuleAttribute(LocalBlockAttributeEnum attribute) {
    return attribute == LocalBlockAttributeEnum.userId;
  }

  @override
  List<String> getItemAttributes(covariant GalleryComment item) {
    return [if (item.userId != null) item.userId!.toString()];
  }
}

mixin CommentScoreAttributeGetter on AttributeGetter<double, GalleryComment> {
  @override
  bool matchRuleAttribute(LocalBlockAttributeEnum attribute) {
    return attribute == LocalBlockAttributeEnum.score;
  }

  @override
  List<double> getItemAttributes(covariant GalleryComment item) {
    if (item.score.isEmpty) {
      return [];
    }
    return [double.parse(item.score)];
  }
}

abstract class EqualLocalBlockRuleHandler<ITEM> implements LocalBlockRuleHandler<ITEM>, AttributeGetter<String, ITEM> {
  @override
  int get order => 10;

  @override
  bool executeRule(ITEM item, LocalBlockRule rule) {
    List<String> attribute = getItemAttributes(item);
    return attribute.any((a) => a == rule.expression);
  }

  @override
  bool matchRule(LocalBlockRule rule) {
    return rule.pattern == LocalBlockPatternEnum.equal && matchRuleAttribute(rule.attribute);
  }

  @override
  ({String? msg, bool success}) validateRule(LocalBlockRule rule) {
    return (success: true, msg: null);
  }
}

abstract class GreaterThanLocalBlockRuleHandler<ITEM> implements LocalBlockRuleHandler<ITEM>, AttributeGetter<double, ITEM> {
  @override
  int get order => 10;

  @override
  bool executeRule(ITEM item, LocalBlockRule rule) {
    List<double> attribute = getItemAttributes(item);
    return attribute.any((a) => a > double.parse(rule.expression));
  }

  @override
  bool matchRule(LocalBlockRule rule) {
    return rule.pattern == LocalBlockPatternEnum.gt && matchRuleAttribute(rule.attribute);
  }

  @override
  ({String? msg, bool success}) validateRule(LocalBlockRule rule) {
    if (double.tryParse(rule.expression) == null) {
      return (success: false, msg: 'inputNumberHint'.tr);
    } else {
      return (success: true, msg: null);
    }
  }
}

abstract class GreaterThanEqualLocalBlockRuleHandler<ITEM> implements LocalBlockRuleHandler<ITEM>, AttributeGetter<double, ITEM> {
  @override
  int get order => 10;

  @override
  bool executeRule(ITEM item, LocalBlockRule rule) {
    List<double> attribute = getItemAttributes(item);
    return attribute.any((a) => a >= double.parse(rule.expression));
  }

  @override
  bool matchRule(LocalBlockRule rule) {
    return rule.pattern == LocalBlockPatternEnum.gte && matchRuleAttribute(rule.attribute);
  }

  @override
  ({String? msg, bool success}) validateRule(LocalBlockRule rule) {
    if (double.tryParse(rule.expression) == null) {
      return (success: false, msg: 'inputNumberHint'.tr);
    } else {
      return (success: true, msg: null);
    }
  }
}

abstract class SmallerThanLocalBlockRuleHandler<ITEM> implements LocalBlockRuleHandler<ITEM>, AttributeGetter<double, ITEM> {
  @override
  int get order => 10;

  @override
  bool executeRule(ITEM item, LocalBlockRule rule) {
    List<double> attribute = getItemAttributes(item);
    return attribute.any((a) => a < double.parse(rule.expression));
  }

  @override
  bool matchRule(LocalBlockRule rule) {
    return rule.pattern == LocalBlockPatternEnum.st && matchRuleAttribute(rule.attribute);
  }

  @override
  ({String? msg, bool success}) validateRule(LocalBlockRule rule) {
    if (double.tryParse(rule.expression) == null) {
      return (success: false, msg: 'inputNumberHint'.tr);
    } else {
      return (success: true, msg: null);
    }
  }
}

abstract class SmallerThanEqualLocalBlockRuleHandler<ITEM> implements LocalBlockRuleHandler<ITEM>, AttributeGetter<double, ITEM> {
  @override
  int get order => 10;

  @override
  bool executeRule(ITEM item, LocalBlockRule rule) {
    List<double> attribute = getItemAttributes(item);
    return attribute.any((a) => a <= double.parse(rule.expression));
  }

  @override
  bool matchRule(LocalBlockRule rule) {
    return rule.pattern == LocalBlockPatternEnum.ste && matchRuleAttribute(rule.attribute);
  }

  @override
  ({String? msg, bool success}) validateRule(LocalBlockRule rule) {
    if (double.tryParse(rule.expression) == null) {
      return (success: false, msg: 'inputNumberHint'.tr);
    } else {
      return (success: true, msg: null);
    }
  }
}

abstract class LikeLocalBlockRuleHandler<ITEM> implements LocalBlockRuleHandler<ITEM>, AttributeGetter<String, ITEM> {
  @override
  int get order => 10;

  @override
  bool executeRule(ITEM item, LocalBlockRule rule) {
    List<String> attribute = getItemAttributes(item);
    return attribute.any((a) => a.contains(rule.expression));
  }

  @override
  bool matchRule(LocalBlockRule rule) {
    return rule.pattern == LocalBlockPatternEnum.like && matchRuleAttribute(rule.attribute);
  }

  @override
  ({String? msg, bool success}) validateRule(LocalBlockRule rule) {
    return (success: true, msg: null);
  }
}

abstract class RegexLocalBlockRuleHandler<ITEM> implements LocalBlockRuleHandler<ITEM>, AttributeGetter<String, ITEM> {
  @override
  int get order => 10;

  @override
  bool executeRule(ITEM item, LocalBlockRule rule) {
    List<String> attribute = getItemAttributes(item);
    return attribute.any((a) => RegExp(rule.expression).hasMatch(a));
  }

  @override
  bool matchRule(LocalBlockRule rule) {
    return rule.pattern == LocalBlockPatternEnum.regex && matchRuleAttribute(rule.attribute);
  }

  @override
  ({String? msg, bool success}) validateRule(LocalBlockRule rule) {
    try {
      RegExp(rule.expression);
      return (success: true, msg: null);
    } on FormatException catch (e) {
      Log.error('Invalid regex:${rule.expression}', e);
      return (success: false, msg: 'inputRegexHint'.tr);
    }
  }
}

class GalleryTagEqualLocalBlockRuleHandler extends EqualLocalBlockRuleHandler<Gallery> with GalleryTagAttributeGetter {}

class GalleryUploaderEqualLocalBlockRuleHandler extends EqualLocalBlockRuleHandler<Gallery> with GalleryUploaderAttributeGetter {}

class CommentUsernameEqualLocalBlockRuleHandler extends EqualLocalBlockRuleHandler<GalleryComment> with CommentUsernameAttributeGetter {}

class CommentUserIdEqualLocalBlockRuleHandler extends EqualLocalBlockRuleHandler<GalleryComment> with CommentUserIdAttributeGetter {}

class CommentScoreGreaterThanLocalBlockRuleHandler extends GreaterThanLocalBlockRuleHandler<GalleryComment> with CommentScoreAttributeGetter {}

class CommentScoreGreaterThanEqualLocalBlockRuleHandler extends GreaterThanEqualLocalBlockRuleHandler<GalleryComment> with CommentScoreAttributeGetter {}

class CommentScoreSmallerThanLocalBlockRuleHandler extends SmallerThanLocalBlockRuleHandler<GalleryComment> with CommentScoreAttributeGetter {}

class CommentScoreSmallerThanEqualLocalBlockRuleHandler extends SmallerThanEqualLocalBlockRuleHandler<GalleryComment> with CommentScoreAttributeGetter {}

class GalleryTitleLikeLocalBlockRuleHandler extends LikeLocalBlockRuleHandler<Gallery> with GalleryTitleAttributeGetter {}

class GalleryTagLikeLocalBlockRuleHandler extends LikeLocalBlockRuleHandler<Gallery> with GalleryTagAttributeGetter {}

class GalleryUploaderLikeLocalBlockRuleHandler extends LikeLocalBlockRuleHandler<Gallery> with GalleryUploaderAttributeGetter {}

class CommentUserNameLikeLocalBlockRuleHandler extends LikeLocalBlockRuleHandler<GalleryComment> with CommentUsernameAttributeGetter {}

class GalleryTitleRegexLocalBlockRuleHandler extends RegexLocalBlockRuleHandler<Gallery> with GalleryTitleAttributeGetter {}

class GalleryTagRegexLocalBlockRuleHandler extends RegexLocalBlockRuleHandler<Gallery> with GalleryTagAttributeGetter {}

class GalleryUploaderRegexLocalBlockRuleHandler extends RegexLocalBlockRuleHandler<Gallery> with GalleryUploaderAttributeGetter {}

class CommentUserNameRegexLocalBlockRuleHandler extends RegexLocalBlockRuleHandler<GalleryComment> with CommentUsernameAttributeGetter {}

enum LocalBlockTargetEnum {
  gallery(0, 'gallery', Gallery),
  comment(1, 'comment', GalleryComment),
  ;

  final int code;
  final String desc;
  final Type model;

  const LocalBlockTargetEnum(this.code, this.desc, this.model);

  static LocalBlockTargetEnum fromCode(int code) {
    return LocalBlockTargetEnum.values.where((e) => e.code == code).first;
  }
}

enum LocalBlockAttributeEnum {
  title(0, LocalBlockTargetEnum.gallery, 'title'),
  tag(10, LocalBlockTargetEnum.gallery, 'tag'),
  uploader(20, LocalBlockTargetEnum.gallery, 'uploader'),
  userName(100, LocalBlockTargetEnum.comment, 'userName'),
  userId(110, LocalBlockTargetEnum.comment, 'userId'),
  score(120, LocalBlockTargetEnum.comment, 'score'),
  ;

  final int code;
  final LocalBlockTargetEnum target;
  final String desc;

  const LocalBlockAttributeEnum(this.code, this.target, this.desc);

  static List<LocalBlockAttributeEnum> withTarget(LocalBlockTargetEnum? target) => LocalBlockAttributeEnum.values.where((e) => e.target == target).toList();

  static LocalBlockAttributeEnum fromCode(int code) {
    return LocalBlockAttributeEnum.values.where((e) => e.code == code).first;
  }
}

enum LocalBlockPatternEnum {
  equal(0, [LocalBlockAttributeEnum.tag, LocalBlockAttributeEnum.uploader, LocalBlockAttributeEnum.userName, LocalBlockAttributeEnum.userId], '='),
  gt(1, [LocalBlockAttributeEnum.score], '>'),
  gte(2, [LocalBlockAttributeEnum.score], '>='),
  st(3, [LocalBlockAttributeEnum.score], '<'),
  ste(4, [LocalBlockAttributeEnum.score], '<='),
  like(5, [LocalBlockAttributeEnum.title, LocalBlockAttributeEnum.tag, LocalBlockAttributeEnum.uploader, LocalBlockAttributeEnum.userName], 'like'),
  regex(6, [LocalBlockAttributeEnum.title, LocalBlockAttributeEnum.tag, LocalBlockAttributeEnum.uploader, LocalBlockAttributeEnum.userName], 'regex'),
  ;

  final int code;
  final List<LocalBlockAttributeEnum> attributes;
  final String desc;

  const LocalBlockPatternEnum(this.code, this.attributes, this.desc);

  static List<LocalBlockPatternEnum> withAttribute(LocalBlockAttributeEnum? attribute) =>
      LocalBlockPatternEnum.values.where((e) => e.attributes.contains(attribute)).toList();

  static LocalBlockPatternEnum fromCode(int code) {
    return LocalBlockPatternEnum.values.where((e) => e.code == code).first;
  }
}

class LocalBlockRule {
  int? id;

  LocalBlockTargetEnum target;

  LocalBlockAttributeEnum attribute;

  LocalBlockPatternEnum pattern;

  String expression;

  LocalBlockRule({
    this.id,
    required this.target,
    required this.attribute,
    required this.pattern,
    required this.expression,
  });

  @override
  String toString() {
    return 'LocalBlockRule{id: $id, target: $target, attribute: $attribute, pattern: $pattern, expression: $expression}';
  }

  bool match(Object item) => target.model == item.runtimeType;
}
