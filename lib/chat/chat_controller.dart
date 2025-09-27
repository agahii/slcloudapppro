import 'dart:collection';
import 'package:flutter/foundation.dart';

import 'chat_repository.dart';
import 'chat_service.dart';
import 'models/chat_message.dart';
import 'models/chat_user.dart';

class ChatController extends ChangeNotifier {
  ChatController._();
  static final ChatController instance = ChatController._();

  final Map<String, ChatUser> _onlineUsers = {};
  UnmodifiableListView<ChatUser> get onlineUsers => UnmodifiableListView(
      _onlineUsers.values.toList()..sort((a, b) => a.displayName.compareTo(b.displayName)));

  final Map<String, List<ChatMessage>> _threads = {}; // key = peerId
  UnmodifiableListView<ChatMessage> thread(String peerId) => UnmodifiableListView(_threads[peerId] ?? const []);

  bool _initialized = false;
  bool get initialized => _initialized;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    ChatService.instance.ensureRegistered();
    // Presence snapshot
    ChatService.instance.usersSnapshotStream.listen((list) {
      _onlineUsers
        ..clear()
        ..addEntries(list.map((u) => MapEntry(u.id, u.copyWith(isOnline: true))));
      notifyListeners();
    });
    // Presence diffs
    ChatService.instance.presenceDiffStream.listen((user) {
      if (user.isOnline) {
        _onlineUsers[user.id] = user.copyWith(isOnline: true);
      } else {
        final existing = _onlineUsers[user.id];
        if (existing != null) _onlineUsers[user.id] = existing.copyWith(isOnline: false);
      }
      notifyListeners();
    });
    // Incoming messages
    ChatService.instance.messageStream.listen((m) {
      final list = _threads.putIfAbsent(m.threadId, () => <ChatMessage>[]);
      list.add(m);
      notifyListeners();
    });

    // Ask for initial presence snapshot
    await ChatService.instance.requestUsersSnapshot();
  }

  Future<void> openThread(String peerId) async {
    if (!_initialized) await init();
    if (!_threads.containsKey(peerId)) {
      final history = await ChatRepository.instance.fetchThread(peerId);
      _threads[peerId] = history.toList();
    }
    notifyListeners();
  }

  Future<void> sendMessage(String peerId, String text, {required String selfUserId}) async {
    final tempId = DateTime.now().microsecondsSinceEpoch.toString();
    final msg = ChatMessage(
      id: tempId,
      threadId: peerId,
      fromUserId: selfUserId,
      toUserId: peerId,
      text: text.trim(),
      sentAt: DateTime.now(),
      status: MessageStatus.sending,
    );
    final list = _threads.putIfAbsent(peerId, () => <ChatMessage>[]);
    list.add(msg);
    notifyListeners();

    try {
      await ChatService.instance.sendToUser(targetUserId: peerId, text: text, clientMessageId: tempId);
      // optimistic: mark as sent
      final idx = list.indexWhere((m) => m.id == tempId);
      if (idx >= 0) list[idx] = list[idx].copyWith(status: MessageStatus.sent);
    } catch (_) {
      final idx = list.indexWhere((m) => m.id == tempId);
      if (idx >= 0) list[idx] = list[idx].copyWith(status: MessageStatus.failed);
    }
    notifyListeners();
  }
}

