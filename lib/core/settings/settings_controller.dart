import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import 'app_settings.dart';
import 'settings_repository.dart';

/// Replaced during bootstrap with settings loaded from the database.
final initialSettingsProvider = Provider<AppSettings>((ref) {
  throw UnimplementedError('Initial settings must be provided.');
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(appDatabaseProvider));
});

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  SettingsRepository get _repository => ref.read(settingsRepositoryProvider);

  @override
  AppSettings build() => ref.watch(initialSettingsProvider);

  Future<void> setLocale(String? code) async {
    state = state.copyWith(localeCode: code, clearLocale: code == null);
    await _repository.saveLocale(code);
  }

  Future<void> completeOnboarding() async {
    if (state.onboardingComplete) {
      return;
    }
    state = state.copyWith(onboardingComplete: true);
    await _repository.saveOnboardingComplete(true);
  }

  Future<void> setAutoUpdateCheck(bool value) async {
    state = state.copyWith(autoUpdateCheck: value);
    await _repository.saveAutoUpdateCheck(value);
  }
}
