import 'dart:io';

import 'package:extended_image/extended_image.dart';

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
  final _textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
  String _extractedText = '';

  String? _path;

  late FlutterTts flutterTts;
  String? language = 'zh_CN';
  String? engine;
  double volume = 0.5;
  double pitch = 1.0;
  double rate = 0.7;
  bool isCurrentLanguageInstalled = false;

  TtsState ttsState = TtsState.stopped;

  bool get isPlaying => ttsState == TtsState.playing;
  bool get isStopped => ttsState == TtsState.stopped;
  bool get isPaused => ttsState == TtsState.paused;
  bool get isContinued => ttsState == TtsState.continued;

  // 获取可选的语言
  Future<dynamic> _getLanguages() async => await flutterTts.getLanguages;

  // 获取所有引擎，Android
  Future<dynamic> _getEngines() async => await flutterTts.getEngines;

  @override
  Future<void> doInitBean() async {
    flutterTts = FlutterTts();

    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);
    await flutterTts.setLanguage(language!);

    if (Platform.isAndroid) {
      var engine = await flutterTts.getDefaultEngine;
      if (engine != null) {
        print(engine);
      }
      // 安卓特有的用于测试的默认声音
      var voice = await flutterTts.getDefaultVoice;
      if (voice != null) {
        print(voice);
      }

      // 检测语言是否支持
      flutterTts
          .isLanguageInstalled(language!)
          .then((value) => isCurrentLanguageInstalled = (value as bool));

      //设置引擎
      await flutterTts.setEngine(engine);
    }

    flutterTts.setStartHandler(() {
      print("Playing");
      ttsState = TtsState.playing;
    });

    flutterTts.setCompletionHandler(() {
      print("Complete");
      ttsState = TtsState.stopped;
    });

    flutterTts.setCancelHandler(() {
      print("Cancel");
      ttsState = TtsState.stopped;
    });

    flutterTts.setPauseHandler(() {
      print("Paused");
      ttsState = TtsState.paused;
    });

    flutterTts.setContinueHandler(() {
      print("Continued");
      ttsState = TtsState.continued;
    });

    flutterTts.setErrorHandler((msg) {
      print("error: $msg");
      ttsState = TtsState.stopped;
    });
  }

  @override
  Future<void> doAfterBeanReady() async {}

  Future<void> _recognizedText() async {
    try {
      final inputImage = InputImage.fromFilePath(_path!);
      final RecognizedText text =
          await _textRecognizer.processImage(inputImage);
      _extractedText = '';
      for (var element in text.blocks) {
        _extractedText += element.text.replaceAll(RegExp(r'\s'), '') + "。\n";
        print(_extractedText);
        print('-----------------');
      }
    } catch (e) {}
  }

  Future<void> _speak() async {
    if (_extractedText.isNotEmpty) {
      await stop();
      await flutterTts.clearVoice();
      await flutterTts.speak(_extractedText);
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
    var result = await flutterTts.stop();
    if (result == 1) {
      ttsState = TtsState.stopped;
    }
  }

  Future<void> pause() async {
    var result = await flutterTts.pause();
    if (result == 1) {
      ttsState = TtsState.paused;
    }
  }
}
