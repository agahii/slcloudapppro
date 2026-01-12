import 'package:flutter/material.dart';
import '../../chat/chat_controller.dart';
import '../../chat/models/chat_user.dart';
import '../../chat/chat_service.dart';

class UsersOnlineScreen extends StatefulWidget {
  const UsersOnlineScreen({super.key});

  @override
  State<UsersOnlineScreen> createState() => _UsersOnlineScreenState();
}

class _UsersOnlineScreenState extends State<UsersOnlineScreen> {
  final controller = ChatController.instance;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChange);
    controller.init();
  }

  @override
  void dispose() {
    controller.removeListener(_onChange);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final users = controller.onlineUsers
        .where((u) {
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return u.displayName.toLowerCase().contains(q) ||
              u.id.toLowerCase().contains(q) ||
              (u.email.isNotEmpty && u.email.toLowerCase().contains(q));
        })
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search users by name or ID',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
        ),
      ),
      body: users.isEmpty
          ? const Center(child: Text('No users found'))
          : RefreshIndicator(
              onRefresh: () async => ChatService.instance.requestUsersSnapshot(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.2),
                itemBuilder: (_, i) => _UserTile(user: users[i]),
              ),
            ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final ChatUser user;
  const _UserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final onlineColor = user.isOnline ? Colors.green : Colors.grey;
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?')),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: onlineColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      title: Text(user.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.email.isNotEmpty) Text(user.email, style: const TextStyle(fontSize: 12)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: onlineColor),
              const SizedBox(width: 6),
              Text(user.isOnline ? 'Online' : 'Offline', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.chat_bubble_outline_rounded),
      onTap: () async {
        await ChatController.instance.openThread(user.id);
        if (!context.mounted) return;
        Navigator.pushNamed(context, '/chat/thread', arguments: {'peerId': user.id, 'name': user.displayName});
      },
    );
  }
}
