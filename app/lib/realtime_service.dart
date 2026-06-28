import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_service.dart';

/// A live event pushed from the backend.
class LiveEvent {
  final String type; // new_message | conversations_changed | network_changed | help_alert
  final String? platform;
  final String? conversationId;
  final String? name; // peer name for help_alert

  LiveEvent(this.type, this.platform, this.conversationId, this.name);

  factory LiveEvent.fromJson(Map<String, dynamic> j) => LiveEvent(
        j['type'] as String? ?? '',
        j['platform'] as String?,
        j['conversation_id'] as String?,
        j['name'] as String?,
      );
}

/// Connects to the backend WebSocket and exposes a broadcast stream of events.
/// Auto-reconnects with backoff and reports connection state so the UI can show
/// a "live" indicator.
class RealtimeService {
  RealtimeService({required this.baseUrl});

  final String baseUrl;

  final _events = StreamController<LiveEvent>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _retry;
  bool _connected = false;
  bool _disposed = false;
  int _attempt = 0;

  Stream<LiveEvent> get events => _events.stream;
  Stream<bool> get connection => _connection.stream;
  bool get isConnected => _connected;

  String get _wsUrl {
    final u = baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final key = ApiService.apiKey;
    final query = key.isEmpty ? '' : '?key=${Uri.encodeQueryComponent(key)}';
    return '$u/api/ws$query';
  }

  void connect() {
    if (_disposed) return;
    _retry?.cancel();
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _channel = channel;
      _sub = channel.stream.listen(
        (data) {
          _setConnected(true);
          _attempt = 0;
          try {
            final json = jsonDecode(data as String) as Map<String, dynamic>;
            _events.add(LiveEvent.fromJson(json));
          } catch (_) {/* ignore malformed frame */}
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
      // ready() resolves once the socket opens
      channel.ready.then((_) => _setConnected(true)).catchError((_) {
        _scheduleReconnect();
      });
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _setConnected(bool value) {
    if (_connected != value) {
      _connected = value;
      if (!_disposed) _connection.add(value);
    }
  }

  void _scheduleReconnect() {
    _setConnected(false);
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    if (_disposed) return;
    _attempt = (_attempt + 1).clamp(1, 6);
    final delay = Duration(seconds: _attempt * 2); // 2,4,...12s backoff
    _retry?.cancel();
    _retry = Timer(delay, connect);
  }

  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _events.close();
    _connection.close();
  }
}
