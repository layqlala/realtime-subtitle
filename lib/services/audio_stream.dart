import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';

/// 接收 Android 原生层传来的 PCM 音频数据流
class AudioStreamService {
  static const _channel = MethodChannel('com.example.realtimesubtitle/audio');
  static const _eventChannel = EventChannel('com.example.realtimesubtitle/audio/stream');

  Stream<Uint8List>? _audioStream;
  StreamSubscription? _subscription;

  /// 开始捕获系统音频，返回 PCM 16kHz 16bit mono 数据流
  Stream<Uint8List> get audioStream {
    _audioStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((data) => data is Uint8List ? data : Uint8List.fromList(data));
    return _audioStream!;
  }

  Future<void> startCapture() async {
    await _channel.invokeMethod('startCapture');
  }

  Future<void> stopCapture() async {
    await _channel.invokeMethod('stopCapture');
  }

  Future<void> requestOverlayPermission() async {
    await _channel.invokeMethod('requestOverlayPermission');
  }

  void dispose() {
    _subscription?.cancel();
  }
}
