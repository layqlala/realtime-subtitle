import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// 接收 Android 原生层传来的 PCM 音频数据流
class AudioStreamService {
  static const _channel = MethodChannel('com.example.realtimesubtitle/audio');
  static const _eventChannel = EventChannel('com.example.realtimesubtitle/audio/stream');

  Stream<Uint8List>? _audioStream;

  Stream<Uint8List> get audioStream {
    _audioStream ??= _eventChannel.receiveBroadcastStream().cast<Uint8List>();
    return _audioStream!;
  }

  Future<void> startCapture() async {
    await _channel.invokeMethod('startCapture');
  }

  Future<void> stopCapture() async {
    await _channel.invokeMethod('stopCapture');
  }

  void dispose() {
    _audioStream = null;
  }
}
