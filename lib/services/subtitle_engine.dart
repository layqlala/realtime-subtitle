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
  StreamSubscription? _audioSub;  // Fix #4: store audio subscription
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

  // Fix #6: serial queue for sentence processing
  final List<List<int>> _sentenceQueue = [];
  bool _processing = false;

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
    // Fix #7: use null for auto-detect instead of hardcoding 'en'
    _lang = config.sourceLang == 'auto' ? '' : config.sourceLang;

    await _overlayChannel.invokeMethod('showOverlay');
    await audioStream.startCapture();

    _running = true;
    _status = '监听中...';

    final vad = _vad!;

    // Fix #4: store subscription so we can cancel it
    _audioSub = audioStream.audioStream.listen(
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
    // Fix #6: enqueue and process serially
    _sentenceQueue.add(sentence);
    _processNextSentence();
  }

  Future<void> _processNextSentence() async {
    if (_processing || _sentenceQueue.isEmpty) return;
    _processing = true;

    final sentence = _sentenceQueue.removeAt(0);
    try {
      await _doProcessSentence(sentence);
    } catch (e) {
      final msg = e.toString();
      _status = '错误: ${msg.length > 50 ? msg.substring(0, 50) : msg}';
      notifyListeners();
    } finally {
      _processing = false;
      // Process next if any arrived while we were busy
      if (_sentenceQueue.isNotEmpty) {
        _processNextSentence();
      }
    }
  }

  Future<void> _doProcessSentence(List<int> sentence) async {
    final stt = _stt;
    final trans = _trans;
    if (stt == null || trans == null) return;

    _status = '识别中...';
    notifyListeners();

    final text = await stt.transcribe(sentence, _lang);
    if (text.isEmpty) return;

    _originalText = text;
    notifyListeners();

    _status = '翻译中...';
    notifyListeners();

    final translated = await trans.translate(text, _lang.isEmpty ? 'en' : _lang);
    _translatedText = translated;

    try {
      await _overlayChannel.invokeMethod('updateSubtitle', {
        'original': text,
        'translated': translated,
      });
    } catch (_) {
      // overlay may be gone if service stopped
    }

    _status = '监听中...';
    notifyListeners();
  }

  Future<void> stop() async {
    if (!_running) return;

    await audioStream.stopCapture();

    // Fix #4: cancel audio subscription
    await _audioSub?.cancel();
    _audioSub = null;

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

    _sentenceQueue.clear();
    _processing = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _vadSub?.cancel();
    audioStream.dispose();
    super.dispose();
  }
}
