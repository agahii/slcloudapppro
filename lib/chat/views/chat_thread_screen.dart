import 'package:flutter/material.dart';
import '../../chat/chat_controller.dart';
import '../widgets/input_bar.dart';
import '../widgets/message_bubble.dart';

class ChatThreadScreen extends StatefulWidget {
  final String peerId;
  final String displayName;
  const ChatThreadScreen({super.key, required this.peerId, required this.displayName});

  @override
  State<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends State<ChatThreadScreen> {
  final controller = ChatController.instance;
  String? selfUserId; // if you store it, fill here from prefs/profile

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChange);
    controller.openThread(widget.peerId);
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final messages = controller.thread(widget.peerId);
    return Scaffold(
      appBar: AppBar(title: Text(widget.displayName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              reverse: false,
              itemCount: messages.length,
              itemBuilder: (_, i) {
                final m = messages[i];
                final isMe = (selfUserId != null) ? m.fromUserId == selfUserId : false;
                return MessageBubble(message: m, isMe: isMe);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: InputBar(
              onSend: (text) async {
                // TODO: set your own user id from prefs/profile
                final uid = selfUserId ?? 'me';
                await controller.sendMessage(widget.peerId, text, selfUserId: uid);
              },
            ),
          ),
        ],
      ),
    );
  }
}
