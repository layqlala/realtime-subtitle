import 'dart:convert';
import 'package:http/http.dart' as http;

/// OpenAI Whisper API STT 引擎（兼容 OpenAI-compatible endpoint）
class WhisperSTTEngine {
  final String apiKey;
  final String baseUrl;

  final http.Client _client = http.Client();

  WhisperSTTEngine({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
  });

  /// 输入音频字节（16kHz 16bit mono PCM），返回识别文本
  Future<String> transcribe(List<int> audioBytes, String language) async {
    try {
      final uri = Uri.parse('$baseUrl/audio/transcriptions');

      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $apiKey'
        ..fields['model'] = 'whisper-1'
        ..fields['language'] = language
        ..fields['response_format'] = 'text'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            audioBytes,
            filename: 'audio.wav',
          ),
        );

      final response = await _client.send(request);
      final body = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return body.trim();
      } else {
        throw Exception('Whisper API error ${response.statusCode}: $body');
      }
    } catch (e) {
      throw Exception('STT failed: $e');
    }
  }

  Future<void> dispose() async => _client.close();
}
