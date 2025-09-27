class ChatMessage {
  final String id;
  final String threadId; // peerId for 1:1
  final String fromUserId;
  final String toUserId;
  final String text;
  final DateTime sentAt;
  final MessageStatus status;

  const ChatMessage({
    required this.id,
    required this.threadId,
    required this.fromUserId,
    required this.toUserId,
    required this.text,
    required this.sentAt,
    this.status = MessageStatus.sent,
  });

  ChatMessage copyWith({
    String? id,
    String? threadId,
    String? fromUserId,
    String? toUserId,
    String? text,
    DateTime? sentAt,
    MessageStatus? status,
  }) => ChatMessage(
        id: id ?? this.id,
        threadId: threadId ?? this.threadId,
        fromUserId: fromUserId ?? this.fromUserId,
        toUserId: toUserId ?? this.toUserId,
        text: text ?? this.text,
        sentAt: sentAt ?? this.sentAt,
        status: status ?? this.status,
      );

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] ?? json['messageId'] ?? '').toString(),
        threadId: (json['threadId'] ?? json['peerId'] ?? json['toUserId'] ?? '').toString(),
        fromUserId: (json['fromUserId'] ?? json['from'] ?? '').toString(),
        toUserId: (json['toUserId'] ?? json['to'] ?? '').toString(),
        text: (json['text'] ?? json['message'] ?? '').toString(),
        sentAt: DateTime.tryParse((json['sentAt'] ?? json['timestamp'] ?? '').toString()) ?? DateTime.now(),
        status: MessageStatus.sent,
      );
}

enum MessageStatus { sending, sent, failed }

