import '../db/app_database.dart';
import 'app_settings.dart';

/// Persists [AppSettings] in the encrypted database.
class SettingsRepository {
  SettingsRepository(this._database);

  static const _localeKey = 'locale';
  static const _onboardingKey = 'onboarding_complete';
  static const _autoUpdateKey = 'auto_update_check';
  static const _lastUpdateCheckKey = 'last_update_check';

  final AppDatabase _database;

  Future<AppSettings> load() async {
    final rows = await _database.select(_database.settingEntries).get();
    final values = {for (final row in rows) row.key: row.value};

    return AppSettings(
      localeCode: _readLocale(values[_localeKey]),
      onboardingComplete: values[_onboardingKey] == 'true',
      autoUpdateCheck: values[_autoUpdateKey] != 'false',
    );
  }

  Future<void> saveLocale(String? code) => _write(_localeKey, code ?? '');

  Future<void> saveOnboardingComplete(bool value) =>
      _write(_onboardingKey, value.toString());

  Future<void> saveAutoUpdateCheck(bool value) =>
      _write(_autoUpdateKey, value.toString());

  Future<DateTime?> loadLastUpdateCheck() async {
    final row =
        await (_database.select(_database.settingEntries)
              ..where((table) => table.key.equals(_lastUpdateCheckKey)))
            .getSingleOrNull();
    final value = row == null ? null : int.tryParse(row.value);
    return value == null ? null : DateTime.fromMillisecondsSinceEpoch(value);
  }

  Future<void> saveLastUpdateCheck(DateTime value) =>
      _write(_lastUpdateCheckKey, value.millisecondsSinceEpoch.toString());

  Future<void> _write(String key, String value) {
    return _database
        .into(_database.settingEntries)
        .insertOnConflictUpdate(
          SettingEntriesCompanion.insert(key: key, value: value),
        );
  }

  String? _readLocale(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return value == 'en' || value == 'ru' ? value : null;
  }
}
