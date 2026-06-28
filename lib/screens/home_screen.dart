import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/subtitle_engine.dart';
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
      builder: (ctx) => AlertDialog(
        title: const Text('需要悬浮窗权限'),
        content: const Text('实时字幕需要悬浮窗权限才能在其他应用上方显示翻译字幕。\n\n请在接下来的系统设置页面中允许该权限。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去开启')),
        ],
      ),
    );

    if (shouldOpen != true) return false;

    await Permission.systemAlertWindow.request();
    final granted = await Permission.systemAlertWindow.status;

    if (!granted.isGranted && mounted) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('权限未开启'),
          content: const Text('悬浮窗权限尚未开启，实时字幕无法显示。\n\n是否手动前往系统设置页面开启该权限？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('暂不')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('去设置')),
          ],
        ),
      );

      if (openSettings == true) {
        await openAppSettings();
        _resumingFromSettings = true;
      }

      return false;
    }

    return granted.isGranted;
  }

  Future<bool> _ensureNotificationPermission() async {
    if (!Platform.isAndroid) return true;

    final status = await Permission.notification.status;
    if (status.isGranted) return true;

    final requested = await Permission.notification.request();
    return requested.isGranted;
  }

  Future<void> _startWithPermissions() async {
    final overlayReady = await _ensureOverlayPermission();
    if (!overlayReady) return;

    final notificationReady = await _ensureNotificationPermission();
    if (!notificationReady) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('通知权限未授予，Android 13+ 无法稳定运行前台服务')),
      );
    }

    await _engine.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('实时字幕翻译'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildControlButton(),
          const SizedBox(height: 24),
          _buildSection('源语言'),
          _buildLanguageSelector(),
          const SizedBox(height: 16),
          _buildSection('语音识别 (STT)'),
          _buildSTTSettings(),
          const SizedBox(height: 16),
          _buildSection('翻译引擎'),
          _buildTransSettings(),
          const SizedBox(height: 24),
          _buildSaveButton(),
          const SizedBox(height: 16),
          if (_engine.originalText.isNotEmpty) ...[
            _buildSection('当前字幕'),
            _buildSubtitlePreview(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    Color statusColor;
    if (_engine.status.contains('错误')) {
      statusColor = Colors.red;
    } else if (_engine.isRunning) {
      statusColor = Colors.green;
    } else {
      statusColor = Colors.grey;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _engine.status,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _engine.isRunning
            ? _engine.stop
            : () async {
                await _saveConfig();
                await _startWithPermissions();
              },
        icon: Icon(_engine.isRunning ? Icons.stop : Icons.play_arrow, size: 28),
        label: Text(
          _engine.isRunning ? '停止监听' : '开始监听',
          style: const TextStyle(fontSize: 18),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _engine.isRunning ? Colors.red : Colors.blue,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildLanguageSelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'auto', label: Text('自动检测')),
        ButtonSegment(value: 'en', label: Text('英文')),
        ButtonSegment(value: 'ja', label: Text('日语')),
      ],
      selected: {_sourceLang},
      onSelectionChanged: (v) => setState(() => _sourceLang = v.first),
    );
  }

  Widget _buildSTTSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('引擎: Whisper API', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            TextField(
              controller: _sttApiKeyCtrl,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _sttBaseUrlCtrl,
              decoration: const InputDecoration(
                labelText: '自定义 Base URL (可选)',
                hintText: 'https://api.openai.com/v1',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: _transEngine,
              decoration: const InputDecoration(
                labelText: '引擎',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'google', child: Text('Google 翻译 (免费)')),
                DropdownMenuItem(value: 'libre', child: Text('LibreTranslate (免费)')),
                DropdownMenuItem(value: 'custom', child: Text('自定义 API')),
              ],
              onChanged: (v) => setState(() => _transEngine = v!),
            ),
            const SizedBox(height: 8),
            Text('目标语言：简体中文', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            if (_transEngine == 'custom') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _transApiKeyCtrl,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _transBaseUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.openai.com/v1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _transModelCtrl,
                decoration: const InputDecoration(
                  labelText: '模型',
                  hintText: 'gpt-3.5-turbo',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return OutlinedButton.icon(
      onPressed: _saveConfig,
      icon: const Icon(Icons.save),
      label: const Text('保存设置'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }

  Widget _buildSubtitlePreview() {
    return Card(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_engine.originalText, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 8),
            Text(_engine.translatedText, style: const TextStyle(color: Colors.yellow, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _engine.removeListener(_onEngineChanged);
    _sttApiKeyCtrl.dispose();
    _sttBaseUrlCtrl.dispose();
    _transApiKeyCtrl.dispose();
    _transBaseUrlCtrl.dispose();
    _transModelCtrl.dispose();
    _engine.dispose();
    super.dispose();
  }
}
