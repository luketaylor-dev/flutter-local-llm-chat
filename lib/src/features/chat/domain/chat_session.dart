import 'package:llm_interface/src/features/chat/domain/chat_message.dart';

class ChatSession {
  const ChatSession({
    required this.id,
    required this.title,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatSession copyWith({
    String? id,
    String? title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChatSession(
      id: id ?? this.id,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'id': id,
      'title': title,
      'messages': messages.map((ChatMessage m) => m.toMap()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static ChatSession fromMap(Map<String, dynamic> map) {
    final List<dynamic> msgs = map['messages'] as List<dynamic>? ?? <dynamic>[];
    return ChatSession(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Chat',
      messages: msgs
          .map((dynamic e) => ChatMessage.fromMap(e as Map<String, dynamic>))
          .toList(),
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
