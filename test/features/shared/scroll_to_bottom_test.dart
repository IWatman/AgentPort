import 'package:agentport/features/shared/scroll_to_bottom.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('settles at the real bottom of a lazily built list', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          height: 400,
          child: ListView.builder(
            controller: controller,
            itemCount: 400,
            itemBuilder: (context, index) =>
                SizedBox(height: 90, child: Text('Item $index')),
          ),
        ),
      ),
    );

    settleScrollToBottom(controller);
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump();
    }

    expect(controller.hasClients, isTrue);
    expect(controller.offset, controller.position.maxScrollExtent);
    expect(tester.takeException(), isNull);
  });

  test('does nothing without an attached scroll view', () {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    expect(() => settleScrollToBottom(controller), returnsNormally);
  });
}
