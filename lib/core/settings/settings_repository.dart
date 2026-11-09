import '../db/app_database.dart';
import '../../domain/entities/pending_update_download.dart';
import 'app_settings.dart';

/// Persists [AppSettings] in the encrypted database.
class SettingsRepository {
  SettingsRepository(this._database);

  static const _localeKey = 'locale';
  static const _onboardingKey = 'onboarding_complete';
  static const _autoUpdateKey = 'auto_update_check';
  static const _lastUpdateCheckKey = 'last_update_check';
  static const _updateDownloadIdKey = 'update_download_id';
  static const _updateDownloadVersionKey = 'update_download_version';
  static const _updateDownloadFileKey = 'update_download_file';
  static const _updateDownloadChecksumKey = 'update_download_checksum';

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

  Future<PendingUpdateDownload?> loadPendingUpdateDownload() async {
    final rows = await _database.select(_database.settingEntries).get();
    final values = {for (final row in rows) row.key: row.value};
    final id = int.tryParse(values[_updateDownloadIdKey] ?? '');
    final version = values[_updateDownloadVersionKey];
    final fileName = values[_updateDownloadFileKey];
    if (id == null ||
        version == null ||
        version.isEmpty ||
        fileName == null ||
        fileName.isEmpty) {
      return null;
    }
    final checksum = values[_updateDownloadChecksumKey];
    return PendingUpdateDownload(
      id: id,
      version: version,
      fileName: fileName,
      checksumUrl: checksum == null || checksum.isEmpty ? null : checksum,
    );
  }

  Future<void> savePendingUpdateDownload(PendingUpdateDownload pending) async {
    await _write(_updateDownloadIdKey, pending.id.toString());
    await _write(_updateDownloadVersionKey, pending.version);
    await _write(_updateDownloadFileKey, pending.fileName);
    await _write(_updateDownloadChecksumKey, pending.checksumUrl ?? '');
  }

  Future<void> clearPendingUpdateDownload() async {
    await (_database.delete(_database.settingEntries)..where(
          (table) => table.key.isIn(const [
            _updateDownloadIdKey,
            _updateDownloadVersionKey,
            _updateDownloadFileKey,
            _updateDownloadChecksumKey,
          ]),
        ))
        .go();
  }

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
