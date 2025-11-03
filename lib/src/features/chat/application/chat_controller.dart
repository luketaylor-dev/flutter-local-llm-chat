import 'dart:math';

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
      // Build message payload with optional summary (as system) + head + tail
      final List<ChatMessage> limitedHistory = _buildHistoryWithSummary(
        messagesWithUser,
      );
      final AppSettings s = ref.read(settingsProvider);
      // Update api baseUrl/model from settings dynamically
      final LlmApiService apiService = getIt.get<LlmApiService>();
      apiService.updateConfiguration(baseUrl: s.serverUrl, model: s.model);
      final String assistantContent = await repository.createChatCompletion(
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
      // Kick off background summarization if enabled
      // Smart timing: Only summarize if enough messages accumulated
      if (s.enableSummarization) {
        final List<ChatMessage> messagesWithoutSystem = updatedMessages
            .where((ChatMessage m) => m.role != ChatRole.system)
            .toList();
        // Find last summary index in the full list
        final int lastSummaryIndex = updatedMessages.lastIndexWhere(
          (ChatMessage m) => m.id == 'system-summary-current',
        );
        // Count non-system messages after the summary
        if (lastSummaryIndex >= 0) {
          // Get all messages after the summary (including system messages for counting)
          final List<ChatMessage> allAfterSummary = updatedMessages
              .skip(lastSummaryIndex + 1)
              .toList();
          // Count only non-system messages
          final int messagesAfterSummary = allAfterSummary
              .where((ChatMessage m) => m.role != ChatRole.system)
              .length;
          // Only summarize if we have 8+ messages since last summary
          // ignore: avoid_print
          print(
            '[LLM][summary] Messages since last summary: $messagesAfterSummary (threshold: 8)',
          );
          if (messagesAfterSummary >= 8) {
            // ignore: avoid_print
            print('[LLM][summary] Triggering background summarization...');
            _summarizeInBackground(updatedMessages);
          }
        } else {
          // No summary yet, summarize if we have enough messages total
          // ignore: avoid_print
          print(
            '[LLM][summary] No existing summary. Total messages: ${messagesWithoutSystem.length} (threshold: 10)',
          );
          if (messagesWithoutSystem.length >= 10) {
            // ignore: avoid_print
            print(
              '[LLM][summary] Triggering first background summarization...',
            );
            _summarizeInBackground(updatedMessages);
          }
        }
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Error: ${e.toString()}',
      );
    }
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

  List<ChatMessage> _buildHistoryWithSummary(List<ChatMessage> messages) {
    // Find the summary message by its specific ID (if it exists)
    ChatMessage? summaryMessage;
    try {
      summaryMessage = messages.firstWhere(
        (ChatMessage m) => m.id == 'system-summary-current',
      );
    } catch (e) {
      // Summary not found, which is fine
      summaryMessage = null;
    }

    // Filter out system messages from the messages list before limiting
    // (system messages shouldn't count against limits and will be added separately)
    final List<ChatMessage> messagesWithoutSystem = messages
        .where((ChatMessage m) => m.role != ChatRole.system)
        .toList();

    final List<ChatMessage> trimmed = _limitHistory(messagesWithoutSystem);

    // Build result: summary (if exists) + trimmed messages
    final List<ChatMessage> result = <ChatMessage>[];
    if (summaryMessage != null) {
      result.add(summaryMessage);
    }
    result.addAll(trimmed);
    return result;
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
    // Prevent deletion of summary messages
    if (messageId == 'system-summary-current') {
      // ignore: avoid_print
      print('[LLM][summary] Attempted to delete summary - preventing deletion');
      return;
    }
    final List<ChatMessage> updated = <ChatMessage>[
      for (final ChatMessage m in state.messages)
        if (m.id != messageId) m,
    ];
    state = state.copyWith(messages: updated);
    await _persistSession(updated);
  }

  Future<void> _summarizeInBackground(List<ChatMessage> messages) async {
    // Build a prompt asking the LLM to summarize the important facts and state
    // Filter out system messages before processing (they don't count against limits)
    final List<ChatMessage> messagesWithoutSystem = messages
        .where((ChatMessage m) => m.role != ChatRole.system)
        .toList();

    // Calculate what will be sent (head + tail) using the same logic as _limitHistory
    // This determines which messages are in the "tail" that will be sent
    final List<ChatMessage> trimmed = _limitHistory(messagesWithoutSystem);

    // Messages for summary = everything EXCEPT what's in trimmed (head + tail)
    // These are messages in the "middle" that will be summarized and replaced
    final Set<String> trimmedIds = <String>{
      ...trimmed.map((ChatMessage m) => m.id),
    };

    final List<ChatMessage> forSummary = messagesWithoutSystem
        .where((ChatMessage m) => !trimmedIds.contains(m.id))
        .toList();

    // Only summarize if there are messages to summarize
    if (forSummary.isEmpty) {
      // ignore: avoid_print
      print('[LLM][summary] No messages to summarize, skipping.');
      return;
    }

    // Smart summary timing: Only summarize if we have enough messages
    // This prevents summarizing too frequently for short conversations
    // ignore: avoid_print
    print(
      '[LLM][summary] Messages to summarize: ${forSummary.length} (minimum: 5)',
    );
    if (forSummary.length < 5) {
      // ignore: avoid_print
      print('[LLM][summary] Not enough messages to summarize, skipping.');
      return;
    }

    // Check if there's an existing summary to merge with
    ChatMessage? existingSummary;
    try {
      existingSummary = messages.firstWhere(
        (ChatMessage m) => m.id == 'system-summary-current',
      );
    } catch (e) {
      existingSummary = null;
    }
    final bool hasExistingSummary = existingSummary != null;

    // Adaptive summary size based on conversation length
    // More messages = larger summary needed to preserve detail
    final int totalMessages = messagesWithoutSystem.length;
    final int summaryMaxTokens = totalMessages < 20
        ? 800
        : totalMessages < 50
        ? 1200
        : totalMessages < 100
        ? 1800
        : 2500;

    // Structured summary prompt optimized for story/world building
    final String summaryPrompt = hasExistingSummary
        ? '''Update and expand the existing world state summary with new information from the recent conversation. Preserve all existing important details.

Format your response as a structured summary with these sections:

## Characters
- List all characters mentioned, their descriptions, relationships, and current status
- Include any new characters introduced

## World & Locations  
- Document all places, settings, and established world facts
- Note any world-building details, rules, or constraints

## Plot Threads
- Summarize ongoing storylines and unresolved questions
- Track significant events and their consequences

## Recent Events
- Brief summary of what happened in the messages being summarized
- Focus on important developments and decisions

IMPORTANT:
- Preserve ALL existing important information from the previous summary
- Only add or update information that has changed or is new
- Do not invent facts not present in the conversation
- Be thorough but concise
- Maintain consistency with established facts'''
        : '''Create a comprehensive world state summary from this conversation. This summary will be used to maintain context in a long-running roleplay/story conversation.

Format your response as a structured summary with these sections:

## Characters
- List all characters mentioned, their descriptions, relationships, and current status
- Note character traits, motivations, and relationships between characters

## World & Locations
- Document all places, settings, and established world facts
- Note any world-building details, rules, magic systems, or constraints
- Record any important locations and their characteristics

## Plot Threads
- Summarize ongoing storylines and unresolved questions
- Track significant events and their consequences
- Note any mysteries, goals, or ongoing conflicts

## Recent Events
- Brief summary of key events that have occurred
- Focus on important developments and decisions made

IMPORTANT:
- Be thorough and detailed - this summary will be the primary context for future messages
- Do not invent facts not present in the conversation
- Preserve nuances and important details
- Organize information clearly for easy reference''';

    final List<ChatMessage> summaryMessages = <ChatMessage>[
      ChatMessage(
        id: 'system-summary',
        role: ChatRole.system,
        content: hasExistingSummary
            ? 'You are a world state summarization assistant for a roleplay/story conversation. Your task is to update and expand the existing world state summary with new information, preserving all important existing details. You only summarize facts present in the conversation and never invent new information.'
            : 'You are a world state summarization assistant for a roleplay/story conversation. Your task is to create a comprehensive summary that preserves all important details about characters, world, plot, and events. You only summarize facts present in the conversation and never invent new information.',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      ),
      if (hasExistingSummary)
        ChatMessage(
          id: 'existing-summary',
          role: ChatRole.user,
          content: 'EXISTING SUMMARY:\n${existingSummary.content}',
          timestamp: DateTime.fromMillisecondsSinceEpoch(1),
        ),
      ...forSummary,
      ChatMessage(
        id: _generateId(),
        role: ChatRole.user,
        content: summaryPrompt,
        timestamp: DateTime.now(),
      ),
    ];
    try {
      final String summary = await getIt
          .get<LlmRepository>()
          .createChatCompletion(
            messages: summaryMessages,
            temperature: 0.1, // Lower temperature for factual accuracy
            maxTokens: summaryMaxTokens,
          );
      // ignore: avoid_print
      print(
        '[LLM][summary] Generated summary (len=${summary.length}):\n$summary',
      );
      // Store summary as a system message at the start of the state
      final ChatMessage systemSummary = ChatMessage(
        id: 'system-summary-current',
        role: ChatRole.system,
        content: summary,
        timestamp: DateTime.now(),
      );
      // Keep only one system summary (replace existing)
      // Get current state to avoid race conditions
      final List<ChatMessage> currentMessages = state.messages;
      final List<ChatMessage> withoutOldSummary = <ChatMessage>[
        for (final ChatMessage m in currentMessages)
          if (m.id != 'system-summary-current') m,
      ];
      // Add the new summary at the beginning
      final List<ChatMessage> updatedMessages = <ChatMessage>[
        systemSummary,
        ...withoutOldSummary,
      ];
      // ignore: avoid_print
      print(
        '[LLM][summary] Updating state with new summary. Total messages: ${updatedMessages.length}',
      );
      state = state.copyWith(messages: updatedMessages);
      await _persistSession(updatedMessages);
      // ignore: avoid_print
      print('[LLM][summary] Summary update complete and persisted.');
    } catch (e) {
      // Log background summary errors but don't show to user
      // ignore: avoid_print
      print('[LLM][summary] Error: $e');
    }
  }

  String _generateId() {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final int random = Random().nextInt(1 << 32);
    return '$timestamp-$random';
  }
}
