import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models.dart';
import '../platform_ui.dart';
import '../realtime_service.dart';
import '../util.dart';
import 'chat_screen.dart';
import 'platforms_screen.dart';

class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.api, required this.realtime});
  final ApiService api;
  final RealtimeService realtime;

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  late Future<List<Conversation>> _future;
  List<PlatformInfo> _platforms = [];
  String? _filter; // null = all platforms
  String _search = '';
  bool _live = false;
  StreamSubscription? _eventSub;
  StreamSubscription? _connSub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadPlatforms();
    _future = widget.api.fetchConversations();
    _live = widget.realtime.isConnected;
    _connSub = widget.realtime.connection.listen((v) {
      if (mounted) setState(() => _live = v);
    });
    _eventSub = widget.realtime.events.listen((_) => _onLiveEvent());
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _connSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  /// Any live event means the inbox may have changed — refresh (debounced so a
  /// burst of events triggers a single reload).
  void _onLiveEvent() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() =>
            _future = widget.api.fetchConversations(platform: _filter));
      }
    });
  }

  Future<void> _loadPlatforms() async {
    try {
      final p = await widget.api.fetchPlatforms();
      if (mounted) setState(() => _platforms = p);
    } catch (_) {/* surfaced via conversation load */}
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.api.fetchConversations(platform: _filter));
    await _future;
  }

  void _setFilter(String? platform) {
    setState(() {
      _filter = platform;
      _future = widget.api.fetchConversations(platform: platform);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('All Messages',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            _LiveDot(live: _live),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Accounts & platforms',
            icon: const Icon(Icons.dashboard_customize_rounded),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => PlatformsScreen(api: widget.api)),
              );
              _loadPlatforms();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _SearchField(onChanged: (v) => setState(() => _search = v)),
          _FilterBar(
            platforms: _platforms,
            selected: _filter,
            onSelect: _setFilter,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Conversation>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _ErrorView(
                        error: snap.error.toString(), onRetry: _refresh);
                  }
                  final all = snap.data ?? [];
                  final convs = _search.isEmpty
                      ? all
                      : all
                          .where((c) => c.name
                              .toLowerCase()
                              .contains(_search.toLowerCase()))
                          .toList();
                  if (convs.isEmpty) {
                    return const _EmptyView();
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: convs.length,
                    separatorBuilder: (_, _) => const Divider(
                        height: 1, indent: 78, endIndent: 12),
                    itemBuilder: (_, i) => _ConversationTile(
                      conversation: convs[i],
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                              api: widget.api,
                              realtime: widget.realtime,
                              conversation: convs[i]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.live});
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live ? const Color(0xFF22C55E) : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: live
                ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)]
                : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(live ? 'Live' : 'Offline',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search conversations',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: Theme.of(context).colorScheme.surfaceContainerHighest
              .withValues(alpha: 0.5),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.platforms,
    required this.selected,
    required this.onSelect,
  });
  final List<PlatformInfo> platforms;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip(context, label: 'All', platform: null, active: selected == null),
          ...platforms.map((p) => _chip(
                context,
                label: p.label,
                platform: p.platform,
                active: selected == p.platform,
              )),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context,
      {required String label, String? platform, required bool active}) {
    final color = platform == null
        ? Theme.of(context).colorScheme.primary
        : platformColor(platform);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: active,
        showCheckmark: false,
        avatar: platform == null
            ? null
            : Icon(platformIcon(platform),
                size: 16, color: active ? Colors.white : color),
        label: Text(label),
        labelStyle: TextStyle(
          color: active ? Colors.white : null,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        selectedColor: color,
        backgroundColor: color.withValues(alpha: 0.10),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
        onSelected: (_) => onSelect(platform),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});
  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final preview = c.lastSender.isNotEmpty && c.isGroup
        ? '${c.lastSender}: ${c.lastMessage}'
        : c.lastMessage;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: ConversationAvatar(conversation: c),
      title: Row(
        children: [
          Expanded(
            child: Text(c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(relativeTime(c.timestamp),
              style: TextStyle(
                  fontSize: 12,
                  color: c.unreadCount > 0
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(preview.isEmpty ? 'No messages yet' : preview,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (c.unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('${c.unreadCount}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Icon(Icons.inbox_rounded, size: 64, color: Colors.grey),
        SizedBox(height: 12),
        Center(child: Text('No conversations here yet')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 100),
        const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
        const SizedBox(height: 12),
        const Center(
          child: Text("Can't reach the backend",
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
        const SizedBox(height: 16),
        Center(
          child: FilledButton.tonal(
              onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
