import 'package:flutter/material.dart';

/// Formats a timestamp for the OpenCode connection and session lists.
String openCodeDateText(BuildContext context, DateTime value) {
  final localizations = MaterialLocalizations.of(context);
  final local = value.toLocal();
  final date = localizations.formatMediumDate(local);
  final time = localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(local),
    alwaysUse24HourFormat: true,
  );
  return '$date, $time';
}
