import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';

class McpTool {
  final String name;
  final String? description;
  final Map<String, dynamic>? inputSchema;
  final String serverName;

  const McpTool({
    required this.name,
    this.description,
    this.inputSchema,
    required this.serverName,
  });

  Map<String, dynamic> toOpenAiTool() => {
        'type': 'function',
        'function': {
          'name': name,
          if (description != null) 'description': description,
          'parameters': inputSchema ?? {'type': 'object', 'properties': {}},
        },
      };
}

class McpServer {
  final String name;
  final String url;
  String? _sessionId;
  int _nextId = 1;
  List<McpTool> tools = [];
  bool isConnected = false;
  bool isConnecting = false;
  String? error;

  McpServer({required this.name, required this.url});

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
        if (_sessionId != null) 'Mcp-Session-Id': _sessionId!,
      };

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse(url),
      headers: _headers(),
      body: jsonEncode(body),
    );

    final sid = response.headers['mcp-session-id'];
    if (sid != null) _sessionId = sid;

    if (response.statusCode == 202) return {};

    if (response.statusCode == 404 && _sessionId != null) {
      _sessionId = null;
      isConnected = false;
      throw Exception('MCP session expired');
    }

    if (response.statusCode != 200) {
      throw Exception('MCP Error: ${response.statusCode} ${response.body}');
    }

    final contentType = response.headers['content-type'] ?? '';
    if (contentType.contains('text/event-stream')) {
      return _parseSSE(response.body);
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _parseSSE(String body) {
    Map<String, dynamic>? last;
    for (final line in body.split('\n')) {
      if (line.startsWith('data: ')) {
        try {
          last = jsonDecode(line.substring(6)) as Map<String, dynamic>;
        } catch (_) {}
      }
    }
    return last ?? {};
  }

  Future<void> connect() async {
    isConnecting = true;
    error = null;
    try {
      final result = await _post({
        'jsonrpc': '2.0',
        'id': _nextId++,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2025-03-26',
          'capabilities': {},
          'clientInfo': {'name': 'FlutterAIChat', 'version': '1.0.0'},
        },
      });

      final serverResult = result['result'] as Map<String, dynamic>?;
      if (serverResult == null && result['error'] != null) {
        throw Exception(
            'Init failed: ${result['error']['message'] ?? result['error']}');
      }

      await _post({
        'jsonrpc': '2.0',
        'method': 'notifications/initialized',
      });

      isConnected = true;
      await _listTools();
    } catch (e) {
      error = e.toString();
      isConnected = false;
      _sessionId = null;
      rethrow;
    } finally {
      isConnecting = false;
    }
  }

  Future<void> _listTools() async {
    tools.clear();
    String? cursor;

    do {
      final params = <String, dynamic>{};
      if (cursor != null) params['cursor'] = cursor;

      final result = await _post({
        'jsonrpc': '2.0',
        'id': _nextId++,
        'method': 'tools/list',
        'params': params,
      });

      final data = result['result'] as Map<String, dynamic>?;
      if (data == null) break;

      final toolsList = data['tools'] as List<dynamic>? ?? [];
      for (final t in toolsList) {
        final toolMap = t as Map<String, dynamic>;
        tools.add(McpTool(
          name: toolMap['name'] as String,
          description: toolMap['description'] as String?,
          inputSchema: toolMap['inputSchema'] as Map<String, dynamic>?,
          serverName: name,
        ));
      }

      cursor = data['nextCursor'] as String?;
    } while (cursor != null);
  }

  Future<String> callTool(
      String toolName, Map<String, dynamic> arguments) async {
    final result = await _post({
      'jsonrpc': '2.0',
      'id': _nextId++,
      'method': 'tools/call',
      'params': {
        'name': toolName,
        'arguments': arguments,
      },
    });

    if (result['error'] != null) {
      final err = result['error'] as Map<String, dynamic>;
      return 'Error: ${err['message'] ?? err}';
    }

    final data = result['result'] as Map<String, dynamic>?;
    if (data == null) return 'No result';

    final content = data['content'] as List<dynamic>? ?? [];
    final parts = <String>[];
    for (final item in content) {
      final map = item as Map<String, dynamic>;
      if (map['type'] == 'text') {
        parts.add(map['text'] as String);
      } else if (map['type'] == 'image') {
        parts.add('[Image: ${map['mimeType']}]');
      }
    }

    return parts.join('\n');
  }

  Future<void> disconnect() async {
    if (_sessionId != null) {
      try {
        await http.delete(
          Uri.parse(url),
          headers: {'Mcp-Session-Id': _sessionId!},
        );
      } catch (_) {}
    }
    _sessionId = null;
    isConnected = false;
    tools.clear();
  }
}

/// MCP-сервис с захардкоженным VkusVill сервером.
/// Поддерживает включение/выключение отдельных инструментов.
class McpService {
  static const _disabledToolsKey = 'mcp_disabled_tools';

  final McpServer vkusvill = McpServer(
    name: 'vkusvill',
    url: 'https://mcp001.vkusvill.ru/mcp',
  );

  /// Множество отключённых инструментов (по имени).
  final Set<String> _disabledTools = {};

  McpService() {
    _loadDisabledTools();
  }

  bool get isConnected => vkusvill.isConnected;
  bool get isConnecting => vkusvill.isConnecting;
  String? get error => vkusvill.error;
  List<McpTool> get allTools => vkusvill.tools;

  bool get hasEnabledTools =>
      vkusvill.isConnected &&
      vkusvill.tools.any((t) => !_disabledTools.contains(t.name));

  List<McpTool> get enabledTools => vkusvill.tools
      .where((t) => !_disabledTools.contains(t.name))
      .toList();

  bool isToolEnabled(String toolName) => !_disabledTools.contains(toolName);

  void setToolEnabled(String toolName, bool enabled) {
    if (enabled) {
      _disabledTools.remove(toolName);
    } else {
      _disabledTools.add(toolName);
    }
    _saveDisabledTools();
  }

  List<Map<String, dynamic>> getOpenAiTools() =>
      enabledTools.map((t) => t.toOpenAiTool()).toList();

  Future<void> connect() async => vkusvill.connect();
  Future<void> disconnect() async => vkusvill.disconnect();

  Future<String> callTool(
      String toolName, Map<String, dynamic> arguments) async {
    if (!vkusvill.isConnected) {
      return 'Error: VkusVill MCP server not connected';
    }
    return vkusvill.callTool(toolName, arguments);
  }

  void _loadDisabledTools() {
    try {
      final box = Hive.box('settings');
      final json = box.get(_disabledToolsKey) as String?;
      if (json == null) return;
      final list = jsonDecode(json) as List<dynamic>;
      _disabledTools.addAll(list.cast<String>());
    } catch (_) {}
  }

  void _saveDisabledTools() {
    try {
      final box = Hive.box('settings');
      box.put(_disabledToolsKey, jsonEncode(_disabledTools.toList()));
    } catch (_) {}
  }
}
