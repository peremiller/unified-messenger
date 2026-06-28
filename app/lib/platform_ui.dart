import 'package:flutter/material.dart';

import 'models.dart';

/// Per-platform visual helpers (icon, colour, initials) and status styling.

const Map<String, Color> kPlatformColors = {
  'telegram': Color(0xFF2AABEE),
  'discord': Color(0xFF5865F2),
  'slack': Color(0xFF4A154B),
  'substack': Color(0xFFFF6719),
  'skool': Color(0xFFF2C94C),
  'sms': Color(0xFF34C759),
  'whatsapp': Color(0xFF25D366),
  'messenger': Color(0xFF0084FF),
  'viber': Color(0xFF7360F2),
  'linkedin': Color(0xFF0A66C2),
};

const Map<String, String> kPlatformLabels = {
  'telegram': 'Telegram',
  'discord': 'Discord',
  'slack': 'Slack',
  'substack': 'Substack',
  'skool': 'Skool',
  'sms': 'SMS',
  'whatsapp': 'WhatsApp',
  'messenger': 'Messenger',
  'viber': 'Viber',
  'linkedin': 'LinkedIn',
};

/// A representative Material icon for each platform (no brand-logo assets needed).
IconData platformIcon(String platform) {
  switch (platform) {
    case 'telegram':
      return Icons.send_rounded;
    case 'discord':
      return Icons.sports_esports_rounded;
    case 'slack':
      return Icons.tag_rounded;
    case 'substack':
      return Icons.mark_email_unread_rounded;
    case 'skool':
      return Icons.school_rounded;
    case 'sms':
      return Icons.sms_rounded;
    case 'whatsapp':
      return Icons.chat_rounded;
    case 'messenger':
      return Icons.messenger_rounded;
    case 'viber':
      return Icons.phone_in_talk_rounded;
    case 'linkedin':
      return Icons.work_rounded;
    default:
      return Icons.forum_rounded;
  }
}

Color platformColor(String platform) =>
    kPlatformColors[platform] ?? const Color(0xFF7A7A7A);

String platformLabel(String platform) =>
    kPlatformLabels[platform] ?? platform;

String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

class StatusStyle {
  final String label;
  final Color color;
  final IconData icon;
  const StatusStyle(this.label, this.color, this.icon);
}

StatusStyle statusStyle(String status) {
  switch (status) {
    case 'connected':
      return const StatusStyle('Connected', Color(0xFF22C55E), Icons.check_circle);
    case 'demo':
      return const StatusStyle('Demo data', Color(0xFF3B82F6), Icons.science);
    case 'needs_setup':
      return const StatusStyle(
          'Needs setup', Color(0xFFF59E0B), Icons.settings_suggest);
    case 'unavailable':
      return const StatusStyle('Unavailable', Color(0xFF9CA3AF), Icons.block);
    default:
      return const StatusStyle('Unknown', Color(0xFF9CA3AF), Icons.help);
  }
}

/// A small rounded platform badge (icon on brand colour).
class PlatformBadge extends StatelessWidget {
  const PlatformBadge({super.key, required this.platform, this.size = 18});
  final String platform;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: platformColor(platform),
        shape: BoxShape.circle,
      ),
      child: Icon(platformIcon(platform), size: size * 0.62, color: Colors.white),
    );
  }
}

/// Avatar showing conversation initials over the platform colour, with a small
/// platform badge tucked into the corner.
class ConversationAvatar extends StatelessWidget {
  const ConversationAvatar({super.key, required this.conversation});
  final Conversation conversation;

  @override
  Widget build(BuildContext context) {
    final color = platformColor(conversation.platform);
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.85), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: conversation.isGroup
                ? const Icon(Icons.groups_rounded, color: Colors.white, size: 24)
                : Text(
                    initialsFor(conversation.name),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 17),
                  ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              child: PlatformBadge(platform: conversation.platform, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
