import 'package:dio/dio.dart';
import 'package:llm_interface/src/features/chat/domain/chat_message.dart';

class LlmApiService {
  LlmApiService({
    required this.dio,
    String baseUrl = 'http://127.0.0.1:8008',
    String? model,
  }) : _baseUrl = baseUrl,
       _model = model;

  final Dio dio;
  String _baseUrl;
  String? _model;

  String get baseUrl => _baseUrl;
  String? get model => _model;

  void updateConfiguration({String? baseUrl, String? model}) {
    if (baseUrl != null) {
      _baseUrl = baseUrl;
    }
    if (model != null) {
      _model = model;
    } else if (model == null && _model != null) {
      _model = null;
    }
  }

  Future<String> sendConversation({
    required List<ChatMessage> messages,
    double? temperature,
    int? maxTokens,
  }) async {
    final Uri url = Uri.parse('$baseUrl/v1/chat/completions');
    final List<Map<String, String>> messageMaps = messages
        .map(
          (ChatMessage m) => <String, String>{
            'role': m.role.asOpenAiString(),
            'content': m.content,
          },
        )
        .toList();
    final Map<String, Object> payload = <String, Object>{
      if (model != null) 'model': model!,
      'messages': messageMaps,
      'temperature': temperature ?? 0.7,
      'max_tokens': maxTokens ?? 512,
      'stream': false,
    };
    final Response<dynamic> res = await dio.post(
      url.toString(),
      data: payload,
      options: Options(
        headers: <String, String>{'Content-Type': 'application/json'},
        validateStatus: (int? code) => code != null && code < 500,
      ),
    );
    if (res.statusCode != null && res.statusCode! >= 400) {
      throw Exception('HTTP ${res.statusCode}: ${res.data ?? 'No body'}');
    }
    final dynamic data = res.data;
    if (data is Map<String, dynamic>) {
      final List<dynamic>? choices = data['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final dynamic messageObj = choices.first['message'];
        if (messageObj is Map<String, dynamic>) {
          final String? content = messageObj['content'] as String?;
          if (content != null) {
            return content;
          }
        }
      }
    }
    throw Exception('Invalid response from LLM server: $data');
  }
}
