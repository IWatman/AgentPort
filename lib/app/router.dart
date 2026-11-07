import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/settings/settings_controller.dart';
import '../features/chat/chat_screen.dart';
import '../features/chats/chats_screen.dart';
import '../features/connections/connections_screen.dart';
import '../features/connections/mcp_server_screen.dart';
import '../features/marketplace/marketplace_screen.dart';
import '../features/marketplace/plugin_detail_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/providers/provider_editor_screen.dart';
import '../features/providers/providers_screen.dart';
import '../features/settings/about_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/home_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _chatsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'chats');
final _marketplaceNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'marketplace',
);
final _connectionsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'connections',
);
final _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: ref.read(settingsControllerProvider).onboardingComplete
        ? '/chats'
        : '/onboarding',
    redirect: (context, state) {
      final onboardingComplete = ref
          .read(settingsControllerProvider)
          .onboardingComplete;
      final atOnboarding = state.matchedLocation == '/onboarding';

      if (!onboardingComplete) {
        return atOnboarding ? null : '/onboarding';
      }
      if (atOnboarding) {
        return '/chats';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _chatsNavigatorKey,
            routes: [
              GoRoute(
                path: '/chats',
                name: 'chats',
                builder: (context, state) => const ChatsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _marketplaceNavigatorKey,
            routes: [
              GoRoute(
                path: '/marketplace',
                name: 'marketplace',
                builder: (context, state) => const MarketplaceScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _connectionsNavigatorKey,
            routes: [
              GoRoute(
                path: '/connections',
                name: 'connections',
                builder: (context, state) => const ConnectionsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/chats/:id',
        name: 'chat',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ChatScreen(conversationId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/connections/:id',
        name: 'mcpServer',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            McpServerScreen(serverId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/marketplace/plugins/:id',
        name: 'marketplacePlugin',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            PluginDetailScreen(pluginId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/providers',
        name: 'providers',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProvidersScreen(),
      ),
      GoRoute(
        path: '/providers/new',
        name: 'providerNew',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ProviderEditorScreen(),
      ),
      GoRoute(
        path: '/providers/:id',
        name: 'providerEdit',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) =>
            ProviderEditorScreen(providerId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
