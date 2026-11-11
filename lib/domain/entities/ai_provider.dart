import 'provider_oauth.dart';

/// The kind of API behind an API-key provider.
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
    this.authMethod = ProviderAuthMethod.apiKey,
  });

  final String id;
  final String name;
  final AiProviderType type;
  final String baseUrl;
  final String model;
  final String apiKeyRef;
  final ProviderAuthMethod authMethod;

  bool get usesAccount => authMethod != ProviderAuthMethod.apiKey;
  bool get usesResponses => authMethod == ProviderAuthMethod.chatGpt;

  bool get isDeepSeek => type == AiProviderType.deepSeek;
}
