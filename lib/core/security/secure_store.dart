import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small wrapper around the platform keystore.
///
/// Every secret used by AgentPort goes through this class. On Android the
/// values are encrypted with a hardware-backed key from the Android Keystore.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              resetOnError: true,
              storageNamespace: 'agentport',
            ),
          );

  static const databaseKeyName = 'agentport.database.key.v1';

  final FlutterSecureStorage _storage;
  final Random _random = Random.secure();

  /// Returns the 256-bit SQLCipher key as lowercase hex.
  ///
  /// The key is generated once and kept in the platform keystore. It never
  /// leaves the device.
  Future<String> databaseKeyHex() async {
    final existing = await _storage.read(key: databaseKeyName);
    if (existing != null && existing.length == 64) {
      return existing;
    }

    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: databaseKeyName, value: hex);
    return hex;
  }

  Future<String?> read(String key) => _storage.read(key: key);

  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  Future<void> delete(String key) => _storage.delete(key: key);
}

final secureStoreProvider = Provider<SecureStore>((ref) {
  throw UnimplementedError('SecureStore must be provided during bootstrap.');
});
