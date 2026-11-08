import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Installs app-wide error handlers.
///
/// Debug builds keep Flutter's red error screen for diagnostics. Release
/// builds show a neutral message instead of exposing implementation details.
void installErrorHandling() {
  FlutterError.onError = (details) {
    debugPrint('AgentPort error: ${details.exceptionAsString()}');
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('AgentPort async error: $error');
    return true;
  };
  if (!kDebugMode) {
    ErrorWidget.builder = (details) => const AgentPortErrorScreen();
  }
}

class AgentPortErrorScreen extends StatelessWidget {
  const AgentPortErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF0B1020),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 44,
                color: Color(0xFF9AAFFF),
              ),
              SizedBox(height: 16),
              Text(
                'Something went wrong',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Restart AgentPort. If the problem repeats, reinstall the app or report an issue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFAAB2C8),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
