# 实时字幕翻译 (RealTimeSubtitle)

Android 实时字幕翻译应用。通过 MediaProjection 捕获系统内录音频，Whisper API 识别英文/日语语音，Google/LibreTranslate/自定义 API 翻译为中文，悬浮窗叠加显示。

## 功能

- 🎧 **系统内录** — 捕获设备播放的所有音频（视频、会议、游戏）
- 🗣 **语音识别** — 支持英文和日语，Whisper API 驱动
- 🌐 **翻译引擎** — 默认免费（Google 翻译 / LibreTranslate），可接自定义 API（OpenAI 兼容）
- 🫧 **悬浮窗字幕** — 半透明置顶窗口，原文+译文双行显示
- 🔔 **前台 Service** — 后台持续监听，通知栏控制
- ⚙️ **可配置** — API Key、Base URL、语言、引擎全部可设

## 下载

前往 [Releases](https://github.com/layqlala/realtime-subtitle/releases) 下载最新 APK。

## 系统要求

- Android 10+ (API 29)
- 需要授予「录屏」和「悬浮窗」权限

## 自行构建

```bash
git clone https://github.com/layqlala/realtime-subtitle.git
cd realtime-subtitle
flutter pub get
flutter build apk --release
```

## 使用

1. 安装 APK，打开应用
2. 在设置页填入 Whisper API Key（OpenAI 或兼容 endpoint）
3. 选择源语言（英文 / 日语 / 自动检测）
4. 点击「开始监听」
5. 授权录屏权限 → 悬浮窗出现
6. 播放任何音频，字幕实时显示

## 技术栈

- Flutter 3.38 + Dart
- Android MediaProjection + AudioPlaybackCapture
- Kotlin 原生 AudioCaptureService（前台 Service）
- Whisper API / Google Translate / LibreTranslate

## License

MIT
