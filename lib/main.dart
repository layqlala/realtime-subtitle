import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'utils/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  runApp(RealTimeSubtitleApp(config: config));
}

class RealTimeSubtitleApp extends StatelessWidget {
  final AppConfig config;
  const RealTimeSubtitleApp({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '实时字幕',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: HomeScreen(config: config),
    );
  }
}
