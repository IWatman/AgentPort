import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/generated/app_localizations.dart';
import '../shared/empty_state.dart';
import 'providers_controller.dart';

class ProvidersScreen extends ConsumerWidget {
  const ProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final providers = ref.watch(providersControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.providersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/providers/new'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.providerAdd),
      ),
      body: providers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l10n.chatErrorUnknown,
          body: error.toString(),
          action: OutlinedButton(
            onPressed: () =>
                ref.read(providersControllerProvider.notifier).reload(),
            child: Text(l10n.commonRetry),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.key_rounded,
              title: l10n.providersEmptyTitle,
              body: l10n.providersEmptyBody,
              action: FilledButton.icon(
                onPressed: () => context.push('/providers/new'),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.providerAdd),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: items.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Text(
                    l10n.providersSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              final provider = items[index - 1];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHigh,
                    child: Icon(
                      provider.isDeepSeek
                          ? Icons.auto_awesome_rounded
                          : Icons.cloud_queue_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(provider.name),
                  subtitle: Text(
                    '${provider.model} · ${_hostLabel(provider.baseUrl)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/providers/${provider.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _hostLabel(String baseUrl) {
    final parsed = Uri.tryParse(baseUrl.trim());
    return parsed?.host.isNotEmpty == true ? parsed!.host : baseUrl;
  }
}
