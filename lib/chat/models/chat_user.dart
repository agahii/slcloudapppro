class ChatUser {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isOnline;
  final bool isSupport;
  final String email;

  const ChatUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isOnline = false,
    this.isSupport = false,
    this.email = '',
  });

  ChatUser copyWith({String? id, String? displayName, String? avatarUrl, bool? isOnline, bool? isSupport, String? email}) => ChatUser(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        isOnline: isOnline ?? this.isOnline,
        isSupport: isSupport ?? this.isSupport,
        email: email ?? this.email,
      );

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    // Support multiple casings from backend: id/ID, fullName/FullName, status/Status, isSupport/IsSupport
    final rawId = json['id'] ?? json['ID'] ?? json['userId'] ?? json['employeeId'] ?? '';
    final rawName = json['displayName'] ?? json['fullName'] ?? json['FullName'] ?? json['name'] ?? json['mobileNumber'] ?? '';
    final rawStatus = json['isOnline'] ?? json['online'] ?? json['status'] ?? json['Status'] ?? true;
    final rawSupport = json['isSupport'] ?? json['IsSupport'] ?? false;
    final rawEmail = json['email'] ?? json['Email'] ?? json['emailAddress'] ?? json['EmailAddress'] ?? '';
    bool parseBool(dynamic v) {
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      if (v is num) return v != 0;
      return false;
    }
    String parseEmail(dynamic e, dynamic id) {
      final s = (e ?? '').toString();
      if (s.isNotEmpty) return s;
      final idStr = (id ?? '').toString();
      return idStr.contains('@') ? idStr : '';
    }
    return ChatUser(
      id: rawId.toString(),
      displayName: rawName.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      isOnline: parseBool(rawStatus),
      isSupport: parseBool(rawSupport),
      email: parseEmail(rawEmail, rawId),
    );
  }
}
