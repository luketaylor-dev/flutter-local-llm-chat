class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;

  Map<String, Object> toMap() {
    return <String, Object>{
      'id': id,
      'role': role.name,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  static ChatMessage fromMap(Map<String, dynamic> map) {
    final String roleStr = map['role'] as String? ?? 'user';
    final ChatRole role = roleStr == 'assistant'
        ? ChatRole.assistant
        : roleStr == 'system'
        ? ChatRole.system
        : ChatRole.user;
    return ChatMessage(
      id: map['id'] as String? ?? '',
      role: role,
      content: map['content'] as String? ?? '',
      timestamp:
          DateTime.tryParse(map['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum ChatRole { user, assistant, system }

extension ChatRoleAsString on ChatRole {
  String asOpenAiString() {
    switch (this) {
      case ChatRole.user:
        return 'user';
      case ChatRole.assistant:
        return 'assistant';
      case ChatRole.system:
        return 'system';
    }
  }
}
