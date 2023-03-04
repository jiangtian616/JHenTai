import 'package:get/get.dart';
import 'package:jhentai/src/l18n/en_US.dart';
import 'package:jhentai/src/l18n/zh_CN.dart';
import 'package:jhentai/src/l18n/zh_TW.dart';
import 'package:jhentai/src/l18n/pt_BR.dart';
import 'package:jhentai/src/l18n/ko_KR.dart';

class LocaleText extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en_US': en_US.keys(),
        'zh_CN': zh_CN.keys(),
        'zh_TW': zh_TW.keys(),
        'pt_BR': pt_BR.keys(),
        'ko_KR': ko_KR.keys(),
      };
}
