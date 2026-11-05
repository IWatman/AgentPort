import 'package:flutter/widgets.dart';

/// User preferences that must be available before the first frame.
class AppSettings {
  const AppSettings({
    this.localeCode,
    this.onboardingComplete = false,
    this.autoUpdateCheck = true,
  });

  /// `null` follows the system language. Otherwise `en` or `ru`.
  final String? localeCode;

  final bool onboardingComplete;

  /// Automatic update checks are limited to the stable channel.
  final bool autoUpdateCheck;

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  AppSettings copyWith({
    String? localeCode,
    bool clearLocale = false,
    bool? onboardingComplete,
    bool? autoUpdateCheck,
  }) {
    return AppSettings(
      localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      autoUpdateCheck: autoUpdateCheck ?? this.autoUpdateCheck,
    );
  }
}
