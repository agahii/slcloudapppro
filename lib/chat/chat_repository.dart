import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';
import 'models/chat_message.dart';

class ChatRepository {
  ChatRepository._();
  static final ChatRepository instance = ChatRepository._();

  Future<List<ChatMessage>> fetchThread(String peerId, {int take = 30}) async {
    // Placeholder implementation. Replace with your real API when available.
    // Falls back to asking the hub, or returns empty until endpoint exists.
    try {
      // Example REST endpoint (adjust to your backend):
      // final uri = Uri.parse('${ApiService.baseUrl}/api/Chat/Thread?peerId=$peerId&take=$take');
      // final prefs = await SharedPreferences.getInstance();
      // final token = prefs.getString('token') ?? '';
      // final resp = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      // if (resp.statusCode == 200) {
      //   final list = (jsonDecode(resp.body)['items'] as List).cast<Map<String, dynamic>>();
      //   return list.map(ChatMessage.fromJson).toList();
      // }
      // throw ApiException(resp.statusCode, ApiService.extractServerMessage(resp));
      return const [];
    } catch (_) {
      return const [];
    }
  }
}

