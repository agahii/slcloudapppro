import 'package:flutter/material.dart';
import '../../chat/models/chat_message.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  const MessageBubble({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.08);
    final fg = isMe ? Theme.of(context).colorScheme.onPrimary : Colors.white;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(2),
      bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(16),
    );
    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: bg, borderRadius: radius),
          child: Column(
            crossAxisAlignment: align,
            children: [
              Text(
                message.text,
                style: TextStyle(color: fg, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: 0.6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _fmtTime(message.sentAt),
                      style: TextStyle(color: fg, fontSize: 10),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      message.status == MessageStatus.failed
                          ? Icons.error_outline
                          : message.status == MessageStatus.sending
                              ? Icons.schedule
                              : Icons.check,
                      size: 12,
                      color: fg,
                    )
                  ],
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  static String _fmtTime(DateTime dt) => '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}'
      .toString();
}

