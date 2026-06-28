import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models.dart';
import '../platform_ui.dart';

class PlatformsScreen extends StatefulWidget {
  const PlatformsScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<PlatformsScreen> createState() => _PlatformsScreenState();
}

class _PlatformsScreenState extends State<PlatformsScreen> {
  late Future<List<PlatformInfo>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchPlatforms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts & Platforms')),
      body: FutureBuilder<List<PlatformInfo>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final platforms = snap.data ?? [];
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const _Legend(),
              const SizedBox(height: 8),
              ...platforms.map((p) => _PlatformCard(info: p)),
            ],
          );
        },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest
          .withValues(alpha: 0.4),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'Connected platforms sync live messages. Demo platforms show sample '
          'data so you can explore the app. Add credentials in backend/.env to '
          'go live. Some platforms have no usable personal-inbox API.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  const _PlatformCard({required this.info});
  final PlatformInfo info;

  @override
  Widget build(BuildContext context) {
    final st = statusStyle(info.status);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: info.color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(platformIcon(info.platform),
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(info.label,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      _StatusPill(style: st),
                    ],
                  ),
                  if (info.detail.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(info.detail,
                          style: const TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: Colors.grey)),
                    ),
                  if (info.canSend)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          Icon(Icons.reply_rounded,
                              size: 14, color: Color(0xFF22C55E)),
                          SizedBox(width: 4),
                          Text('Can send replies',
                              style: TextStyle(
                                  fontSize: 12, color: Color(0xFF22C55E))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style});
  final StatusStyle style;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 4),
          Text(style.label,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: style.color)),
        ],
      ),
    );
  }
}
