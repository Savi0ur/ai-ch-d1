import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RequestLogPanel extends StatelessWidget {
  final ApiService apiService;
  final Stopwatch stopwatch;
  final bool isStreaming;
  final String selectedModel;

  // Pricing per 1M tokens: (input, output)
  static const _pricing = <String, (double, double)>{
    'openai/gpt-5.2': (2.50, 10.00),
    'openai/gpt-5.1': (2.00, 8.00),
    'openai/gpt-4.1': (2.00, 8.00),
    'openai/o3': (10.00, 40.00),
    'openai/gpt-4o-mini': (0.15, 0.60),
  };

  const RequestLogPanel({
    super.key,
    required this.apiService,
    required this.stopwatch,
    required this.isStreaming,
    required this.selectedModel,
  });

  @override
  Widget build(BuildContext context) {
    final log = apiService.lastRequestLog;
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
                _logSection(context, 'Method', log.method),
                _logSection(context, 'URL', log.url),
                _logBlock(context, 'Headers', headersText),
                _logBlock(context, 'Body', bodyText),
                const Divider(height: 24),
                Text(
                  'Response Info',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                _buildResponseInfo(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponseInfo(BuildContext context) {
    final elapsed = stopwatch.elapsed;
    final timeStr = isStreaming
        ? 'streaming...'
        : '${(elapsed.inMilliseconds / 1000).toStringAsFixed(2)}s';

    final resLog = apiService.lastResponseLog;

    if (resLog == null && !isStreaming) {
      return _logSection(context, 'Time', timeStr);
    }

    final prompt = resLog?.promptTokens ?? 0;
    final completion = resLog?.completionTokens ?? 0;
    final total = resLog?.totalTokens ?? 0;

    final prices = _pricing[selectedModel];
    String costStr = '-';
    if (resLog != null && prices != null) {
      final cost =
          (prompt * prices.$1 + completion * prices.$2) / 1000000;
      costStr = '\$${cost.toStringAsFixed(6)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _logSection(context, 'Time', timeStr),
        _logSection(context, 'Prompt tokens', '$prompt'),
        _logSection(context, 'Completion tokens', '$completion'),
        _logSection(context, 'Total tokens', '$total'),
        _logSection(context, 'Est. cost', costStr),
      ],
    );
  }

  Widget _logSection(BuildContext context, String label, String value) {
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

  Widget _logBlock(BuildContext context, String label, String value) {
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
