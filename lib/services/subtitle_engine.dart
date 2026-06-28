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
  StreamSubscription<dynamic>? _vadSub;

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

    await _overlayChannel.invokeMethod('showOverlay');
    await audioStream.startCapture();

    _running = true;
    _status = '监听中...';

    final vad = _vad!;
    final stt = _stt!;
    final trans = _trans!;
    final lang = config.sourceLang == 'auto' ? 'en' : config.sourceLang;

    audioStream.audioStream.listen(
      (Uint8List chunk) => vad.feed(chunk.toList()),
      onError: (e) {
        _status = '错误: $e';
        notifyListeners();
      },
    );

    _vadSub = vad.sentenceStream.listen(_onSentence(stt, trans, lang));

    notifyListeners();
  }

  void Function(List<int>) _onSentence(WhisperSTTEngine stt, TranslateEngine trans, String lang) {
    return (sentence) async {
      try {
        _status = '识别中...';
        notifyListeners();

        final text = await stt.transcribe(sentence, lang);
        if (text.isEmpty) return;

        _originalText = text;
        notifyListeners();

        _status = '翻译中...';
        notifyListeners();

        final translated = await trans.translate(text, lang);
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
    };
  }

  Future<void> stop() async {
    if (!_running) return;

    await audioStream.stopCapture();
    await _overlayChannel.invokeMethod('hideOverlay');

    _vadSub?.cancel();
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
    _vadSub?.cancel();
    audioStream.dispose();
    super.dispose();
  }
}
