import 'dart:io';

import 'package:extended_image/extended_image.dart';
import 'package:get/get_rx/src/rx_workers/rx_workers.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/service/log.dart';

import 'jh_service.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

MlttsService mlTtsService = MlttsService();

enum TtsState { playing, stopped, paused, continued }

class MlttsService with JHLifeCircleBeanErrorCatch implements JHLifeCircleBean {
  // latin: 拉丁文, chinese：汉文, devanagiri：梵文, japanese：日文, korean：韩文,
  /* 1. 拉丁文（使用拉丁字母的语言）：
ca-ES（加泰罗尼亚语）
nl-NL（荷兰语）
fr-CA（法语）
en-AU（英语）
id-ID（印尼语）
da-DK（丹麦语）
sk-SK（斯洛伐克语）
sv-SE（瑞典语）
tr-TR（土耳其语）
pt-BR（葡萄牙语）
es-MX（西班牙语）
en-US（英语）
hu-HU（匈牙利语）
fr-FR（法语）
pt-PT（葡萄牙语）
hr-HR（克罗地亚语）
en-GB（英语）
nl-BE（荷兰语）
pl-PL（波兰语）
vi-VN（越南语）
de-DE（德语）
fi-FI（芬兰语）
es-ES（西班牙语）
ms-MY（马来语）
en-IE（英语）
sl-SI（斯洛文尼亚语）
en-IN（英语）
it-IT（意大利语）
ro-RO（罗马尼亚语）
nb-NO（挪威博克马尔语）
en-ZA（英语）
cs-CZ（捷克语）
2. 汉文（使用汉字的语言）：
zh-CN（中文）
zh-HK（中文）
zh-TW（中文）
3. 梵文（使用天城文的语言）：
hi-IN（印地语）
4. 日文（使用日文汉字和假名的语言）：
ja-JP（日语）

5. 韩文（使用谚文的语言）：
ko-KR（韩语）
其他代码：
列表中的其他代码（如 ar-001、uk-UA、th-TH、he-IL、el-GR、ru-RU、bg-BG 等）使用阿拉伯字母、西里尔字母、泰文字母、希伯来字母、希腊字母等文字系统，不属于您提到的五种语种范围。
  */
  late TextRecognizer _textRecognizer;
  String _extractedText = '';

  String? _path;
  late FlutterTts _flutterTts;
  bool isCurrentLanguageInstalled = false;
  TtsState ttsState = TtsState.stopped;
  List<String> languages = [];
  List<String> engines = [];
  List<String> _exclusionList = [];
  int _blockDelay = 3;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  late Worker mlTtsScriptLister;
  late Worker mlTtsEngineLister;
  late Worker mlTtsLanguageLister;
  late Worker mlTtsPitchLister;
  late Worker mlTtsRateLister;
  late Worker mlTtsVolumeLister;
  late Worker mlTtsExclusionListLister;
  late Worker mlTtsBlockDelayLister;

  Future<void> _initConfig(_) async {
    await _flutterTts.setVolume(readSetting.mlTtsVolume.value);
    await _flutterTts.setSpeechRate(readSetting.mlTtsRate.value);
    await _flutterTts.setPitch(readSetting.mlTtsPitch.value);
    await _flutterTts.setLanguage(readSetting.mlTtsLanguage.value!);
    await _setEngine();
    _setExclusionList();
    _blockDelay = readSetting.mlTtsMinWordLimit.value;

    _flutterTts.setStartHandler(() {
      log.debug('setStartHandler:Playing');
      ttsState = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      log.debug('setCompletionHandler:Complete');
      ttsState = TtsState.stopped;
    });

    _flutterTts.setCancelHandler(() {
      log.debug('setCancelHandler:Cancel');
      ttsState = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      log.debug('setPauseHandler:Paused');
      ttsState = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      log.debug('setContinueHandler:Continued');
      ttsState = TtsState.continued;
    });

    _flutterTts.setErrorHandler((msg) {
      log.debug('setErrorHandler:error: $msg');
      ttsState = TtsState.stopped;
    });
  }

  Future<void> _setEngine() async {
    if (Platform.isAndroid) {
      engines = [];
      var engs = await _flutterTts.getEngines;
      for (var element in engs) {
        engines.add(element);
      }

      var engine =
          readSetting.mlTtsEngine.value ?? await _flutterTts.getDefaultEngine;
      if (engine != null) {
        log.debug('_setEngine:error: $engine');
      }
      var voice = await _flutterTts.getDefaultVoice;
      if (voice != null) {
        log.debug('_setEngine:error: $voice');
      }

      _flutterTts
          .isLanguageInstalled(readSetting.mlTtsLanguage.value!)
          .then((value) => isCurrentLanguageInstalled = (value as bool));

      await _flutterTts.setEngine(engine);
    }
  }

  void _setExclusionList() {
    _exclusionList = readSetting.mlTtsExclusionList.value?.split(',') ?? [];
    _exclusionList = _exclusionList.map((e) => e.trim()).toList();
    _exclusionList = _exclusionList.where((e) => e != '').toList();
  }

  void dispose() {
    mlTtsScriptLister.dispose();
    mlTtsEngineLister.dispose();
    mlTtsLanguageLister.dispose();
    mlTtsPitchLister.dispose();
    mlTtsRateLister.dispose();
    mlTtsVolumeLister.dispose();
    mlTtsExclusionListLister.dispose();
    mlTtsBlockDelayLister.dispose();
  }

  void _addListers() {
    mlTtsScriptLister = ever(readSetting.mlTtsScript, (_) {
      _textRecognizer = TextRecognizer(script: readSetting.mlTtsScript.value);
    });
    mlTtsEngineLister = ever(readSetting.mlTtsEngine, (_) {
      _setEngine();
    });
    mlTtsLanguageLister = ever(readSetting.mlTtsLanguage, (_) {
      _flutterTts.setLanguage(readSetting.mlTtsLanguage.value!);
    });
    mlTtsPitchLister = ever(readSetting.mlTtsPitch, (_) {
      _flutterTts.setPitch(readSetting.mlTtsPitch.value);
    });
    mlTtsRateLister = ever(readSetting.mlTtsRate, (_) {
      _flutterTts.setSpeechRate(readSetting.mlTtsRate.value);
    });
    mlTtsVolumeLister = ever(readSetting.mlTtsVolume, (_) {
      _flutterTts.setVolume(readSetting.mlTtsVolume.value);
    });
    mlTtsExclusionListLister = ever(readSetting.mlTtsExclusionList, (_) {
      _setExclusionList();
    });
    mlTtsBlockDelayLister = ever(readSetting.mlTtsMinWordLimit, (_) {
      _blockDelay = readSetting.mlTtsMinWordLimit.value;
    });
  }

  @override
  Future<void> doInitBean() async {
    _flutterTts = FlutterTts();
    _textRecognizer = TextRecognizer(script: readSetting.mlTtsScript.value);

    await _initConfig('');
  }

  @override
  Future<void> doAfterBeanReady() async {
    _addListers();
    var langs = await _flutterTts.getLanguages;
    for (var element in langs) {
      languages.add(element);
    }
    log.debug('doAfterBeanReady:error: $languages');
  }

  Future<void> _recognizedText() async {
    try {
      final inputImage = InputImage.fromFilePath(_path!);
      final RecognizedText text =
          await _textRecognizer.processImage(inputImage);
      _extractedText = '';
      for (var block in text.blocks) {
        var t = block.text.replaceAll(RegExp(r'\s'), '');
        for (var val in _exclusionList) {
          if (t.contains(val)) {
            continue;
          }
        }
        if (t.length < readSetting.mlTtsMinWordLimit.value) {
          continue;
        }
        _extractedText += t;
        log.debug('_setEngine:error: $_extractedText');
      }
    } catch (e) {}
  }

  Future<void> _speak() async {
    if (_extractedText.isNotEmpty) {
      await stop();
      await _flutterTts.clearVoice();
      await _flutterTts.speak(_extractedText);
    }
  }

  Future<void> playFromPath(path) async {
    if (path == null || _path == path) {
      return;
    }

    _path = path;
    await _recognizedText();
    _speak();
  }

  Future<void> playFromUrl(String? url) async {
    if (url == null) {
      return;
    }

    _path = await getCachedImageFilePath(url);
    await _recognizedText();
    _speak();
  }

  Future<void> stop() async {
    var result = await _flutterTts.stop();
    if (result == 1) {
      ttsState = TtsState.stopped;
    }
  }

  Future<void> pause() async {
    var result = await _flutterTts.pause();
    if (result == 1) {
      ttsState = TtsState.paused;
    }
  }
}
