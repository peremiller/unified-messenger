import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../notifications/notification_service.dart';
import '../realtime_service.dart';
import 'heatmap_screen.dart';
import 'inbox_screen.dart';
import 'network_screen.dart';

/// Top-level navigation: Chats · Network · Map. An IndexedStack keeps each
/// tab's state (and live subscriptions) alive while switching.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api, required this.realtime});
  final ApiService api;
  final RealtimeService realtime;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _notifications = createNotificationService();
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _notifications.init();
    _eventSub = widget.realtime.events.listen(_onEvent);
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  /// A contact flagged "need help" anywhere in the network → OS notification +
  /// an in-app banner with a shortcut to the Network tab.
  void _onEvent(LiveEvent e) {
    if (e.type != 'help_alert' || !mounted) return;
    final display = (e.name == null || e.name!.isEmpty) ? 'A contact' : e.name!;
    _notifications.showHelp(display);
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      backgroundColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 6),
      content: Text('🆘 $display needs help',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      action: SnackBarAction(
        label: 'View',
        textColor: Colors.white,
        onPressed: () => setState(() => _index = 1),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      InboxScreen(api: widget.api, realtime: widget.realtime),
      NetworkScreen(api: widget.api, realtime: widget.realtime),
      HeatmapScreen(api: widget.api, realtime: widget.realtime),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum),
              label: 'Chats'),
          NavigationDestination(
              icon: Icon(Icons.signal_cellular_alt_outlined),
              selectedIcon: Icon(Icons.signal_cellular_alt),
              label: 'Network'),
          NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map),
              label: 'Map'),
        ],
      ),
    );
  }
}
