import 'package:llm_interface/src/features/chat/data/llm_api_service.dart';
import 'package:llm_interface/src/features/chat/domain/chat_message.dart';

class LlmRepository {
  LlmRepository({required this.apiService});
  final LlmApiService apiService;
  Future<String> createChatCompletion({
    required List<ChatMessage> messages,
    required double temperature,
    required int maxTokens,
  }) async {
    return apiService.sendConversation(
      messages: messages,
      temperature: temperature,
      maxTokens: maxTokens,
    );
  }
}
