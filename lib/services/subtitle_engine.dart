import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/audio_stream.dart';
import '../services/vad.dart';
import '../services/stt_engine.dart';
import '../services/translate_engine.dart';
import '../utils/config.dart';

class SubtitleEngine extends ChangeNotifier {
  final AppConfig config;
  final AudioStreamService audioStream = AudioStreamService();
  static const _overlayChannel = MethodChannel('com.example.realtimesubtitle/overlay');

  VADProcessor? _vad;
  WhisperSTTEngine? _stt;
  TranslateEngine? _trans;
  StreamSubscription? _vadSub;
  String _lang = 'en';

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

    _stt = WhisperSTTEngine(
      apiKey: config.sttApiKey,
      baseUrl: config.sttBaseUrl.isNotEmpty ? config.sttBaseUrl : 'https://api.openai.com/v1',
    );

    _trans = buildTranslateEngine(
      primaryType: config.transEngine,
      apiKey: config.transApiKey.isNotEmpty ? config.transApiKey : null,
      baseUrl: config.transBaseUrl.isNotEmpty ? config.transBaseUrl : null,
      model: config.transModel,
    );

    _vad = VADProcessor();
    _lang = config.sourceLang == 'auto' ? 'en' : config.sourceLang;

    await _overlayChannel.invokeMethod('showOverlay');
    await audioStream.startCapture();

    _running = true;
    _status = '监听中...';

    final vad = _vad!;

    audioStream.audioStream.listen(
      (Uint8List chunk) => vad.feed(chunk.toList()),
      onError: (e) {
        _status = '错误: $e';
        notifyListeners();
      },
    );

    _vadSub = vad.sentenceStream.listen(_onSentence);

    notifyListeners();
  }

  void _onSentence(List<int> sentence) {
    _processSentence(sentence);
  }

  Future<void> _processSentence(List<int> sentence) async {
    final stt = _stt;
    final trans = _trans;
    if (stt == null || trans == null) return;

    try {
      _status = '识别中...';
      notifyListeners();

      final text = await stt.transcribe(sentence, _lang);
      if (text.isEmpty) return;

      _originalText = text;
      notifyListeners();

      _status = '翻译中...';
      notifyListeners();

      final translated = await trans.translate(text, _lang);
      _translatedText = translated;

      await _overlayChannel.invokeMethod('updateSubtitle', {
        'original': text,
        'translated': translated,
      });

      _status = '监听中...';
      notifyListeners();
    } catch (e) {
      final msg = e.toString();
      _status = '错误: ${msg.length > 50 ? msg.substring(0, 50) : msg}';
      notifyListeners();
    }
  }

  Future<void> stop() async {
    if (!_running) return;

    await audioStream.stopCapture();
    await _overlayChannel.invokeMethod('hideOverlay');

    _vadSub?.cancel();
    _vad?.dispose();
    if (_stt != null) await _stt!.dispose();
    if (_trans != null) await _trans!.dispose();

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
    _vadSub?.cancel();
    audioStream.dispose();
    super.dispose();
  }
}
