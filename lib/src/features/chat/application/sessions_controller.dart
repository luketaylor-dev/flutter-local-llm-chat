import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_interface/src/features/chat/data/local_chat_repository.dart';
import 'package:llm_interface/src/features/chat/domain/chat_message.dart';
import 'package:llm_interface/src/features/chat/domain/chat_session.dart';

final NotifierProvider<SessionsController, List<ChatSession>> sessionsProvider =
    NotifierProvider<SessionsController, List<ChatSession>>(
      SessionsController.new,
    );

class SessionsController extends Notifier<List<ChatSession>> {
  late final LocalChatRepository repository;

  @override
  List<ChatSession> build() {
    repository = LocalChatRepository();
    return <ChatSession>[];
  }

  Future<void> loadSessions() async {
    final List<ChatSession> sessions = await repository.loadSessions();
    state = sessions;
  }

  Future<ChatSession> createSession() async {
    final ChatSession session = ChatSession(
      id: _generateId(),
      title: 'New Chat',
      messages: <ChatMessage>[],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final List<ChatSession> updated = <ChatSession>[session, ...state];
    state = updated;
    await repository.saveSessions(updated);
    return session;
  }

  Future<void> upsertSession(ChatSession session) async {
    final List<ChatSession> updated = <ChatSession>[
      for (final ChatSession s in state)
        if (s.id == session.id) session else s,
    ];
    if (!updated.any((ChatSession s) => s.id == session.id)) {
      updated.insert(0, session);
    }
    state = updated;
    await repository.saveSessions(updated);
  }

  Future<void> removeSession(String sessionId) async {
    final List<ChatSession> updated = <ChatSession>[
      for (final ChatSession s in state)
        if (s.id != sessionId) s,
    ];
    state = updated;
    await repository.saveSessions(updated);
  }

  Future<void> renameSession({
    required String sessionId,
    required String title,
  }) async {
    final List<ChatSession> updated = <ChatSession>[
      for (final ChatSession s in state)
        if (s.id == sessionId)
          s.copyWith(title: title, updatedAt: DateTime.now())
        else
          s,
    ];
    state = updated;
    await repository.saveSessions(updated);
  }

  Future<ChatSession> duplicateSession(String sessionId) async {
    final ChatSession original = state.firstWhere(
      (ChatSession s) => s.id == sessionId,
      orElse: () => throw Exception('Session not found: $sessionId'),
    );
    final String newTitle = original.title.isEmpty
        ? 'Copy of Chat'
        : 'Copy of ${original.title}';
    final ChatSession duplicated = ChatSession(
      id: _generateId(),
      title: newTitle,
      messages: List<ChatMessage>.from(original.messages),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final List<ChatSession> updated = <ChatSession>[duplicated, ...state];
    state = updated;
    await repository.saveSessions(updated);
    return duplicated;
  }

  String _generateId() {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final int random = Random().nextInt(1 << 32);
    return '$timestamp-$random';
  }
}
