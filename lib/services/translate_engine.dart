import 'dart:convert';
import 'package:http/http.dart' as http;

/// 翻译引擎统一接口
abstract class TranslateEngine {
  /// 翻译文本，target 固定为 "zh"
  Future<String> translate(String text, String sourceLang);
  Future<void> dispose();
}

/// LibreTranslate 免费翻译
class LibreTranslateEngine implements TranslateEngine {
  final String baseUrl;
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
          'source': sourceLang,
          'target': 'zh',
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translatedText'] ?? '';
      } else {
        throw Exception('LibreTranslate error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('LibreTranslate failed: $e');
    }
  }

  @override
  Future<void> dispose() async => _client.close();
}

/// Google Translate 免费接口
class GoogleTranslateEngine implements TranslateEngine {
  final http.Client _client = http.Client();

  @override
  Future<String> translate(String text, String sourceLang) async {
    try {
      final uri = Uri.parse(
        'https://translate.googleapis.com/translate_a/single'
        '?client=gtx&sl=$sourceLang&tl=zh&dt=t&q=${Uri.encodeComponent(text)}',
      );

      final response = await _client.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // 解析 [[["译文","原文",...]],...] 结构
        final parts = (data[0] as List)
            .where((e) => e is List && e.isNotEmpty)
            .map((e) => (e as List)[0].toString())
            .join('');
        return parts;
      } else {
        throw Exception('Google Translate error ${response.statusCode}');
      }
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
  final http.Client _client = http.Client();

  CustomAPITranslateEngine({
    required this.apiKey,
    this.baseUrl = 'https://api.openai.com/v1',
    this.model = 'gpt-3.5-turbo',
  });

  @override
  Future<String> translate(String text, String sourceLang) async {
    try {
      final langName = sourceLang == 'en' ? 'English' : 'Japanese';
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['choices'][0]['message']['content'] as String).trim();
      } else {
        throw Exception('API error ${response.statusCode}: ${response.body}');
      }
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
          model: model ?? 'gpt-3.5-turbo',
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
