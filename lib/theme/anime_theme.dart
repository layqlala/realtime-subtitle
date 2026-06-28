import 'package:flutter/material.dart';

/// 二次元简约风配色
/// 主色：柔粉  辅色：天蓝  背景：奶白  文字：深灰
class AnimeTheme {
  AnimeTheme._();

  // ── 配色 ──
  static const sakura = Color(0xFFFFB7C5);       // 樱花粉
  static const sakuraDark = Color(0xFFE8889E);   // 深樱粉
  static const sky = Color(0xFF87CEEB);           // 天蓝
  static const skyDark = Color(0xFF5BA3C9);       // 深天蓝
  static const lavender = Color(0xFFC3B1E1);      // 薰衣草紫
  static const cream = Color(0xFFFFF8F0);         // 奶白
  static const creamDark = Color(0xFFF5EDE3);     // 深奶白
  static const charcoal = Color(0xFF2D2D3A);      // 深灰文字
  static const subtitle = Color(0xFFFFF3B0);      // 字幕黄
  static const danger = Color(0xFFFF6B6B);        // 危险红
  static const success = Color(0xFF7EC8A0);       // 成功绿

  // ── 圆角 ──
  static const radiusL = 20.0;
  static const radiusM = 14.0;
  static const radiusS = 10.0;

  // ── 阴影 ──
  static List<BoxShadow> get softShadow => [
    BoxShadow(color: sakura.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4)),
  ];

  // ── ThemeData ──
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorSchemeSeed: sakura,
      scaffoldBackgroundColor: cream,
      fontFamily: 'NotoSansSC',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: charcoal,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: charcoal),
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: sakura,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sakuraDark,
          side: const BorderSide(color: sakura),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: creamDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusS),
          borderSide: const BorderSide(color: sakura, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: TextStyle(color: Colors.grey[400]),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS)),
          ),
          textStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: charcoal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusS)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
