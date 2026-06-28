import 'dart:convert';
import 'package:http/http.dart' as http;

/// 翻译引擎统一接口
abstract class TranslateEngine {
  Future<String> translate(String text, String sourceLang);
  Future<void> dispose();
}

/// LibreTranslate 免费翻译
class LibreTranslateEngine implements TranslateEngine {
  final String baseUrl;
  static const _timeout = Duration(seconds: 15);
  final http.Client _client = http.Client();

  LibreTranslateEngine({this.baseUrl = 'https://libretranslate.com'});

  @override
  Future<String> translate(String text, String sourceLang) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'source': sourceLang.isEmpty ? 'auto' : sourceLang,
          'target': 'zh',
          'format': 'text',
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translatedText'] ?? '';
      } else {
        throw Exception('LibreTranslate error ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('LibreTranslate timeout');
    } catch (e) {
      throw Exception('LibreTranslate failed: $e');
    }
  }

  @override
  Future<void> dispose() async => _client.close();
}

/// Google Translate 免费接口
class GoogleTranslateEngine implements TranslateEngine {
  static const _timeout = Duration(seconds: 15);
  final http.Client _client = http.Client();

  @override
  Future<String> translate(String text, String sourceLang) async {
    try {
      // Fix: map empty/auto to 'auto' for Google
      final sl = sourceLang.isEmpty ? 'auto' : sourceLang;
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx&sl=$sl&tl=zh&dt=t&q=${Uri.encodeComponent(text)}',
      );

      final response = await _client.get(uri).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final parts = (data[0] as List)
            .where((e) => e is List && e.isNotEmpty)
            .map((e) => (e as List)[0].toString())
            .join('');
        return parts;
      } else {
        throw Exception('Google Translate error ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Google Translate timeout');
    } catch (e) {
      throw Exception('Google Translate failed: $e');
    }
  }

  @override
  Future<void> dispose() async => _client.close();
}

/// 自定义 API 翻译（OpenAI-compatible）
class CustomAPITranslateEngine implements TranslateEngine {
  final String apiKey;
  final String baseUrl;
  final String model;
  static const _timeout = Duration(seconds: 30);
  final http.Client _client = http.Client();

  CustomAPITranslateEngine({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-3.5-turbo',
  });

  @override
  Future<String> translate(String text, String sourceLang) async {
    try {
      final langName = switch (sourceLang) {
        'ja' => 'Japanese',
        'en' => 'English',
        _ => 'English or Japanese',
      };
      final response = await _client.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are a translator. Translate the following $langName text to Simplified Chinese. Output only the translation, no explanations.',
            },
            {'role': 'user', 'content': text},
          ],
          'temperature': 0.3,
          'max_tokens': 500,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String).trim();
      } else {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }
    } on TimeoutException {
      throw Exception('Custom API timeout');
    } catch (e) {
      throw Exception('Custom API failed: $e');
    }
  }

  @override
  Future<void> dispose() async => _client.close();
}

/// 多级翻译引擎：按优先级尝试，失败自动降级
class FallbackTranslateEngine implements TranslateEngine {
  final List<TranslateEngine> engines;

  FallbackTranslateEngine(this.engines);

  @override
  Future<String> translate(String text, String sourceLang) async {
    for (final engine in engines) {
      try {
        return await engine.translate(text, sourceLang);
      } catch (_) {
        // 降级到下一个引擎
      }
    }
    throw Exception('All translation engines failed');
  }

  @override
  Future<void> dispose() async {
    for (final e in engines) {
      await e.dispose();
    }
  }
}

/// 构建翻译引擎链
TranslateEngine buildTranslateEngine({
  String primaryType = 'google',
  String? apiKey,
  String? baseUrl,
  String? model,
}) {
  final engines = <TranslateEngine>[];

  switch (primaryType) {
    case 'libre':
      engines.add(LibreTranslateEngine());
      engines.add(GoogleTranslateEngine());
      break;
    case 'custom':
      if (apiKey != null && apiKey.isNotEmpty) {
        engines.add(CustomAPITranslateEngine(
          apiKey: apiKey,
          baseUrl: baseUrl ?? 'https://api.openai.com/v1',
          model: (model != null && model.isNotEmpty) ? model : 'gpt-3.5-turbo',
        ));
      }
      engines.add(GoogleTranslateEngine());
      break;
    case 'google':
    default:
      engines.add(GoogleTranslateEngine());
      engines.add(LibreTranslateEngine());
      break;
  }

  return FallbackTranslateEngine(engines);
}
