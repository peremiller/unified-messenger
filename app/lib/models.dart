import 'package:flutter/material.dart';

/// Mirrors the backend's unified models.

class PlatformInfo {
  final String platform;
  final String label;
  final Color color;
  final String status; // connected | demo | needs_setup | unavailable
  final String detail;
  final bool canSend;

  PlatformInfo({
    required this.platform,
    required this.label,
    required this.color,
    required this.status,
    required this.detail,
    required this.canSend,
  });

  factory PlatformInfo.fromJson(Map<String, dynamic> j) => PlatformInfo(
        platform: j['platform'] as String,
        label: j['label'] as String,
        color: _hexColor(j['color'] as String),
        status: j['status'] as String,
        detail: (j['detail'] ?? '') as String,
        canSend: (j['can_send'] ?? false) as bool,
      );
}

class Conversation {
  final String id;
  final String platform;
  final String name;
  final bool isGroup;
  final String lastMessage;
  final String lastSender;
  final String timestamp;
  final int unreadCount;

  Conversation({
    required this.id,
    required this.platform,
    required this.name,
    required this.isGroup,
    required this.lastMessage,
    required this.lastSender,
    required this.timestamp,
    required this.unreadCount,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        platform: j['platform'] as String,
        name: j['name'] as String,
        isGroup: (j['is_group'] ?? false) as bool,
        lastMessage: (j['last_message'] ?? '') as String,
        lastSender: (j['last_sender'] ?? '') as String,
        timestamp: (j['timestamp'] ?? '') as String,
        unreadCount: (j['unread_count'] ?? 0) as int,
      );
}

class Message {
  final String id;
  final String platform;
  final String senderName;
  final String text;
  final String timestamp;
  final bool isFromMe;
  final List<String> attachments;

  Message({
    required this.id,
    required this.platform,
    required this.senderName,
    required this.text,
    required this.timestamp,
    required this.isFromMe,
    required this.attachments,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String,
        platform: j['platform'] as String,
        senderName: (j['sender_name'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        timestamp: (j['timestamp'] ?? '') as String,
        isFromMe: (j['is_from_me'] ?? false) as bool,
        attachments:
            ((j['attachments'] ?? []) as List).map((e) => e.toString()).toList(),
      );
}

class Peer {
  final String id;
  final String name;
  final String phone;
  final bool isSelf;
  final bool online;
  final int signalLevel; // 0-4 bars; -1 unknown
  final String connectionType; // cellular | wifi | none | unknown
  final String status; // safe | help | unknown
  final double? lat;
  final double? lng;
  final String lastSeen;
  final String mapsUrl;

  Peer({
    required this.id,
    required this.name,
    required this.phone,
    required this.isSelf,
    required this.online,
    required this.signalLevel,
    required this.connectionType,
    required this.status,
    required this.lat,
    required this.lng,
    required this.lastSeen,
    required this.mapsUrl,
  });

  bool get hasLocation => lat != null && lng != null;
  bool get needsHelp => status == 'help';
  bool get isSafe => status == 'safe';

  factory Peer.fromJson(Map<String, dynamic> j) => Peer(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: (j['phone'] ?? '') as String,
        isSelf: (j['is_self'] ?? false) as bool,
        online: (j['online'] ?? false) as bool,
        signalLevel: (j['signal_level'] ?? 0) as int,
        connectionType: (j['connection_type'] ?? 'unknown') as String,
        status: (j['status'] ?? 'unknown') as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        lastSeen: (j['last_seen'] ?? '') as String,
        mapsUrl: (j['maps_url'] ?? '') as String,
      );
}

Color _hexColor(String hex) {
  final cleaned = hex.replaceAll('#', '');
  return Color(int.parse('FF$cleaned', radix: 16));
}
