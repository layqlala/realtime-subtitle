import 'dart:async';
import 'dart:math';

/// 简易能量阈值 VAD（语音活动检测）
/// 通过 RMS 能量判断是否为有效语音段，静音时自动切句
class VADProcessor {
  final double silenceThreshold;
  final int silenceFrames;
  final int minSpeechFrames;

  int _silentCount = 0;
  int _speechCount = 0;
  final List<int> _buffer = [];
  bool _inSpeech = false;
  bool _disposed = false;

  final StreamController<List<int>> _sentenceController =
      StreamController<List<int>>.broadcast();
  Stream<List<int>> get sentenceStream => _sentenceController.stream;

  VADProcessor({
    this.silenceThreshold = 300.0,
    this.silenceFrames = 15,
    this.minSpeechFrames = 10,
  });

  /// 输入 PCM 16-bit 音频数据
  void feed(List<int> pcmBytes) {
    if (_disposed) return; // Fix #2: guard against post-dispose feed

    final rms = _calculateRMS(pcmBytes);

    if (rms > silenceThreshold) {
      _silentCount = 0;
      _speechCount++;
      _buffer.addAll(pcmBytes);
      _inSpeech = true;
    } else {
      if (_inSpeech) {
        _silentCount++;
        _buffer.addAll(pcmBytes);

        if (_silentCount >= silenceFrames && _speechCount >= minSpeechFrames) {
          final sentence = List<int>.from(_buffer);
          _sentenceController.add(sentence);
          _buffer.clear();
          _speechCount = 0;
          _inSpeech = false;
        }
      }
    }
  }

  double _calculateRMS(List<int> samples) {
    if (samples.isEmpty) return 0;
    var sum = 0.0;
    for (var i = 0; i < samples.length - 1; i += 2) {
      final sample = (samples[i + 1] << 8) | (samples[i] & 0xFF);
      final value = (sample > 32767) ? sample - 65536 : sample;
      sum += value * value;
    }
    return sqrt(sum / (samples.length / 2));
  }

  void dispose() {
    _disposed = true;
    _sentenceController.close();
  }
}
