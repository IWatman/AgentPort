import 'package:flutter/material.dart';

import '../../domain/entities/ai_provider.dart';

/// A ready-made configuration for a supported OpenAI-compatible provider.
///
/// Preset values are examples: users can edit every field after picking one.
class ProviderPreset {
  const ProviderPreset({
    required this.id,
    required this.label,
    required this.description,
    required this.baseUrl,
    required this.model,
    required this.type,
    required this.icon,
  });

  final String id;
  final String label;
  final String description;
  final String baseUrl;
  final String model;
  final AiProviderType type;
  final IconData icon;

  static const deepSeek = ProviderPreset(
    id: 'deepseek',
    label: 'DeepSeek',
    description: 'Reasoning and coding models at low cost.',
    baseUrl: 'https://api.deepseek.com',
    model: 'deepseek-chat',
    type: AiProviderType.deepSeek,
    icon: Icons.auto_awesome_rounded,
  );

  static const openAi = ProviderPreset(
    id: 'openai',
    label: 'OpenAI',
    description: 'GPT models from the official OpenAI API.',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini',
    type: AiProviderType.openAiCompatible,
    icon: Icons.blur_on_rounded,
  );

  static const openRouter = ProviderPreset(
    id: 'openrouter',
    label: 'OpenRouter',
    description: 'One key for many models and providers.',
    baseUrl: 'https://openrouter.ai/api/v1',
    model: 'openai/gpt-4o-mini',
    type: AiProviderType.openAiCompatible,
    icon: Icons.alt_route_rounded,
  );

  static const groq = ProviderPreset(
    id: 'groq',
    label: 'Groq',
    description: 'Very fast inference on open models.',
    baseUrl: 'https://api.groq.com/openai/v1',
    model: 'llama-3.3-70b-versatile',
    type: AiProviderType.openAiCompatible,
    icon: Icons.bolt_rounded,
  );

  static const mistral = ProviderPreset(
    id: 'mistral',
    label: 'Mistral',
    description: 'European models from Mistral AI.',
    baseUrl: 'https://api.mistral.ai/v1',
    model: 'mistral-large-latest',
    type: AiProviderType.openAiCompatible,
    icon: Icons.air_rounded,
  );

  static const together = ProviderPreset(
    id: 'together',
    label: 'Together AI',
    description: "Open-source models on Together's cloud.",
    baseUrl: 'https://api.together.xyz/v1',
    model: 'meta-llama/Llama-3.3-70B-Instruct-Turbo',
    type: AiProviderType.openAiCompatible,
    icon: Icons.groups_rounded,
  );

  static const xAi = ProviderPreset(
    id: 'xai',
    label: 'xAI',
    description: 'Grok models from xAI.',
    baseUrl: 'https://api.x.ai/v1',
    model: 'grok-2-latest',
    type: AiProviderType.openAiCompatible,
    icon: Icons.rocket_launch_rounded,
  );

  static const gemini = ProviderPreset(
    id: 'gemini',
    label: 'Google Gemini',
    description: 'Gemini models through the OpenAI-compatible endpoint.',
    baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    model: 'gemini-2.5-flash',
    type: AiProviderType.openAiCompatible,
    icon: Icons.stars_rounded,
  );

  static const custom = ProviderPreset(
    id: 'custom',
    label: 'Custom',
    description: 'Any other OpenAI-compatible endpoint.',
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini',
    type: AiProviderType.openAiCompatible,
    icon: Icons.tune_rounded,
  );

  static const all = <ProviderPreset>[
    deepSeek,
    openAi,
    openRouter,
    groq,
    mistral,
    together,
    xAi,
    gemini,
    custom,
  ];

  /// Returns the preset with [id], or `null` when [id] is missing or unknown.
  static ProviderPreset? byId(String? id) {
    if (id == null) {
      return null;
    }
    for (final preset in all) {
      if (preset.id == id) {
        return preset;
      }
    }
    return null;
  }
}
