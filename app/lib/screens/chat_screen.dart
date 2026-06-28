import 'dart:async';

import 'package:flutter/material.dart';

import '../api_service.dart';
import '../models.dart';
import '../platform_ui.dart';
import '../realtime_service.dart';
import '../util.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.api,
    required this.realtime,
    required this.conversation,
  });
  final ApiService api;
  final RealtimeService realtime;
  final Conversation conversation;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Future<List<Message>> _future;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  final List<Message> _optimistic = [];
  StreamSubscription? _eventSub;

  @override
  void initState() {
    super.initState();
    _future = widget.api
        .fetchMessages(widget.conversation.platform, widget.conversation.id);
    _eventSub = widget.realtime.events.listen(_onLiveEvent);
  }

  /// Refresh this thread when a new message lands in *this* conversation.
  void _onLiveEvent(LiveEvent e) {
    final c = widget.conversation;
    final matches = e.type == 'new_message' &&
        e.platform == c.platform &&
        (e.conversationId == null || e.conversationId == c.id);
    if (!matches || !mounted) return;
    setState(() {
      _optimistic.clear(); // server now has the real history
      _future = widget.api.fetchMessages(c.platform, c.id);
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final sent = await widget.api.sendMessage(
          widget.conversation.platform, widget.conversation.id, text);
      _controller.clear();
      setState(() => _optimistic.add(sent));
      _scrollToBottom();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.conversation;
    final color = platformColor(c.platform);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ConversationAvatar(conversation: c),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  Row(
                    children: [
                      Icon(platformIcon(c.platform), size: 12, color: color),
                      const SizedBox(width: 4),
                      Text(platformLabel(c.platform),
                          style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600)),
                      if (c.isGroup) ...[
                        const Text('  ·  group',
                            style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Message>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Could not load messages\n${snap.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                final msgs = [...(snap.data ?? []), ..._optimistic];
                if (msgs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) =>
                      _Bubble(message: msgs[i], accent: color),
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.accent});
  final Message message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final mine = message.isFromMe;
    final align = mine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = mine
        ? accent
        : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = mine ? Colors.white : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: align,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 2),
              child: Text(message.senderName,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: accent)),
            ),
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.76),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(mine ? 16 : 4),
                bottomRight: Radius.circular(mine ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text, style: TextStyle(color: textColor)),
                if (message.attachments.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(message.attachments.first,
                        style: TextStyle(
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                            color: textColor ?? accent)),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text(clockTime(message.timestamp),
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
              top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Message',
                  filled: true,
                  fillColor: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            sending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton.filled(
                    onPressed: onSend,
                    icon: const Icon(Icons.send_rounded),
                  ),
          ],
        ),
      ),
    );
  }
}
