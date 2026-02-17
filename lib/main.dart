import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'api_service.dart';

Future<void> main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'gpt 4o mini',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _apiService = ApiService();
  final _scrollController = ScrollController();

  // Request Settings
  bool _settingsEnabled = false;
  final _systemPromptController = TextEditingController();
  final _maxTokensController = TextEditingController(text: '1024');
  final _stopSequenceController = TextEditingController();

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

    try {
      final stream = _apiService.sendMessageStream(
        text,
        systemPrompt:
            _settingsEnabled ? _systemPromptController.text.trim() : null,
        maxTokens: _settingsEnabled
            ? int.tryParse(_maxTokensController.text.trim())
            : null,
        stopSequence:
            _settingsEnabled ? _stopSequenceController.text.trim() : null,
      );

      _streamSubscription = stream.listen(
        (delta) {
          setState(() {
            _result += delta;
          });
          _scrollToBottom();
        },
        onError: (error) {
          setState(() {
            _error = error.toString();
            _isStreaming = false;
          });
        },
        onDone: () {
          setState(() {
            _isStreaming = false;
          });
        },
      );
    } catch (e) {
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
      _controller.clear();
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _hasResponse ? _buildResult() : _buildInput(),
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'gpt 4o mini',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 24),
          _buildRequestSettings(),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            maxLines: 4,
            minLines: 1,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendRequest(),
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    return Column(
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
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
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
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
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
          ),
        ),
      ],
    );
  }
}
