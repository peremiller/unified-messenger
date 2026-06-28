import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../api_service.dart';
import '../models.dart';
import '../realtime_service.dart';

class HeatmapScreen extends StatefulWidget {
  const HeatmapScreen({super.key, required this.api, required this.realtime});
  final ApiService api;
  final RealtimeService realtime;

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  List<Peer> _peers = [];
  bool _loading = true;
  String _filter = 'all'; // all | help | safe
  StreamSubscription? _eventSub;

  List<Peer> get _filtered {
    switch (_filter) {
      case 'help':
        return _peers.where((p) => p.needsHelp).toList();
      case 'safe':
        return _peers.where((p) => p.isSafe).toList();
      default:
        return _peers;
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    _eventSub = widget.realtime.events.listen((e) {
      if (e.type == 'network_changed') _load();
    });
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final peers = await widget.api.fetchNetwork();
      if (mounted) {
        setState(() {
          _peers = peers.where((p) => p.hasLocation).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  LatLng get _center {
    if (_peers.isEmpty) return const LatLng(12.0, 122.0); // PH center
    final lat = _peers.map((p) => p.lat!).reduce((a, b) => a + b) / _peers.length;
    final lng = _peers.map((p) => p.lng!).reduce((a, b) => a + b) / _peers.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Heatmap',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: _peers.length <= 1 ? 11 : 5.6,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.unifiedmessenger.app',
                    ),
                    _HeatLayer(peers: _filtered),
                    MarkerLayer(
                      markers: [
                        for (final p in _filtered)
                          Marker(
                            point: LatLng(p.lat!, p.lng!),
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: (p.needsHelp
                                        ? const Color(0xFFEF4444)
                                        : p.online
                                            ? const Color(0xFF22C55E)
                                            : Colors.grey)
                                    .withValues(alpha: 0.95),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  top: 12,
                  child: _FilterBar(
                    filter: _filter,
                    counts: {
                      'all': _peers.length,
                      'help': _peers.where((p) => p.needsHelp).length,
                      'safe': _peers.where((p) => p.isSafe).length,
                    },
                    onSelect: (f) => setState(() => _filter = f),
                  ),
                ),
                const Positioned(left: 12, bottom: 12, child: _Legend()),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: _CountChip(count: _filtered.length),
                ),
              ],
            ),
    );
  }
}

/// Additive radial-gradient heat overlay. Each peer paints a soft hot blob;
/// overlapping blobs accumulate toward white-hot, so dense areas read hottest.
/// Online peers and stronger signals burn brighter.
class _HeatLayer extends StatelessWidget {
  const _HeatLayer({required this.peers});
  final List<Peer> peers;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final blobs = <_Blob>[];
    for (final p in peers) {
      final pt = camera.latLngToScreenPoint(LatLng(p.lat!, p.lng!));
      final weight = (p.online ? 0.55 : 0.2) + p.signalLevel * 0.08;
      blobs.add(_Blob(Offset(pt.x, pt.y), weight.clamp(0.15, 0.95)));
    }
    return IgnorePointer(
      child: CustomPaint(size: Size.infinite, painter: _HeatPainter(blobs)),
    );
  }
}

class _Blob {
  final Offset center;
  final double weight; // 0..1
  _Blob(this.center, this.weight);
}

class _HeatPainter extends CustomPainter {
  _HeatPainter(this.blobs);
  final List<_Blob> blobs;

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 60.0;
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final b in blobs) {
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFF3B00).withValues(alpha: b.weight),
            const Color(0xFFFF9500).withValues(alpha: b.weight * 0.5),
            const Color(0x00FF9500),
          ],
          stops: const [0.0, 0.4, 1.0],
        ).createShader(Rect.fromCircle(center: b.center, radius: radius));
      canvas.drawCircle(b.center, radius, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeatPainter old) =>
      old.blobs.length != blobs.length ||
      !_sameCenters(old.blobs, blobs);

  bool _sameCenters(List<_Blob> a, List<_Blob> b) {
    for (var i = 0; i < a.length; i++) {
      if ((a[i].center - b[i].center).distanceSquared > 0.5) return false;
    }
    return true;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar(
      {required this.filter, required this.counts, required this.onSelect});
  final String filter;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('all', 'All', Color(0xFF5B6CFF)),
      ('help', 'Needs help', Color(0xFFEF4444)),
      ('safe', 'Safe', Color(0xFF22C55E)),
    ];
    return Row(
      children: [
        for (final (key, label, color) in items)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelect(key),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: filter == key
                      ? color
                      : Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color, width: 1.2),
                ),
                child: Text(
                  '$label (${counts[key] ?? 0})',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight:
                        filter == key ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 8,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              gradient: LinearGradient(colors: [
                Color(0xFF1E3A8A),
                Color(0xFFFF9500),
                Color(0xFFFF3B00),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          const Text('low → high density',
              style: TextStyle(color: Colors.white, fontSize: 11)),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$count located',
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}