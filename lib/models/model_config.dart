class ModelConfig {
  final String id;
  final String label;
  final double inputPrice; // per 1M tokens
  final double outputPrice; // per 1M tokens

  const ModelConfig({
    required this.id,
    required this.label,
    required this.inputPrice,
    required this.outputPrice,
  });

  static const all = <ModelConfig>[
    ModelConfig(id: 'openai/gpt-5.2', label: 'GPT-5.2', inputPrice: 2.50, outputPrice: 10.00),
    ModelConfig(id: 'openai/gpt-5.1', label: 'GPT-5.1', inputPrice: 2.00, outputPrice: 8.00),
    ModelConfig(id: 'openai/gpt-4.1', label: 'GPT-4.1', inputPrice: 2.00, outputPrice: 8.00),
    ModelConfig(id: 'openai/o3', label: 'o3', inputPrice: 10.00, outputPrice: 40.00),
    ModelConfig(id: 'openai/gpt-4o-mini', label: 'GPT-4o Mini', inputPrice: 0.15, outputPrice: 0.60),
  ];

  static Map<String, String> get dropdownItems =>
      {for (final m in all) m.id: m.label};

  static (double, double)? getPricing(String id) {
    final match = all.where((m) => m.id == id);
    if (match.isEmpty) return null;
    return (match.first.inputPrice, match.first.outputPrice);
  }
}
