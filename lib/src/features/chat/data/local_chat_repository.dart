import 'dart:convert';

import 'package:llm_interface/src/features/chat/domain/chat_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalChatRepository {
  LocalChatRepository();
  static const String _sessionsKey = 'chat_sessions_v1';

  Future<List<ChatSession>> loadSessions() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_sessionsKey);
    if (raw == null || raw.isEmpty) {
      return <ChatSession>[];
    }
    final List<dynamic> list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((dynamic e) => ChatSession.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSessions(List<ChatSession> sessions) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String raw = jsonEncode(
      sessions.map((ChatSession s) => s.toMap()).toList(),
    );
    await prefs.setString(_sessionsKey, raw);
  }
}
