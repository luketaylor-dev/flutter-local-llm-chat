import 'package:llm_interface/src/features/chat/domain/chat_message.dart';

class ChatState {
  const ChatState({
    required this.messages,
    required this.isLoading,
    this.errorMessage,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? errorMessage;

  factory ChatState.initial() {
    return const ChatState(messages: <ChatMessage>[], isLoading: false);
  }

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
