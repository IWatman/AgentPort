import 'package:agentport/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigation labels stay on one line with a large font', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          bottomNavigationBar: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1,
            child: NavigationBar(
              selectedIndex: 2,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  label: 'Чаты',
                ),
                NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  label: 'Плагины',
                ),
                NavigationDestination(
                  icon: Icon(Icons.hub_outlined),
                  label: 'Серверы',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Настройки',
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final label = tester.getSize(find.text('Серверы'));
    expect(label.height, lessThan(20));
  });
}
