/// The kind of API behind a provider.
///
/// Both kinds speak the OpenAI chat-completions protocol; the distinction only
/// affects presets and UI copy.
enum AiProviderType {
  deepSeek('deepseek'),
  openAiCompatible('openai');

  const AiProviderType(this.storageValue);

  final String storageValue;

  static AiProviderType fromStorage(String value) {
    return switch (value) {
      'deepseek' => AiProviderType.deepSeek,
      _ => AiProviderType.openAiCompatible,
    };
  }
}

/// A configured AI provider. The API key is not part of this model: only the
/// secure-storage reference is kept here.
class AiProvider {
  const AiProvider({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.model,
    required this.apiKeyRef,
  });

  final String id;
  final String name;
  final AiProviderType type;
  final String baseUrl;
  final String model;
  final String apiKeyRef;

  bool get isDeepSeek => type == AiProviderType.deepSeek;
}

/// Preset values used when creating a new provider.
abstract final class ProviderPresets {
  static const deepSeekName = 'DeepSeek';
  static const deepSeekBaseUrl = 'https://api.deepseek.com';
  static const deepSeekModel = 'deepseek-chat';

  static const customName = 'Custom provider';
  static const customBaseUrl = 'https://api.openai.com/v1';
  static const customModel = 'gpt-4o-mini';
}
