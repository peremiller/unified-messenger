import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api_service.dart';
import '../contacts_service.dart';
import '../models.dart';
import '../realtime_service.dart';
import '../signal_service.dart';
import '../util.dart';

/// Stable identity for this device's self-report. A production app would use a
/// real per-device id; one constant is fine for a single user.
const String kSelfId = 'me-device';
const String kSelfName = 'Me';

const _kHelp = Color(0xFFEF4444);
const _kSafe = Color(0xFF22C55E);

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key, required this.api, required this.realtime});
  final ApiService api;
  final RealtimeService realtime;

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen> {
  final _signal = SignalService();
  final _contactsSvc = ContactsService();
  SignalStatus _status = SignalStatus.offline;
  String _myStatus = 'unknown'; // emergency check-in
  late Future<List<Peer>> _future;
  ContactsResult? _contacts;
  StreamSubscription? _signalSub;
  StreamSubscription? _eventSub;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.fetchNetwork();
    _initSignal();
    _loadContacts();
    _eventSub = widget.realtime.events.listen((e) {
      if (e.type == 'network_changed') _refresh();
    });
  }

  Future<void> _initSignal() async {
    _status = await _signal.current();
    if (mounted) setState(() {});
    _signalSub = _signal.watch().listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _shareStatus(silent: true); // appear online on open
  }

  Future<void> _loadContacts() async {
    final res = await _contactsSvc.load();
    if (mounted) setState(() => _contacts = res);
  }

  @override
  void dispose() {
    _signalSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() => _future = widget.api.fetchNetwork());
  }

  Future<void> _shareStatus({String? status, bool silent = false}) async {
    if (_sharing) return;
    if (status != null) setState(() => _myStatus = status);
    setState(() => _sharing = true);
    try {
      final loc = await tryGetLocation();
      await widget.api.reportPresence(
        id: kSelfId,
        name: kSelfName,
        signalLevel: _status.level,
        connectionType: _status.connectionType,
        status: _myStatus,
        lat: loc?.lat,
        lng: loc?.lng,
      );
      _refresh();
      if (!silent && mounted) {
        final msg = status == 'help'
            ? 'Sent “Need help” with your location'
            : status == 'safe'
                ? 'Marked yourself safe'
                : 'Shared your status';
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not share: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _openMaps(Peer p) async {
    final uri = Uri.parse(p.mapsUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not open Maps')));
      }
    }
  }

  /// peerId -> matched device-contact name, plus how many contacts are matched.
  ({Map<String, String> names, int matched, int total}) _match(List<Peer> peers) {
    final contacts = _contacts?.contacts ?? const <DeviceContact>[];
    final peerByPhone = {
      for (final p in peers)
        if (p.phone.isNotEmpty) normalizePhone(p.phone): p
    };
    final names = <String, String>{};
    var matched = 0;
    for (final c in contacts) {
      Peer? hit;
      for (final ph in c.phones) {
        hit = peerByPhone[normalizePhone(ph)];
        if (hit != null) break;
      }
      if (hit != null) {
        names[hit.id] = c.name;
        matched++;
      }
    }
    return (names: names, matched: matched, total: contacts.length);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Signal',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<List<Peer>>(
          future: _future,
          builder: (context, snap) {
            final peers = (snap.data ?? []).where((p) => !p.isSelf).toList();
            final online = peers.where((p) => p.online).length;
            final help = peers.where((p) => p.needsHelp).toList();
            final m = _match(peers);
            return ListView(
              children: [
                if (help.isNotEmpty) _HelpBanner(count: help.length),
                _MySignalCard(
                  status: _status,
                  myStatus: _myStatus,
                  sharing: _sharing,
                  onSafe: () => _shareStatus(status: 'safe'),
                  onHelp: () => _shareStatus(status: 'help'),
                ),
                _ContactsSummary(
                  matched: m.matched,
                  total: m.total,
                  fromDevice: _contacts?.fromDevice ?? true,
                  loading: _contacts == null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      const Text('Contacts in your network',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text('$online of ${peers.length} have signal',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (snap.hasError)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                        child: Text('Could not load network\n${snap.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey))),
                  )
                else
                  ...peers.map((p) => _PeerTile(
                        peer: p,
                        contactName: m.names[p.id],
                        onMaps: () => _openMaps(p),
                      )),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Text(
                    'Only contacts who also use this app and choose to share '
                    'appear here. Signal, location and status can never be '
                    'detected remotely without their consent.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HelpBanner extends StatelessWidget {
  const _HelpBanner({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kHelp.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kHelp.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _kHelp),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              count == 1
                  ? '1 contact needs help'
                  : '$count contacts need help',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: _kHelp, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _MySignalCard extends StatelessWidget {
  const _MySignalCard({
    required this.status,
    required this.myStatus,
    required this.sharing,
    required this.onSafe,
    required this.onHelp,
  });
  final SignalStatus status;
  final String myStatus;
  final bool sharing;
  final VoidCallback onSafe;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    final color = status.online ? _kSafe : Colors.grey;
    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 0,
      color: Theme.of(context)
          .colorScheme
          .surfaceContainerHighest
          .withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                SignalBars(level: status.level, color: color, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('My signal',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(status.label,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                if (myStatus != 'unknown') StatusBadge(status: myStatus),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: myStatus == 'safe'
                          ? _kSafe
                          : _kSafe.withValues(alpha: 0.15),
                      foregroundColor:
                          myStatus == 'safe' ? Colors.white : _kSafe,
                    ),
                    onPressed: sharing ? null : onSafe,
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text("I'm safe"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: myStatus == 'help'
                          ? _kHelp
                          : _kHelp.withValues(alpha: 0.15),
                      foregroundColor:
                          myStatus == 'help' ? Colors.white : _kHelp,
                    ),
                    onPressed: sharing ? null : onHelp,
                    icon: const Icon(Icons.sos_rounded, size: 18),
                    label: const Text('Need help'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactsSummary extends StatelessWidget {
  const _ContactsSummary({
    required this.matched,
    required this.total,
    required this.fromDevice,
    required this.loading,
  });
  final int matched;
  final int total;
  final bool fromDevice;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.contacts_rounded, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: loading
                  ? const Text('Matching your contacts…',
                      style: TextStyle(fontSize: 13))
                  : Text(
                      '$matched of $total phone contacts are on the network'
                      '${fromDevice ? '' : ' (sample contacts)'}',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  const _PeerTile(
      {required this.peer, required this.contactName, required this.onMaps});
  final Peer peer;
  final String? contactName;
  final VoidCallback onMaps;

  @override
  Widget build(BuildContext context) {
    final color = peer.online ? _kSafe : Colors.grey;
    final displayName = contactName ?? peer.name;
    return ListTile(
      leading: SignalBars(level: peer.signalLevel, color: color, size: 22),
      title: Row(
        children: [
          Flexible(
            child: Text(displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 6),
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          if (peer.status != 'unknown') ...[
            const SizedBox(width: 8),
            StatusBadge(status: peer.status),
          ],
        ],
      ),
      subtitle: Text(
        '${peer.online ? peer.connectionType : "offline"}'
        '${peer.lastSeen.isEmpty ? "" : " · seen ${relativeTime(peer.lastSeen)}"}'
        '${contactName != null && contactName != peer.name ? " · as ${peer.name}" : ""}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: peer.hasLocation
          ? IconButton(
              tooltip: 'Open location in Google Maps',
              icon: const Icon(Icons.place, color: Color(0xFFEA4335)),
              onPressed: onMaps,
            )
          : const Icon(Icons.location_off, color: Colors.grey, size: 20),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final help = status == 'help';
    final color = help ? _kHelp : _kSafe;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        help ? 'NEEDS HELP' : 'SAFE',
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }
}

/// Classic signal-bars glyph (4 ascending bars; dimmed above the active level).
class SignalBars extends StatelessWidget {
  const SignalBars(
      {super.key, required this.level, required this.color, this.size = 24});
  final int level; // 0-4
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (i) {
          final active = i < level;
          return Container(
            width: size * 0.18,
            height: size * (0.35 + i * 0.22),
            decoration: BoxDecoration(
              color: active ? color : color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
