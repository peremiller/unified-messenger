import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:unified_messenger/api_service.dart';
import 'package:unified_messenger/realtime_service.dart';
import 'package:unified_messenger/screens/inbox_screen.dart';

void main() {
  testWidgets('Inbox renders its header', (WidgetTester tester) async {
    final api = ApiService(baseUrl: 'http://localhost:0');
    // Not connected — avoids a live socket / pending reconnect timers in tests.
    final realtime = RealtimeService(baseUrl: 'http://localhost:0');
    addTearDown(realtime.dispose);

    await tester.pumpWidget(MaterialApp(
      home: InboxScreen(api: api, realtime: realtime),
    ));

    expect(find.text('All Messages'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });
}
