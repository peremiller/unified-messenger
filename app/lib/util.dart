import 'package:intl/intl.dart';

/// Human-friendly relative time from an ISO-8601 string.
String relativeTime(String iso) {
  if (iso.isEmpty) return '';
  DateTime? dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  dt = dt.toLocal();
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24 && now.day == dt.day) return DateFormat.jm().format(dt);
  if (diff.inDays < 1) return 'Yesterday';
  if (diff.inDays < 7) return DateFormat.E().format(dt); // Mon, Tue...
  return DateFormat.MMMd().format(dt); // Jun 15
}

/// Clock time for a message bubble.
String clockTime(String iso) {
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  return DateFormat.jm().format(dt.toLocal());
}
