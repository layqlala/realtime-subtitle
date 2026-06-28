import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_stream.dart';
import '../services/vad.dart';
import '../services/stt_engine.dart';
import '../services/translate_engine.dart';
import '../utils/config.dart';

/// 字幕引擎：串联音频→VAD→STT→翻译→悬浮窗
class SubtitleEngine extends ChangeNotifier {
  final AppConfig config;
  final AudioStreamService audioStream = AudioStreamService();
  static const _overlayChannel = MethodChannel('com.example.realtimesubtitle/overlay');

  VADProcessor? _vad;
  WhisperSTTEngine? _stt;
  TranslateEngine? _trans;

  bool _running = false;
  bool get isRunning => _running;

  String _originalText = '';
  String _translatedText = '';
  String get originalText => _originalText;
  String get translatedText => _translatedText;

  String _status = '就绪';
  String get status => _status;

  SubtitleEngine({required this.config});

  Future<void> start() async {
    if (_running) return;

    _status = '初始化引擎...';
    notifyListeners();

    // 初始化 STT 引擎
    _stt = WhisperSTTEngine(
      apiKey: config.sttApiKey,
      baseUrl: config.sttBaseUrl.isNotEmpty ? config.sttBaseUrl : 'https://api.openai.com/v1',
    );

    // 初始化翻译引擎
    _trans = buildTranslateEngine(
      primaryType: config.transEngine,
      apiKey: config.transApiKey.isNotEmpty ? config.transApiKey : null,
      baseUrl: config.transBaseUrl.isNotEmpty ? config.transBaseUrl : null,
      model: config.transModel,
    );

    // 初始化 VAD
    _vad = VADProcessor();

    // 显示悬浮窗
    await _overlayChannel.invokeMethod('showOverlay');

    // 开始捕获
    await audioStream.startCapture();

    _running = true;
    _status = '监听中...';

    // 监听音频流 → VAD → STT → 翻译
    audioStream.audioStream.listen(
      (Uint8List chunk) {
        _vad?.feed(chunk.toList());
      },
      onError: (e) {
        _status = '错误: $e';
        notifyListeners();
      },
    );

    final lang = config.sourceLang == 'auto' ? 'en' : config.sourceLang; // ponytail: auto→en, STT内部处理检测

    // VAD 输出完整句子 → STT → 翻译
    _vad!.sentenceStream.listen((sentence) async {
      try {
        _status = '识别中...';
        notifyListeners();

        final text = await _stt!.transcribe(sentence, lang);

        if (text.isNotEmpty) {
          _originalText = text;
          notifyListeners();

          _status = '翻译中...';
          notifyListeners();

          final translated = await _trans!.translate(text, lang);
          _translatedText = translated;

          _overlayChannel.invokeMethod('updateSubtitle', {
            'original': text,
            'translated': translated,
          });

          _status = '监听中...';
          notifyListeners();
        }
      } catch (e) {
        _status = '错误: ${e.toString().substring(0, min(e.toString().length, 50))}';
        notifyListeners();
      }
    });

    notifyListeners();
  }

  Future<void> stop() async {
    if (!_running) return;

    await audioStream.stopCapture();
    await _overlayChannel.invokeMethod('hideOverlay');

    await _vad?.dispose();
    await _stt?.dispose();
    await _trans?.dispose();

    _vad = null;
    _stt = null;
    _trans = null;
    _running = false;
    _status = '已停止';
    _originalText = '';
    _translatedText = '';

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    audioStream.dispose();
    super.dispose();
  }
}
