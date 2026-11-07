import 'package:agentport/features/providers/provider_presets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderPreset', () {
    test('ids are unique', () {
      final ids = ProviderPreset.all.map((preset) => preset.id).toList();

      expect(ids.toSet(), hasLength(ids.length));
      expect(ids, containsAll(['deepseek', 'openai', 'custom']));
    });

    test('byId returns known presets and null otherwise', () {
      expect(ProviderPreset.byId('deepseek'), same(ProviderPreset.deepSeek));
      expect(ProviderPreset.byId('gemini'), same(ProviderPreset.gemini));
      expect(ProviderPreset.byId(null), isNull);
      expect(ProviderPreset.byId('unknown'), isNull);
    });

    test('all presets have example values', () {
      for (final preset in ProviderPreset.all) {
        expect(preset.label, isNotEmpty);
        expect(preset.description, isNotEmpty);
        expect(preset.baseUrl, startsWith('https://'));
        expect(preset.model, isNotEmpty);
      }
    });
  });
}
