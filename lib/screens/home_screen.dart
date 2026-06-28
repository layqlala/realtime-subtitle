import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/subtitle_engine.dart';
import '../theme/anime_theme.dart';
import '../utils/config.dart';

class HomeScreen extends StatefulWidget {
  final AppConfig config;
  const HomeScreen({super.key, required this.config});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late SubtitleEngine _engine;

  final _sttApiKeyCtrl = TextEditingController();
  final _sttBaseUrlCtrl = TextEditingController();
  final _transApiKeyCtrl = TextEditingController();
  final _transBaseUrlCtrl = TextEditingController();
  final _transModelCtrl = TextEditingController();

  String _sourceLang = 'auto';
  String _transEngine = 'google';
  bool _resumingFromSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = SubtitleEngine(config: widget.config);
    _engine.addListener(_onEngineChanged);
    _sourceLang = widget.config.sourceLang;
    _transEngine = widget.config.transEngine;
    _sttApiKeyCtrl.text = widget.config.sttApiKey;
    _sttBaseUrlCtrl.text = widget.config.sttBaseUrl;
    _transApiKeyCtrl.text = widget.config.transApiKey;
    _transBaseUrlCtrl.text = widget.config.transBaseUrl;
    _transModelCtrl.text = widget.config.transModel;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_resumingFromSettings) return;
    if (state == AppLifecycleState.resumed) {
      _resumingFromSettings = false;
      _startWithPermissions();
    }
  }

  void _onEngineChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _saveConfig() async {
    widget.config.sourceLang = _sourceLang;
    widget.config.transEngine = _transEngine;
    widget.config.sttApiKey = _sttApiKeyCtrl.text.trim();
    widget.config.sttBaseUrl = _sttBaseUrlCtrl.text.trim();
    widget.config.transApiKey = _transApiKeyCtrl.text.trim();
    widget.config.transBaseUrl = _transBaseUrlCtrl.text.trim();
    widget.config.transModel = _transModelCtrl.text.trim();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('设置已保存'), duration: Duration(seconds: 1)),
      );
    }
  }

  Future<bool> _ensureOverlayPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.systemAlertWindow.status;
    if (status.isGranted) return true;

    if (!mounted) return false;

    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (ctx) => _AnimeDialog(
        title: '需要悬浮窗权限',
        content: '实时字幕需要悬浮窗权限才能在其他应用上方显示翻译字幕。\n\n请在接下来的系统设置页面中允许该权限。',
        confirmLabel: '去开启',
        cancelLabel: '取消',
      ),
    );

    if (shouldOpen != true) return false;

    await Permission.systemAlertWindow.request();
    final granted = await Permission.systemAlertWindow.status;
    return granted.isGranted;
  }

  Future<void> _startWithPermissions() async {
    if (!mounted) return;
    final overlayOk = await _ensureOverlayPermission();
    if (!overlayOk) return;

    // 请求通知权限
    if (Platform.isAndroid) {
      await Permission.notification.request();
    }

    await _saveConfig();
    await _engine.start();
  }

  // ── UI 构建 ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AnimeTheme.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildStatusCard(),
              const SizedBox(height: 16),
              _buildControlButton(),
              const SizedBox(height: 16),
              _buildSubtitlePreview(),
              const SizedBox(height: 20),
              _buildSettingsPanel(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ── 头部 ──
  Widget _buildHeader() {
    return Row(
      children: [
        // 装饰圆
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AnimeTheme.sakura, AnimeTheme.sky],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: AnimeTheme.softShadow,
          ),
          child: const Icon(Icons.mic_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('实时字幕', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AnimeTheme.charcoal)),
              SizedBox(height: 2),
              Text('监听系统声音 · 自动翻译字幕', style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  // ── 状态卡片 ──
  Widget _buildStatusCard() {
    final running = _engine.isRunning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AnimeTheme.radiusM),
        boxShadow: AnimeTheme.softShadow,
      ),
      child: Row(
        children: [
          // 状态指示灯
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: running ? AnimeTheme.success : Colors.grey[300],
              boxShadow: running
                  ? [BoxShadow(color: AnimeTheme.success.withOpacity(0.5), blurRadius: 8)]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  running ? '监听中' : '就绪',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: running ? AnimeTheme.charcoal : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _engine.status,
                  style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 小装饰
          if (running)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AnimeTheme.success.withOpacity(0.15),
                borderRadius: BorderRadius.circular(AnimeTheme.radiusS),
              ),
              child: const Text('活跃', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AnimeTheme.success)),
            ),
        ],
      ),
    );
  }

  // ── 控制按钮 ──
  Widget _buildControlButton() {
    final running = _engine.isRunning;
    return GestureDetector(
      onTap: running ? () => _engine.stop() : _startWithPermissions,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: running
                ? [AnimeTheme.danger, AnimeTheme.danger.withOpacity(0.8)]
                : [AnimeTheme.sakura, AnimeTheme.sky],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(AnimeTheme.radiusM),
          boxShadow: [
            BoxShadow(
              color: (running ? AnimeTheme.danger : AnimeTheme.sakura).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(running ? Icons.stop_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              running ? '停止监听' : '开始监听',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ── 字幕预览气泡 ──
  Widget _buildSubtitlePreview() {
    final original = _engine.originalText;
    final translated = _engine.translatedText;
    if (original.isEmpty && translated.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AnimeTheme.charcoal,
        borderRadius: BorderRadius.circular(AnimeTheme.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (original.isNotEmpty) ...[
            Text(original, style: const TextStyle(fontSize: 14, color: Colors.white70)),
            const SizedBox(height: 8),
          ],
          if (translated.isNotEmpty)
            Text(
              translated,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AnimeTheme.subtitle),
            ),
        ],
      ),
    );
  }

  // ── 设置面板 ──
  Widget _buildSettingsPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AnimeTheme.radiusM),
        boxShadow: AnimeTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('设置', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AnimeTheme.charcoal)),
          const SizedBox(height: 14),

          // 源语言
          const Text('源语言', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 6),
          _buildLangSelector(),
          const SizedBox(height: 14),

          // 翻译引擎
          const Text('翻译引擎', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 6),
          _buildEngineSelector(),
          const SizedBox(height: 14),

          // STT API Key
          _buildTextField('STT API Key', _sttApiKeyCtrl, obscure: true),
          const SizedBox(height: 10),
          _buildTextField('STT Base URL', _sttBaseUrlCtrl),
          const SizedBox(height: 14),

          // 翻译 API Key (仅 custom)
          if (_transEngine == 'custom') ...[
            _buildTextField('翻译 API Key', _transApiKeyCtrl, obscure: true),
            const SizedBox(height: 10),
            _buildTextField('翻译 Base URL', _transBaseUrlCtrl),
            const SizedBox(height: 10),
            _buildTextField('翻译 Model', _transModelCtrl),
            const SizedBox(height: 10),
          ],

          // 保存按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _saveConfig,
              child: const Text('保存设置'),
            ),
          ),
        ],
      ),
    );
  }

  // ── 语言选择器 ──
  Widget _buildLangSelector() {
    return Row(
      children: [
        _buildLangChip('自动', 'auto'),
        const SizedBox(width: 8),
        _buildLangChip('英语', 'en'),
        const SizedBox(width: 8),
        _buildLangChip('日语', 'ja'),
      ],
    );
  }

  Widget _buildLangChip(String label, String value) {
    final selected = _sourceLang == value;
    return GestureDetector(
      onTap: () => setState(() => _sourceLang = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AnimeTheme.sakura : AnimeTheme.creamDark,
          borderRadius: BorderRadius.circular(AnimeTheme.radiusS),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AnimeTheme.charcoal,
          ),
        ),
      ),
    );
  }

  // ── 引擎选择器 ──
  Widget _buildEngineSelector() {
    return Row(
      children: [
        _buildEngineChip('Google', 'google'),
        const SizedBox(width: 8),
        _buildEngineChip('Libre', 'libre'),
        const SizedBox(width: 8),
        _buildEngineChip('自定义', 'custom'),
      ],
    );
  }

  Widget _buildEngineChip(String label, String value) {
    final selected = _transEngine == value;
    return GestureDetector(
      onTap: () => setState(() => _transEngine = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AnimeTheme.sky : AnimeTheme.creamDark,
          borderRadius: BorderRadius.circular(AnimeTheme.radiusS),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AnimeTheme.charcoal,
          ),
        ),
      ),
    );
  }

  // ── 输入框 ──
  Widget _buildTextField(String label, TextEditingController ctrl, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: label,
            filled: true,
            fillColor: AnimeTheme.creamDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AnimeTheme.radiusS),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AnimeTheme.radiusS),
              borderSide: const BorderSide(color: AnimeTheme.sakura, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.dispose();
    _sttApiKeyCtrl.dispose();
    _sttBaseUrlCtrl.dispose();
    _transApiKeyCtrl.dispose();
    _transBaseUrlCtrl.dispose();
    _transModelCtrl.dispose();
    super.dispose();
  }
}

// ── 二次元风格弹窗 ──
class _AnimeDialog extends StatelessWidget {
  final String title;
  final String content;
  final String confirmLabel;
  final String cancelLabel;

  const _AnimeDialog({
    required this.title,
    required this.content,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AnimeTheme.radiusL)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 装饰图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AnimeTheme.sakura, AnimeTheme.sky],
                ),
              ),
              child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AnimeTheme.charcoal)),
            const SizedBox(height: 10),
            Text(content, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
