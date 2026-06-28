// Throwaway entrypoint used only to screenshot individual screens in isolation
// during development. Run with:  flutter run -t lib/main_preview.dart
import 'package:flutter/material.dart';

import 'api_service.dart';
import 'realtime_service.dart';
import 'screens/heatmap_screen.dart';

void main() {
  final api = ApiService();
  final realtime = RealtimeService(baseUrl: api.baseUrl)..connect();
  const seed = Color(0xFF5B6CFF);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: seed, brightness: Brightness.dark),
    ),
    home: HeatmapScreen(api: api, realtime: realtime),
  ));
}
