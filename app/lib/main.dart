import 'package:flutter/material.dart';

import 'api_service.dart';
import 'push/push_service.dart';
import 'realtime_service.dart';
import 'screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const UnifiedMessengerApp());
}

class UnifiedMessengerApp extends StatefulWidget {
  const UnifiedMessengerApp({super.key});

  @override
  State<UnifiedMessengerApp> createState() => _UnifiedMessengerAppState();
}

class _UnifiedMessengerAppState extends State<UnifiedMessengerApp> {
  late final ApiService api;
  late final RealtimeService realtime;

  @override
  void initState() {
    super.initState();
    api = ApiService();
    realtime = RealtimeService(baseUrl: api.baseUrl)..connect();
    // Register for closed-app push (no-op on web / until Firebase configured).
    createPushService(api).init();
  }

  @override
  void dispose() {
    realtime.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF5B6CFF);
    return MaterialApp(
      title: 'Unified Messenger',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor: seed, brightness: Brightness.dark),
      ),
      home: HomeShell(api: api, realtime: realtime),
    );
  }
}
