import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/opencode/opencode_client.dart';
import '../../data/repositories/opencode_repository.dart';
import '../../domain/entities/opencode.dart';

typedef OpenCodeSessionInsightsKey = ({
  String connectionId,
  String sessionId,
  String? directory,
  String? modelId,
  String? modelProviderId,
});

class OpenCodeSessionInsights {
  const OpenCodeSessionInsights({
    this.session,
    this.contextMessageCount = 0,
    this.modelName,
    this.contextLimit,
    this.totalCost,
    this.subagentCount = 0,
  });

  final OpenCodeSession? session;
  final int contextMessageCount;
  final String? modelName;
  final int? contextLimit;
  final double? totalCost;
  final int subagentCount;
}

/// Loads the session context and the model limit shown in the context sheet.
final openCodeSessionInsightsProvider = FutureProvider.autoDispose
    .family<OpenCodeSessionInsights, OpenCodeSessionInsightsKey>((
      ref,
      key,
    ) async {
      final repository = ref.watch(openCodeRepositoryProvider);
      final connection = await repository.connection(key.connectionId);
      if (connection == null) {
        throw const OpenCodeFailure(
          OpenCodeFailureKind.invalidPayload,
          detail: 'The OpenCode connection no longer exists.',
        );
      }
      final client = await repository.clientFor(connection);

      OpenCodeSession? session;
      try {
        session = await client.session(key.sessionId);
      } catch (_) {
        // The caller falls back to the transcript session snapshot.
      }

      double? totalCost;
      var subagentCount = 0;
      try {
        final sessions = await client.sessions();
        final children = <String, List<OpenCodeSession>>{};
        for (final item in sessions) {
          final parent = item.parentId;
          if (parent == null || parent.isEmpty) {
            continue;
          }
          children.putIfAbsent(parent, () => []).add(item);
        }
        final visited = <String>{key.sessionId};
        double sum = session?.cost ?? 0;
        void addChildren(String parentId) {
          for (final child in children[parentId] ?? const <OpenCodeSession>[]) {
            if (!visited.add(child.id)) {
              continue;
            }
            sum += child.cost ?? 0;
            subagentCount++;
            addChildren(child.id);
          }
        }

        addChildren(key.sessionId);
        totalCost = sum;
      } catch (_) {
        // Subagent costs are optional.
      }

      OpenCodeSessionContext? context;
      try {
        context = await client.sessionContext(key.sessionId);
      } catch (_) {
        // Context is optional; the rest of the sheet still works.
      }

      OpenCodeModel? model;
      try {
        final models = await client.models(directory: key.directory);
        for (final candidate in models) {
          if (candidate.id == key.modelId &&
              candidate.providerId == key.modelProviderId) {
            model = candidate;
            break;
          }
        }
      } catch (_) {
        // The model list is optional; the context limit is omitted.
      }

      return OpenCodeSessionInsights(
        session: session,
        contextMessageCount: context?.messageCount ?? 0,
        modelName: model?.name,
        contextLimit: model?.contextLimit,
        totalCost: totalCost,
        subagentCount: subagentCount,
      );
    });

typedef OpenCodeExtensionKey = ({String connectionId, String? directory});

Future<OpenCodeClient> _clientFor(Ref ref, String connectionId) async {
  final repository = ref.watch(openCodeRepositoryProvider);
  final connection = await repository.connection(connectionId);
  if (connection == null) {
    throw const OpenCodeFailure(
      OpenCodeFailureKind.invalidPayload,
      detail: 'The OpenCode connection no longer exists.',
    );
  }
  return repository.clientFor(connection);
}

/// MCP servers configured on the OpenCode host at one directory.
final openCodeMcpServersProvider = FutureProvider.autoDispose
    .family<List<OpenCodeMcpServer>, OpenCodeExtensionKey>((ref, key) async {
      final client = await _clientFor(ref, key.connectionId);
      return client.mcpServers(directory: key.directory);
    });

/// Plugins loaded by the OpenCode host at one directory.
final openCodePluginsProvider = FutureProvider.autoDispose
    .family<List<OpenCodePlugin>, OpenCodeExtensionKey>((ref, key) async {
      final client = await _clientFor(ref, key.connectionId);
      return client.plugins(directory: key.directory);
    });

/// Skills exposed at one directory. This request can be large, so it is
/// loaded only when the extensions sheet opens.
final openCodeSkillsProvider = FutureProvider.autoDispose
    .family<List<OpenCodeSkill>, OpenCodeExtensionKey>((ref, key) async {
      final client = await _clientFor(ref, key.connectionId);
      return client.skills(directory: key.directory);
    });
