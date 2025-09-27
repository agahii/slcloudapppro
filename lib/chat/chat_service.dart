import 'dart:async';
import 'dart:convert';

import 'package:slcloudapppro/signalr_service.dart';

import 'models/chat_user.dart';
import 'models/chat_message.dart';

/// High-level chat bindings on top of SignalRService.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  // Server -> client events (customize names if different on your hub)
  static const String evtUsersOnline = 'UsersOnline';
  static const String evtUserOnline = 'UserOnline';
  static const String evtUserOffline = 'UserOffline';
  static const String evtReceiveMessage = 'ReceiveMessage';
  static const String evtReceiveMessageFromServer = 'ReceiveMessageFromServer';

  // Client -> server invocations
  static const String opGetOnlineUsers = 'GetOnlineUsers';
  static const String opSendToUser = 'SendToUser'; // (targetUserId, text, clientMessageId)
  static const String opGetThread = 'GetThread';   // (peerId, cursor?)

  final _usersSnapshotCtrl = StreamController<List<ChatUser>>.broadcast();
  final _presenceDiffCtrl = StreamController<ChatUser>.broadcast(); // online status in isOnline flag
  final _messageCtrl = StreamController<ChatMessage>.broadcast();

  Stream<List<ChatUser>> get usersSnapshotStream => _usersSnapshotCtrl.stream;
  Stream<ChatUser> get presenceDiffStream => _presenceDiffCtrl.stream;
  Stream<ChatMessage> get messageStream => _messageCtrl.stream;

  bool _registered = false;

  /// Register hub event handlers. Idempotent.
  void ensureRegistered() {
    if (_registered) return;
    final s = SignalRService.instance;
    s.on(evtUsersOnline, (args) {
      try {
        final raw = _firstArg(args);
        final list = _parseList(raw).map((e) => ChatUser.fromJson(e)).toList();
        _usersSnapshotCtrl.add(list);
      } catch (_) {}
    });
    s.on(evtUserOnline, (args) {
      try {
        final raw = _firstArg(args);
        final user = ChatUser.fromJson(_parseMap(raw));
        _presenceDiffCtrl.add(user.copyWith(isOnline: true));
      } catch (_) {}
    });
    s.on(evtUserOffline, (args) {
      try {
        final id = _firstArg(args).toString();
        _presenceDiffCtrl.add(ChatUser(id: id, displayName: id, isOnline: false));
      } catch (_) {}
    });
    s.on(evtReceiveMessage, (args) {
      try {
        final raw = _firstArg(args);
        final msg = ChatMessage.fromJson(_parseMap(raw));
        _messageCtrl.add(msg);
      } catch (_) {}
    });
    s.on(evtReceiveMessageFromServer, (args) {
      try {
        final raw = _firstArg(args);
        final map = _parseMap(raw);
        final users = _extractUsersFromEnvelope(map);
        if (users.isNotEmpty) {
          _usersSnapshotCtrl.add(users);
          return;
        }
        final diff = _extractPresenceDiff(map);
        if (diff != null) {
          _presenceDiffCtrl.add(diff);
          return;
        }
        final msg = _extractMessage(map);
        if (msg != null) _messageCtrl.add(msg);
      } catch (_) {}
    });
    _registered = true;
  }

  Future<void> requestUsersSnapshot() async {
    final payload = {
      'SenderUniqueMsgID': _newGuid(),
      'MsgType': 'welcome',
      'From': SignalRService.instance.connectionId ?? '',
      'Msg': 'SendUserList',
      'To': '',
    };
    await SignalRService.instance.invoke('ReceiveMessageFromClient', args: [payload]);
  }

  Future<void> sendToUser({required String targetUserId, required String text, String? clientMessageId}) async {
    await SignalRService.instance.invoke(opSendToUser, args: [targetUserId, text, clientMessageId ?? '']);
  }

  // Helpers to normalize payloads coming from hub
  static dynamic _firstArg(List<Object?>? args) => (args == null || args.isEmpty) ? null : args.first;
  static Map<String, dynamic> _parseMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.map((k, v) => MapEntry(k.toString(), v));
    if (raw is String && raw.trim().startsWith('{')) return json.decode(raw) as Map<String, dynamic>;
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> _parseList(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => _parseMap(e)).toList();
    }
    if (raw is String && raw.trim().startsWith('[')) {
      final l = json.decode(raw) as List;
      return l.map((e) => _parseMap(e)).toList();
    }
    return const [];
  }

  static List<ChatUser> _extractUsersFromEnvelope(Map<String, dynamic> map) {
    final candidates = [
      map['users'],
      map['Users'],
      map['userList'],
      map['UserList'],
      (map['data'] is Map) ? (map['data'] as Map)['users'] : null,
    ].where((e) => e != null).toList();
    for (final c in candidates) {
      final list = _parseList(c);
      if (list.isNotEmpty) return list.map(ChatUser.fromJson).toList();
    }
    return const [];
  }

  static ChatUser? _extractPresenceDiff(Map<String, dynamic> map) {
    final event = (map['event'] ?? map['Event'] ?? map['MsgType'] ?? '').toString().toLowerCase();
    if (event.contains('online') && map['user'] != null) {
      final u = ChatUser.fromJson(_parseMap(map['user']));
      return u.copyWith(isOnline: true);
    }
    if (event.contains('offline')) {
      final id = (map['id'] ?? map['userId'] ?? '').toString();
      if (id.isNotEmpty) return ChatUser(id: id, displayName: id, isOnline: false);
    }
    return null;
  }

  static ChatMessage? _extractMessage(Map<String, dynamic> map) {
    final data = map['data'] ?? map['Data'];
    if (data != null) {
      final dm = _parseMap(data);
      if (dm.isNotEmpty) return ChatMessage.fromJson(dm);
    }
    if (map.containsKey('message') || map.containsKey('text')) {
      return ChatMessage.fromJson(map);
    }
    return null;
  }

  static String _newGuid() {
    const hex = '0123456789abcdef';
    int seed = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    String next(int len) {
      var s = StringBuffer();
      for (var i = 0; i < len; i++) {
        seed = (214013 * seed + 2531011) & 0x7fffffff;
        s.write(hex[(seed >> 16) & 0xF]);
      }
      return s.toString();
    }
    return '${next(8)}-${next(4)}-${next(4)}-${next(4)}-${next(12)}';
  }
}
