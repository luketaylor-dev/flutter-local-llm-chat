import 'dart:async';
import 'dart:convert';

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
    // Validate and construct URL
    final String fullUrl = '$baseUrl/v1/chat/completions';
    // ignore: avoid_print
    print('[LLM][API] Connecting to: $fullUrl');
    final Uri url = Uri.parse(fullUrl);
    if (!url.hasScheme || !url.hasAuthority) {
      throw Exception(
        'Invalid server URL: $baseUrl (must include scheme like http://)',
      );
    }
    final List<Map<String, String>> messageMaps = messages
        .map(
          (ChatMessage m) => <String, String>{
            'role': m.role.asOpenAiString(),
            'content': m.content,
          },
        )
        .toList();
    // Ensure maxTokens is valid (not null, not 0, reasonable max)
    final int effectiveMaxTokens = maxTokens != null && maxTokens > 0
        ? maxTokens
        : 2048; // Default to 2048 instead of 512 for longer responses
    final Map<String, Object> payload = <String, Object>{
      if (model != null) 'model': model!,
      'messages': messageMaps,
      'temperature': temperature ?? 0.7,
      'max_tokens': effectiveMaxTokens,
      'stream': false,
    };
    // ignore: avoid_print
    print('[LLM][API] Request max_tokens: $effectiveMaxTokens');
    try {
      final Response<dynamic> res = await dio.post(
        url.toString(),
        data: payload,
        options: Options(
          headers: <String, String>{'Content-Type': 'application/json'},
          validateStatus: (int? code) => code != null && code < 500,
        ),
      );
      if (res.statusCode != null && res.statusCode! >= 400) {
        // ignore: avoid_print
        print(
          '[LLM][API] HTTP Error ${res.statusCode}: ${res.data ?? 'No body'}',
        );
        throw Exception('HTTP ${res.statusCode}: ${res.data ?? 'No body'}');
      }
      final dynamic data = res.data;
      if (data is Map<String, dynamic>) {
        final List<dynamic>? choices = data['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final Map<String, dynamic>? firstChoice =
              choices.first as Map<String, dynamic>?;
          // Check finish_reason to detect truncation
          final String? finishReason = firstChoice?['finish_reason'] as String?;
          if (finishReason == 'length') {
            // ignore: avoid_print
            print(
              '[LLM][API] WARNING: Response was truncated due to max_tokens limit. '
              'Consider increasing maxTokens setting.',
            );
          }
          final dynamic messageObj = firstChoice?['message'];
          if (messageObj is Map<String, dynamic>) {
            final String? content = messageObj['content'] as String?;
            if (content != null) {
              // ignore: avoid_print
              print(
                '[LLM][API] Successfully received response (finish_reason: $finishReason, length: ${content.length})',
              );
              return content;
            }
          }
        }
      }
      // ignore: avoid_print
      print('[LLM][API] Invalid response format: $data');
      throw Exception('Invalid response from LLM server: $data');
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[LLM][API] DioException: ${e.type} - ${e.message}');
      // ignore: avoid_print
      print('[LLM][API] Request URL: ${e.requestOptions.uri}');
      // ignore: avoid_print
      print(
        '[LLM][API] Response: ${e.response?.statusCode} - ${e.response?.data}',
      );
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Connection timeout. Check if server is running at $baseUrl',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Connection refused. Is the server running at $baseUrl? '
          'Check firewall and network settings.',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server response timeout');
      }
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('[LLM][API] Unexpected error: $e');
      rethrow;
    }
  }

  Stream<String> sendConversationStream({
    required List<ChatMessage> messages,
    double? temperature,
    int? maxTokens,
  }) async* {
    final String fullUrl = '$baseUrl/v1/chat/completions';
    // ignore: avoid_print
    print('[LLM][API][Stream] Connecting to: $fullUrl');
    final Uri url = Uri.parse(fullUrl);
    if (!url.hasScheme || !url.hasAuthority) {
      throw Exception(
        'Invalid server URL: $baseUrl (must include scheme like http://)',
      );
    }
    final List<Map<String, String>> messageMaps = messages
        .map(
          (ChatMessage m) => <String, String>{
            'role': m.role.asOpenAiString(),
            'content': m.content,
          },
        )
        .toList();
    final int effectiveMaxTokens = maxTokens != null && maxTokens > 0
        ? maxTokens
        : 2048;
    final Map<String, Object> payload = <String, Object>{
      if (model != null) 'model': model!,
      'messages': messageMaps,
      'temperature': temperature ?? 0.7,
      'max_tokens': effectiveMaxTokens,
      'stream': true,
    };
    try {
      final Response<ResponseBody> res = await dio.post<ResponseBody>(
        url.toString(),
        data: payload,
        options: Options(
          headers: <String, String>{'Content-Type': 'application/json'},
          responseType: ResponseType.stream,
          validateStatus: (int? code) => code != null && code < 500,
        ),
      );
      if (res.statusCode != null && res.statusCode! >= 400) {
        // ignore: avoid_print
        print('[LLM][API][Stream] HTTP Error ${res.statusCode}');
        throw Exception('HTTP ${res.statusCode}');
      }
      final ResponseBody? responseBody = res.data;
      if (responseBody == null) {
        throw Exception('No response body');
      }
      String buffer = '';
      await for (final List<int> chunk in responseBody.stream) {
        buffer += utf8.decode(chunk);
        final List<String> lines = buffer.split('\n');
        buffer = lines.removeLast();
        for (final String line in lines) {
          if (line.trim().isEmpty) {
            continue;
          }
          final String? content = _parseSseLine(line);
          if (content != null) {
            yield content;
          }
        }
      }
      if (buffer.trim().isNotEmpty) {
        final String? content = _parseSseLine(buffer);
        if (content != null) {
          yield content;
        }
      }
    } on DioException catch (e) {
      // ignore: avoid_print
      print('[LLM][API][Stream] DioException: ${e.type} - ${e.message}');
      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Connection timeout. Check if server is running at $baseUrl',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Connection refused. Is the server running at $baseUrl? '
          'Check firewall and network settings.',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server response timeout');
      }
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('[LLM][API][Stream] Unexpected error: $e');
      rethrow;
    }
  }

  String? _parseSseLine(String line) {
    if (!line.startsWith('data: ')) {
      return null;
    }
    final String data = line.substring(6).trim();
    if (data == '[DONE]') {
      return null;
    }
    try {
      final Map<String, dynamic> json =
          jsonDecode(data) as Map<String, dynamic>;
      final List<dynamic>? choices = json['choices'] as List<dynamic>?;
      if (choices != null && choices.isNotEmpty) {
        final Map<String, dynamic>? firstChoice =
            choices.first as Map<String, dynamic>?;
        final Map<String, dynamic>? delta =
            firstChoice?['delta'] as Map<String, dynamic>?;
        final String? content = delta?['content'] as String?;
        return content;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[LLM][API][Stream] Error parsing SSE line: $e');
    }
    return null;
  }
}
