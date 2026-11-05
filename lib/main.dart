import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app/agent_port_app.dart';
import 'app/theme.dart';
import 'core/db/app_database.dart';
import 'core/security/secure_store.dart';
import 'core/settings/settings_controller.dart';
import 'core/settings/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final secureStore = SecureStore();
    final databaseKey = await secureStore.databaseKeyHex();
    final supportDirectory = await getApplicationSupportDirectory();
    final databaseFile = File(
      p.join(supportDirectory.path, 'agentport.sqlite'),
    );
    final database = openEncryptedDatabase(
      file: databaseFile,
      keyHex: databaseKey,
    );
    final settings = await SettingsRepository(database).load();

    runApp(
      ProviderScope(
        overrides: [
          secureStoreProvider.overrideWithValue(secureStore),
          appDatabaseProvider.overrideWithValue(database),
          initialSettingsProvider.overrideWithValue(settings),
        ],
        child: const AgentPortApp(),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('AgentPort bootstrap failed: $error\n$stackTrace');
    runApp(_BootstrapFailureApp(error: error));
  }
}

/// Shown only when the encrypted database cannot be opened, for example after
/// the keystore was reset while the database file survived.
class _BootstrapFailureApp extends StatelessWidget {
  const _BootstrapFailureApp({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.lock_reset_rounded, size: 48),
                    const SizedBox(height: 20),
                    Text(
                      'AgentPort could not start',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'The encrypted storage could not be opened. '
                      'Reinstalling the app removes local data and creates a new key.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => main(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
