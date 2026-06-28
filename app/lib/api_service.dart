import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'models.dart';

/// Talks to the Unified Messenger backend.
///
/// Base URL resolution:
///  - Override at build/run time:  --dart-define=API_BASE=http://192.168.1.x:8000
///  - Android emulator reaches the host machine via 10.0.2.2
///  - Everything else (web, iOS sim, desktop) uses localhost
class ApiService {
  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBase();

  final String baseUrl;

  /// Optional shared secret, supplied with `--dart-define=API_KEY=YOUR_KEY`.
  /// Must match the backend's API_KEY when the backend has one set.
  static const String apiKey = String.fromEnvironment('API_KEY');

  Map<String, String> get _authHeaders =>
      apiKey.isEmpty ? const {} : {'X-API-Key': apiKey};

  static String _defaultBase() {
    const override = String.fromEnvironment('API_BASE');
    if (override.isNotEmpty) return override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }

  Future<List<PlatformInfo>> fetchPlatforms() async {
    final data = await _getList('/api/platforms');
    return data.map((e) => PlatformInfo.fromJson(e)).toList();
  }

  Future<List<Conversation>> fetchConversations({String? platform}) async {
    final path = platform == null
        ? '/api/conversations'
        : '/api/conversations?platform=$platform';
    final data = await _getList(path);
    return data.map((e) => Conversation.fromJson(e)).toList();
  }

  Future<List<Message>> fetchMessages(String platform, String conversationId) async {
    final data = await _getList(
        '/api/conversations/$platform/$conversationId/messages');
    return data.map((e) => Message.fromJson(e)).toList();
  }

  Future<Message> sendMessage(
      String platform, String conversationId, String text) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/conversations/$platform/$conversationId/send'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({'text': text}),
    );
    if (resp.statusCode >= 400) {
      throw ApiException(_errorMessage(resp));
    }
    return Message.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<List<Peer>> fetchNetwork() async {
    final data = await _getList('/api/network');
    return data.map((e) => Peer.fromJson(e)).toList();
  }

  Future<Peer> reportPresence({
    required String id,
    required String name,
    String phone = '',
    required int signalLevel,
    required String connectionType,
    String status = 'unknown',
    double? lat,
    double? lng,
  }) async {
    final resp = await http.post(
      Uri.parse('$baseUrl/api/presence'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({
        'id': id,
        'name': name,
        'phone': phone,
        'signal_level': signalLevel,
        'connection_type': connectionType,
        'status': status,
        'lat': lat,
        'lng': lng,
      }),
    );
    if (resp.statusCode >= 400) {
      throw ApiException(_errorMessage(resp));
    }
    return Peer.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> registerFcmToken(
      {required String token, String platform = ''}) async {
    await http.post(
      Uri.parse('$baseUrl/api/fcm/register'),
      headers: {'Content-Type': 'application/json', ..._authHeaders},
      body: jsonEncode({'token': token, 'platform': platform}),
    );
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    final resp = await http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders);
    if (resp.statusCode >= 400) {
      throw ApiException(_errorMessage(resp));
    }
    final decoded = jsonDecode(resp.body);
    return (decoded as List).cast<Map<String, dynamic>>();
  }

  String _errorMessage(http.Response resp) {
    try {
      final body = jsonDecode(resp.body);
      if (body is Map && body['detail'] != null) return body['detail'].toString();
    } catch (_) {}
    return 'Request failed (${resp.statusCode})';
  }
}

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}
