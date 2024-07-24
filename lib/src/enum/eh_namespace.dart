enum EHNamespace {
  rows('rows', null, '分类'),
  language('language', 'l', '语言'),
  artist('artist', 'a', '作者'),
  character('character', 'c', '角色'),
  female('female', 'f', '女性'),
  male('male', 'm', '男性'),
  parody('parody', 'p', '原作'),
  group('group', 'g', '团队'),
  mixed('mixed', 'x', '混合'),
  cosplayer('cosplayer', 'cos', '角色扮演者'),
  reclass('reclass', 'r', '重新分类'),
  temp('temp', null, '临时'),
  other('other', 'o', '其他'),
  ;

  const EHNamespace(this.desc, this.abbr, this.chineseDesc);

  final String desc;

  final String? abbr;

  final String? chineseDesc;

  static EHNamespace? findNameSpaceFromDescOrAbbr(String? desc) {
    for (final EHNamespace ns in values) {
      if (ns.desc == desc || ns.abbr == desc) {
        return ns;
      }
    }
    return null;
  }
}
