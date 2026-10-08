import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aisley_mobile_buyer/app/buyer_app.dart';

void main() {
  testWidgets(
    'mouse drag and wheel scroll preserve clicks and text selection',
    (tester) async {
      tester.view.physicalSize = const Size(420, 420);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController();
      final text = TextEditingController(
        text: 'Mouse text selection remains available',
      );
      var clicks = 0;
      addTearDown(scroll.dispose);
      addTearDown(text.dispose);

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const BuyerScrollBehavior(),
          home: Scaffold(
            body: ListView(
              controller: scroll,
              children: [
                const SizedBox(height: 180, child: Center(child: Text('Top'))),
                SizedBox(
                  height: 180,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () => clicks++,
                      child: const Text('Mouse click'),
                    ),
                  ),
                ),
                const SizedBox(height: 360, child: Text('Scrollable content')),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(controller: text),
                ),
                const SizedBox(height: 200),
              ],
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(360, 330));
      await mouse.moveTo(const Offset(360, 330));
      await mouse.down(const Offset(360, 330));
      await mouse.moveTo(const Offset(360, 180));
      await tester.pumpAndSettle();
      await mouse.up();
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));

      final beforeWheel = scroll.offset;
      await tester.sendEventToBinding(
        PointerScrollEvent(
          viewId: tester.view.viewId,
          timeStamp: Duration.zero,
          kind: PointerDeviceKind.mouse,
          device: 2,
          position: const Offset(360, 300),
          scrollDelta: const Offset(0, 120),
        ),
      );
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(beforeWheel));

      await tester.ensureVisible(find.text('Mouse click'));
      final click = tester.getCenter(find.text('Mouse click'));
      await mouse.moveTo(click);
      await mouse.down(click);
      await mouse.up();
      await tester.pumpAndSettle();
      expect(clicks, 1);

      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(TextField));
      final editable = find.byType(EditableText);
      final rect = tester.getRect(editable);
      final focusPoint = Offset(rect.right - 8, rect.center.dy);
      await mouse.moveTo(focusPoint);
      await mouse.down(focusPoint);
      await mouse.up();
      await tester.pumpAndSettle();
      final input = tester.widget<EditableText>(editable);
      expect(input.enableInteractiveSelection, isTrue);
      expect(input.focusNode.hasFocus, isTrue);
      expect(text.selection.isValid, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
