import 'package:agentport/features/providers/model_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DeepSeek exposes current model names and labels legacy IDs', () {
    expect(ProviderModelCatalog.deepSeekModels.map((option) => option.id), [
      'deepseek-flash',
      'deepseek-v4-pro',
    ]);
    expect(
      ProviderModelCatalog.labelFor(
        'https://api.deepseek.com',
        'deepseek-flash',
      ),
      'DeepSeek V4.1 Flash',
    );
    expect(
      ProviderModelCatalog.labelFor(
        'https://api.deepseek.com',
        'deepseek-reasoner',
      ),
      'DeepSeek Reasoner (legacy)',
    );
  });

  test('unknown models keep their API id', () {
    expect(
      ProviderModelCatalog.labelFor('https://example.com', 'my-model'),
      'my-model',
    );
    expect(ProviderModelCatalog.forBaseUrl('https://example.com'), isEmpty);
  });
}
