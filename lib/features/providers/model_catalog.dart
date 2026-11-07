/// Human-readable names for known provider models.
///
/// The API always receives [ModelOption.id]; the UI shows [ModelOption.label].
class ModelOption {
  const ModelOption({required this.id, required this.label});

  final String id;
  final String label;
}

abstract final class ProviderModelCatalog {
  static const deepSeekModels = <ModelOption>[
    ModelOption(id: 'deepseek-flash', label: 'DeepSeek V4.1 Flash'),
    ModelOption(id: 'deepseek-v4-pro', label: 'DeepSeek V4 Pro'),
  ];

  static const openAiModels = <ModelOption>[
    ModelOption(id: 'gpt-4o-mini', label: 'GPT-4o mini'),
    ModelOption(id: 'gpt-4o', label: 'GPT-4o'),
    ModelOption(id: 'gpt-4.1-mini', label: 'GPT-4.1 mini'),
  ];

  static const openRouterModels = <ModelOption>[
    ModelOption(id: 'openai/gpt-4o-mini', label: 'GPT-4o mini'),
    ModelOption(id: 'anthropic/claude-3.5-sonnet', label: 'Claude 3.5 Sonnet'),
    ModelOption(id: 'google/gemini-2.5-flash', label: 'Gemini 2.5 Flash'),
  ];

  static const groqModels = <ModelOption>[
    ModelOption(id: 'llama-3.3-70b-versatile', label: 'Llama 3.3 70B'),
    ModelOption(id: 'llama-3.1-8b-instant', label: 'Llama 3.1 8B'),
  ];

  static const mistralModels = <ModelOption>[
    ModelOption(id: 'mistral-large-latest', label: 'Mistral Large'),
    ModelOption(id: 'mistral-small-latest', label: 'Mistral Small'),
  ];

  static const togetherModels = <ModelOption>[
    ModelOption(
      id: 'meta-llama/Llama-3.3-70B-Instruct-Turbo',
      label: 'Llama 3.3 70B Turbo',
    ),
  ];

  static const xAiModels = <ModelOption>[
    ModelOption(id: 'grok-2-latest', label: 'Grok 2'),
  ];

  static const geminiModels = <ModelOption>[
    ModelOption(id: 'gemini-2.5-flash', label: 'Gemini 2.5 Flash'),
    ModelOption(id: 'gemini-2.5-pro', label: 'Gemini 2.5 Pro'),
  ];

  /// Legacy DeepSeek aliases still accepted by the API. They are labeled in
  /// the UI but not offered as new choices.
  static const _legacyDeepSeekLabels = <String, String>{
    'deepseek-chat': 'DeepSeek Chat (legacy)',
    'deepseek-reasoner': 'DeepSeek Reasoner (legacy)',
  };

  static List<ModelOption> forBaseUrl(String baseUrl) {
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
    return switch (host) {
      'api.deepseek.com' => deepSeekModels,
      'api.openai.com' => openAiModels,
      'openrouter.ai' => openRouterModels,
      'api.groq.com' => groqModels,
      'api.mistral.ai' => mistralModels,
      'api.together.xyz' => togetherModels,
      'api.x.ai' => xAiModels,
      'generativelanguage.googleapis.com' => geminiModels,
      _ => const [],
    };
  }

  static ModelOption? find(String baseUrl, String model) {
    for (final option in forBaseUrl(baseUrl)) {
      if (option.id == model) {
        return option;
      }
    }
    return null;
  }

  static String labelFor(String baseUrl, String model) {
    final option = find(baseUrl, model);
    if (option != null) {
      return option.label;
    }
    final host = Uri.tryParse(baseUrl)?.host.toLowerCase() ?? '';
    if (host == 'api.deepseek.com') {
      return _legacyDeepSeekLabels[model] ?? model;
    }
    return model;
  }
}
