import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/provider_repository.dart';
import '../../domain/entities/ai_provider.dart';

final providersControllerProvider =
    AsyncNotifierProvider<ProvidersController, List<AiProvider>>(
      ProvidersController.new,
    );

class ProvidersController extends AsyncNotifier<List<AiProvider>> {
  @override
  Future<List<AiProvider>> build() {
    return ref.watch(providerRepositoryProvider).list();
  }

  Future<AiProvider> create({
    required String name,
    required AiProviderType type,
    required String baseUrl,
    required String model,
    required String apiKey,
  }) async {
    final provider = await ref
        .read(providerRepositoryProvider)
        .create(
          name: name,
          type: type,
          baseUrl: baseUrl,
          model: model,
          apiKey: apiKey,
        );
    state = AsyncData([...?state.value, provider]);
    return provider;
  }

  Future<void> save({
    required AiProvider provider,
    required String name,
    required AiProviderType type,
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    await ref
        .read(providerRepositoryProvider)
        .update(
          provider: provider,
          name: name,
          type: type,
          baseUrl: baseUrl,
          model: model,
          apiKey: apiKey,
        );
    final current = state.value ?? const <AiProvider>[];
    state = AsyncData([
      for (final item in current)
        if (item.id == provider.id)
          AiProvider(
            id: provider.id,
            name: name,
            type: type,
            baseUrl: baseUrl,
            model: model,
            apiKeyRef: provider.apiKeyRef,
          )
        else
          item,
    ]);
  }

  Future<void> delete(AiProvider provider) async {
    await ref.read(providerRepositoryProvider).delete(provider);
    final current = state.value ?? const <AiProvider>[];
    state = AsyncData([
      for (final item in current)
        if (item.id != provider.id) item,
    ]);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(providerRepositoryProvider).list(),
    );
  }
}
