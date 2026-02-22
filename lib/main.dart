import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_service.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _isDark = false;

  void _toggleTheme() {
    setState(() {
      _isDark = !_isDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: ChatScreen(
        isDark: _isDark,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;

  const ChatScreen({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _apiService = ApiService();
  final _scrollController = ScrollController();

  // Model selection
  static const _models = <String, String>{
    'openai/gpt-5.2': 'GPT-5.2',
    'openai/gpt-5.1': 'GPT-5.1',
    'openai/gpt-4.1': 'GPT-4.1',
    'openai/o3': 'o3',
    'openai/gpt-4o-mini': 'GPT-4o Mini',
  };
  String _selectedModel = 'openai/gpt-4o-mini';

  // Pricing per 1M tokens: (input, output)
  static const _pricing = <String, (double, double)>{
    'openai/gpt-5.2': (2.50, 10.00),
    'openai/gpt-5.1': (2.00, 8.00),
    'openai/gpt-4.1': (2.00, 8.00),
    'openai/o3': (10.00, 40.00),
    'openai/gpt-4o-mini': (0.15, 0.60),
  };

  final _stopwatch = Stopwatch();

  // Request Settings
  bool _settingsEnabled = false;
  final _systemPromptController = TextEditingController();
  final _maxTokensController = TextEditingController(text: '1024');
  final _stopSequenceController = TextEditingController();
  double _temperature = 0.7;

  bool _isStreaming = false;
  String _result = '';
  String? _error;
  StreamSubscription<String>? _streamSubscription;

  Future<void> _sendRequest() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isStreaming = true;
      _result = '';
      _error = null;
    });

    _stopwatch.reset();
    _stopwatch.start();

    try {
      final stream = _apiService.sendMessageStream(
        text,
        model: _selectedModel,
        systemPrompt:
            _settingsEnabled ? _systemPromptController.text.trim() : null,
        maxTokens: _settingsEnabled
            ? int.tryParse(_maxTokensController.text.trim())
            : null,
        stopSequence:
            _settingsEnabled ? _stopSequenceController.text.trim() : null,
        temperature: _settingsEnabled ? _temperature : null,
      );

      _streamSubscription = stream.listen(
        (delta) {
          setState(() {
            _result += delta;
          });
          _scrollToBottom();
        },
        onError: (error) {
          _stopwatch.stop();
          setState(() {
            _error = error.toString();
            _isStreaming = false;
          });
        },
        onDone: () {
          _stopwatch.stop();
          setState(() {
            _isStreaming = false;
          });
        },
      );
    } catch (e) {
      _stopwatch.stop();
      setState(() {
        _error = e.toString();
        _isStreaming = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 50),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _cancelStream() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _apiService.cancelStream();
    setState(() {
      _isStreaming = false;
    });
  }

  void _reset() {
    _cancelStream();
    setState(() {
      _result = '';
      _error = null;
    });
  }

  bool get _hasResponse => _result.isNotEmpty || _error != null || _isStreaming;

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _controller.dispose();
    _systemPromptController.dispose();
    _maxTokensController.dispose();
    _stopSequenceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            _hasResponse
                ? _buildResultScreen()
                : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildInput(),
                  ),
                ),
              ),
            if (!_hasResponse)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: widget.onToggleTheme,
                  icon: Icon(
                    widget.isDark ? Icons.light_mode : Icons.dark_mode,
                  ),
                  tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedModel,
            decoration: InputDecoration(
              labelText: 'Model',
              prefixIcon: const Icon(Icons.smart_toy_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
            borderRadius: BorderRadius.circular(12),
            items: _models.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedModel = value);
              }
            },
          ),
          const SizedBox(height: 24),
          _buildRequestSettings(),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: null,
            minLines: 3,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'Your request...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sendRequest,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Request Settings',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Switch(
                  value: _settingsEnabled,
                  onChanged: (value) {
                    setState(() {
                      _settingsEnabled = value;
                    });
                  },
                ),
              ],
            ),
            if (_settingsEnabled) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _systemPromptController,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  labelText: 'System Prompt',
                  hintText: 'Enter system instructions...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _maxTokensController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Tokens',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stopSequenceController,
                decoration: const InputDecoration(
                  labelText: 'Stop Sequence',
                  hintText: 'Enter stop sequence...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Temperature: ${_temperature.toStringAsFixed(1)}'),
                  Expanded(
                    child: Slider(
                      value: _temperature,
                      min: 0.0,
                      max: 2.0,
                      divisions: 20,
                      label: _temperature.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _temperature = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultScreen() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isStreaming)
                TextButton.icon(
                  onPressed: _cancelStream,
                  icon: const Icon(Icons.stop, size: 18),
                  label: const Text('Stop'),
                ),
              IconButton(
                onPressed: _reset,
                icon: const Icon(Icons.close),
                tooltip: 'Close',
              ),
              IconButton(
                onPressed: widget.onToggleTheme,
                icon: Icon(
                  widget.isDark ? Icons.light_mode : Icons.dark_mode,
                ),
                tooltip: widget.isDark ? 'Light mode' : 'Dark mode',
              ),
            ],
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildResponsePanel()),
                const SizedBox(width: 16),
                Expanded(child: _buildRequestLogPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsePanel() {
    return SingleChildScrollView(
      controller: _scrollController,
      child: SizedBox(
        width: double.infinity,
        child: _error != null
            ? Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SelectableText(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              )
            : Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        _result,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (_isStreaming) ...[
                        const SizedBox(height: 8),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildRequestLogPanel() {
    final log = _apiService.lastRequestLog;
    if (log == null) return const SizedBox.shrink();

    const encoder = JsonEncoder.withIndent('  ');
    final headersText = encoder.convert(log.maskedHeaders);
    final bodyText = encoder.convert(log.body);

    return SingleChildScrollView(
      child: SizedBox(
        width: double.infinity,
        child: Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Request Log',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _logSection('Method', log.method),
                _logSection('URL', log.url),
                _logBlock('Headers', headersText),
                _logBlock('Body', bodyText),
                const Divider(height: 24),
                Text(
                  'Response Info',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _buildResponseInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponseInfo() {
    final elapsed = _stopwatch.elapsed;
    final timeStr = _isStreaming
        ? 'streaming...'
        : '${(elapsed.inMilliseconds / 1000).toStringAsFixed(2)}s';

    final resLog = _apiService.lastResponseLog;

    if (resLog == null && !_isStreaming) {
      return _logSection('Time', timeStr);
    }

    final prompt = resLog?.promptTokens ?? 0;
    final completion = resLog?.completionTokens ?? 0;
    final total = resLog?.totalTokens ?? 0;

    final prices = _pricing[_selectedModel];
    String costStr = '-';
    if (resLog != null && prices != null) {
      final cost =
          (prompt * prices.$1 + completion * prices.$2) / 1000000;
      costStr = '\$${cost.toStringAsFixed(6)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _logSection('Time', timeStr),
        _logSection('Prompt tokens', '$prompt'),
        _logSection('Completion tokens', '$completion'),
        _logSection('Total tokens', '$total'),
        _logSection('Est. cost', costStr),
      ],
    );
  }

  Widget _logSection(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
      ),
    );
  }

  Widget _logBlock(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
          ),
        ],
      ),
    );
  }
}
