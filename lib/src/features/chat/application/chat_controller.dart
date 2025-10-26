import 'dart:math';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:llm_interface/src/di/di.dart';
import 'package:llm_interface/src/features/chat/application/chat_state.dart';
import 'package:llm_interface/src/features/chat/data/llm_repository.dart';
import 'package:llm_interface/src/features/chat/domain/chat_message.dart';
import 'package:llm_interface/src/features/chat/application/sessions_controller.dart';
import 'package:llm_interface/src/features/chat/domain/chat_session.dart';
import 'package:llm_interface/src/features/settings/application/settings_controller.dart';
import 'package:llm_interface/src/features/settings/domain/app_settings.dart';
import 'package:llm_interface/src/features/chat/data/llm_api_service.dart';
import 'package:dio/dio.dart';

final NotifierProvider<ChatController, ChatState> chatControllerProvider =
    NotifierProvider<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  late final LlmRepository repository;
  String? _currentSessionId;

  @override
  ChatState build() {
    repository = getIt.get<LlmRepository>();
    return ChatState.initial();
  }

  void setSessionId(String sessionId) {
    _currentSessionId = sessionId;
  }

  void startSession({
    required String sessionId,
    required List<ChatMessage> messages,
  }) {
    _currentSessionId = sessionId;
    state = ChatState(messages: messages, isLoading: false);
  }

  Future<void> sendMessage({required String content}) async {
    if (content.trim().isEmpty) {
      return;
    }
    final ChatMessage userMessage = ChatMessage(
      id: _generateId(),
      role: ChatRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
    final List<ChatMessage> messagesWithUser = <ChatMessage>[
      ...state.messages,
      userMessage,
    ];
    state = state.copyWith(
      messages: messagesWithUser,
      isLoading: true,
      errorMessage: null,
    );
    try {
      final List<ChatMessage> limitedHistory = _limitHistory(messagesWithUser);
      final AppSettings s = ref.read(settingsProvider);
      // Update api baseUrl/model from settings dynamically
      getIt.unregister<LlmApiService>();
      getIt.registerSingleton<LlmApiService>(
        LlmApiService(
          dio: getIt.get<Dio>(),
          baseUrl: s.serverUrl,
          model: s.model,
        ),
      );
      getIt.unregister<LlmRepository>();
      getIt.registerSingleton<LlmRepository>(
        LlmRepository(apiService: getIt.get<LlmApiService>()),
      );
      final String assistantContent = await getIt
          .get<LlmRepository>()
          .createChatCompletion(
            messages: limitedHistory,
            temperature: s.temperature,
            maxTokens: s.maxTokens,
          );
      final ChatMessage assistantMessage = ChatMessage(
        id: _generateId(),
        role: ChatRole.assistant,
        content: assistantContent,
        timestamp: DateTime.now(),
      );
      final List<ChatMessage> updatedMessages = <ChatMessage>[
        ...state.messages,
        assistantMessage,
      ];
      state = state.copyWith(messages: updatedMessages, isLoading: false);
      await _persistSession(updatedMessages);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  String _generateId() {
    final int ts = DateTime.now().millisecondsSinceEpoch;
    final int rand = Random().nextInt(1 << 32);
    return '$ts-$rand';
  }

  Future<void> _persistSession(List<ChatMessage> updatedMessages) async {
    final String? sessionId = _currentSessionId;
    if (sessionId == null) {
      return;
    }
    final List<ChatSession> sessions = ref.read(sessionsProvider);
    ChatSession? existing = sessions
        .where((ChatSession s) => s.id == sessionId)
        .cast<ChatSession?>()
        .firstWhere((ChatSession? s) => s != null, orElse: () => null);
    if (existing == null) {
      existing = ChatSession(
        id: sessionId,
        title: _deriveTitle(updatedMessages),
        messages: updatedMessages,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } else {
      existing = existing.copyWith(
        messages: updatedMessages,
        updatedAt: DateTime.now(),
        title: existing.title.isEmpty
            ? _deriveTitle(updatedMessages)
            : existing.title,
      );
    }
    await ref.read(sessionsProvider.notifier).upsertSession(existing);
  }

  String _deriveTitle(List<ChatMessage> messages) {
    final ChatMessage firstUser = messages.firstWhere(
      (ChatMessage m) => m.role == ChatRole.user && m.content.trim().isNotEmpty,
      orElse: () => ChatMessage(
        id: '',
        role: ChatRole.user,
        content: 'Chat',
        timestamp: DateTime.now(),
      ),
    );
    final String text = firstUser.content.trim();
    return text.length > 40 ? '${text.substring(0, 40)}…' : text;
  }

  List<ChatMessage> _limitHistory(List<ChatMessage> messages) {
    final AppSettings s = ref.read(settingsProvider);
    final int keepHeadCount = messages.length >= s.keepHeadCount
        ? s.keepHeadCount
        : messages.length;
    final List<ChatMessage> head = messages.take(keepHeadCount).toList();
    final List<ChatMessage> tailCandidates = messages
        .skip(keepHeadCount)
        .toList();

    final int allowedTailCount = s.maxHistoryMessages > keepHeadCount
        ? s.maxHistoryMessages - keepHeadCount
        : 0;
    final List<ChatMessage> tailByCount =
        tailCandidates.length > allowedTailCount
        ? tailCandidates.sublist(tailCandidates.length - allowedTailCount)
        : tailCandidates;

    if (s.maxHistoryChars <= 0) {
      return <ChatMessage>[...head, ...tailByCount];
    }
    final int headChars = head.fold<int>(
      0,
      (int acc, ChatMessage m) => acc + m.content.length,
    );
    if (headChars >= s.maxHistoryChars) {
      // Ensure we still include some recent context even if the head exceeds the char cap
      final int allowedTailCount = s.maxHistoryMessages > keepHeadCount
          ? s.maxHistoryMessages - keepHeadCount
          : 0;
      final int guaranteedTailCount = allowedTailCount > 5
          ? 5
          : allowedTailCount;
      final List<ChatMessage> guaranteedTail = guaranteedTailCount > 0
          ? tailCandidates.sublist(tailCandidates.length - guaranteedTailCount)
          : <ChatMessage>[];
      return <ChatMessage>[...head, ...guaranteedTail];
    }
    final int remainingChars = s.maxHistoryChars - headChars;
    int used = 0;
    final List<ChatMessage> keptTailReversed = <ChatMessage>[];
    for (final ChatMessage m in tailByCount.reversed) {
      final int len = m.content.length;
      if (used + len > remainingChars) {
        break;
      }
      keptTailReversed.add(m);
      used += len;
    }
    final List<ChatMessage> keptTail = keptTailReversed.reversed.toList();
    // Final order: head (oldest few) + keptTail (recent messages up to caps)
    return <ChatMessage>[...head, ...keptTail];
  }

  Future<void> deleteMessage({required String messageId}) async {
    final List<ChatMessage> updated = <ChatMessage>[
      for (final ChatMessage m in state.messages)
        if (m.id != messageId) m,
    ];
    state = state.copyWith(messages: updated);
    await _persistSession(updated);
  }
}
