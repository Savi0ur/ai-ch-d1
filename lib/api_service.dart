import 'dart:async';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ResponseLog {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const ResponseLog({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
}

class RequestLog {
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  const RequestLog({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
  });

  Map<String, String> get maskedHeaders {
    return headers.map((key, value) {
      if (key.toLowerCase() == 'authorization') {
        return MapEntry(key, 'Bearer ${'*' * 16}');
      }
      return MapEntry(key, value);
    });
  }
}

class ApiService {
  static const String _baseUrl = 'https://openai.api.proxyapi.ru/v1';
  static String get _apiKey => dotenv.env['API_KEY'] ?? '';

  http.Client? _activeClient;
  RequestLog? lastRequestLog;
  ResponseLog? lastResponseLog;

  /// Cancel the current streaming request.
  void cancelStream() {
    _activeClient?.close();
    _activeClient = null;
  }

  /// Sends a message and returns a stream of content deltas (tokens).
  Stream<String> sendMessageStream(
    String message, {
    required String model,
    String? systemPrompt,
    int? maxTokens,
    String? stopSequence,
    double? temperature,
  }) async* {
    final url = Uri.parse('$_baseUrl/chat/completions');

    final messages = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      messages.add({'role': 'system', 'content': systemPrompt});
    }
    messages.add({'role': 'user', 'content': message});

    final body = <String, dynamic>{
      'model': model,
      'messages': messages,
      'stream': true,
      'stream_options': {'include_usage': true},
    };

    if (maxTokens != null) {
      body['max_tokens'] = maxTokens;
    }

    if (stopSequence != null && stopSequence.isNotEmpty) {
      body['stop'] = [stopSequence];
    }

    if (temperature != null) {
      body['temperature'] = temperature;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    lastRequestLog = RequestLog(
      method: 'POST',
      url: url.toString(),
      headers: headers,
      body: body,
    );
    lastResponseLog = null;

    final client = http.Client();
    _activeClient = client;

    try {
      final request = http.Request('POST', url);
      request.headers.addAll(headers);
      request.body = jsonEncode(body);

      final response = await client.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception('API Error: ${response.statusCode} $errorBody');
      }

      // Buffer for incomplete SSE lines
      String buffer = '';

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        // Keep the last potentially incomplete line in the buffer
        buffer = lines.removeLast();

        for (final line in lines) {
          final trimmed = line.trim();
          if (trimmed.isEmpty) continue;
          if (!trimmed.startsWith('data: ')) continue;

          final data = trimmed.substring(6);
          if (data == '[DONE]') return;

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final usage = json['usage'] as Map<String, dynamic>?;
            if (usage != null) {
              lastResponseLog = ResponseLog(
                promptTokens: usage['prompt_tokens'] as int? ?? 0,
                completionTokens: usage['completion_tokens'] as int? ?? 0,
                totalTokens: usage['total_tokens'] as int? ?? 0,
              );
            }
            final choices = json['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta =
                  (choices[0] as Map<String, dynamic>)['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null) {
                yield content;
              }
            }
          } catch (_) {
            // Skip malformed JSON chunks
          }
        }
      }
    } finally {
      _activeClient = null;
      client.close();
    }
  }
}
