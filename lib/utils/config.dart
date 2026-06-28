import 'package:shared_preferences/shared_preferences.dart';

/// 应用配置，持久化在 SharedPreferences
class AppConfig {
  static const _keySourceLang = 'source_lang';
  static const _keySttApiKey = 'stt_api_key';
  static const _keySttBaseUrl = 'stt_base_url';
  static const _keyTransEngine = 'trans_engine';
  static const _keyTransApiKey = 'trans_api_key';
  static const _keyTransBaseUrl = 'trans_base_url';
  static const _keyTransModel = 'trans_model';

  final SharedPreferences _prefs;

  AppConfig._(this._prefs);

  static Future<AppConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppConfig._(prefs);
  }

  String get sourceLang => _prefs.getString(_keySourceLang) ?? 'auto';
  set sourceLang(String v) => _prefs.setString(_keySourceLang, v);

  String get sttApiKey => _prefs.getString(_keySttApiKey) ?? '';
  set sttApiKey(String v) => _prefs.setString(_keySttApiKey, v);

  String get sttBaseUrl => _prefs.getString(_keySttBaseUrl) ?? '';
  set sttBaseUrl(String v) => _prefs.setString(_keySttBaseUrl, v);

  String get transEngine => _prefs.getString(_keyTransEngine) ?? 'google';
  set transEngine(String v) => _prefs.setString(_keyTransEngine, v);

  String get transApiKey => _prefs.getString(_keyTransApiKey) ?? '';
  set transApiKey(String v) => _prefs.setString(_keyTransApiKey, v);

  String get transBaseUrl => _prefs.getString(_keyTransBaseUrl) ?? '';
  set transBaseUrl(String v) => _prefs.setString(_keyTransBaseUrl, v);

  String get transModel => _prefs.getString(_keyTransModel) ?? 'gpt-3.5-turbo';
  set transModel(String v) => _prefs.setString(_keyTransModel, v);
}
