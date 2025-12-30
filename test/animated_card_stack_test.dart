import 'package:animated_card_stack/animated_card_stack.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimatedCardStack Rendering & Config', () {
    testWidgets('renders correct number of visible cards', (
      WidgetTester tester,
    ) async {
      final items = List.generate(5, (index) => 'Item $index');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedCardStack(
              items: items,
              visibleCardCount: 3,
              itemBuilder: (context, item) => Text(item),
            ),
          ),
        ),
      );

      // Should find 3 visible cards (Item 0, Item 1, Item 2)
      // Note: Stack renders bottom-up. Item 2 is at bottom, Item 0 is at top.
      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsNothing);
    });

    testWidgets('shows placeholder when items are empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedCardStack(
              items: const [],
              itemBuilder: (context, item) => Text('$item'),
              placeholderBuilder: (context) => const Text('No Items'),
            ),
          ),
        ),
      );

      expect(find.text('No Items'), findsOneWidget);
    });

    testWidgets('renders generic types correctly', (WidgetTester tester) async {
      final items = [1, 2, 3];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedCardStack<int>(
              items: items,
              itemBuilder: (context, item) => Text('Number $item'),
            ),
          ),
        ),
      );

      expect(find.text('Number 1'), findsOneWidget);
    });
  });

  group('AnimatedCardStack Interactions', () {
    testWidgets('dragging past threshold triggers cycle', (
      WidgetTester tester,
    ) async {
      final items = ['A', 'B'];
      bool cardChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedCardStack(
              items: items,
              dragThreshold: 50.0,
              onCardChanged: (index, item) {
                cardChanged = true;
                expect(item, equals('B')); // New top card should be B
              },
              itemBuilder: (context, item) =>
                  SizedBox(width: 300, height: 400, child: Text(item)),
            ),
          ),
        ),
      );

      // Drag 'A' to the right, past threshold
      await tester.drag(find.text('A'), const Offset(200, 0));
      await tester.pump(); // Start animation

      // Verify callback immediately
      expect(cardChanged, isTrue);

      // Let animation finish
      await tester.pumpAndSettle();

      // 'B' should now be the top card (user visible)
      // In the stack logic, the top card is at index 0 of the internal order.
      // Since we just cycled, B is at 0, A is at the end.
      // We can verify simply that B is visible and likely on top/successfully rendered.
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('dragging below threshold snaps back', (
      WidgetTester tester,
    ) async {
      final items = ['A', 'B'];
      bool cardChanged = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedCardStack(
              items: items,
              dragThreshold: 200.0, // High threshold
              onCardChanged: (_, __) => cardChanged = true,
              itemBuilder: (context, item) =>
                  SizedBox(width: 300, height: 400, child: Text(item)),
            ),
          ),
        ),
      );

      // Drag 'A' a little bit
      await tester.drag(find.text('A'), const Offset(50, 0));
      await tester.pump();
      await tester.pumpAndSettle();

      // Should NOT have changed
      expect(cardChanged, isFalse);
      expect(find.text('A'), findsOneWidget);
    });
  });

  group('AnimatedCardStack Controller', () {
    testWidgets('swipeNext triggers animation', (WidgetTester tester) async {
      final controller = AnimatedCardStackController();
      final items = ['1', '2'];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedCardStack(
              controller: controller,
              items: items,
              itemBuilder: (context, item) =>
                  SizedBox(width: 100, height: 100, child: Text(item)),
            ),
          ),
        ),
      );

      expect(find.text('1'), findsOneWidget);

      // Trigger swipe
      final result = controller.swipeNext();
      expect(result, isTrue);

      await tester.pump(); // Start animation
      await tester.pumpAndSettle();

      // Should iterate to next card
      expect(find.text('2'), findsOneWidget);
    });
  });

  group('AnimatedCardStack Callbacks', () {
    testWidgets('onTap and onDoubleTap work', (WidgetTester tester) async {
      String? tappedItem;
      String? doubleTappedItem;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedCardStack(
              items: const ['TapMe'],
              onTap: (item) => tappedItem = item,
              onDoubleTap: (item) => doubleTappedItem = item,
              itemBuilder: (context, item) => Container(
                color: Colors.red, // Solid color to ensure hit test works
                width: 200,
                height: 200,
                child: Text(item),
              ),
            ),
          ),
        ),
      );

      // --- Test Single Tap ---
      await tester.tap(find.text('TapMe'));
      // Wait for double-tap delay to expire so proper onTap is triggered
      await tester.pump(kDoubleTapTimeout);
      expect(tappedItem, equals('TapMe'));
      expect(doubleTappedItem, isNull);

      // Reset
      tappedItem = null;

      // --- Test Double Tap ---
      await tester.tap(find.text('TapMe'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('TapMe'));
      await tester.pumpAndSettle();

      expect(doubleTappedItem, equals('TapMe'));
      // Note: In typical Flutter GestureDetector, a successful double tap DOES NOT trigger onTap
      expect(tappedItem, isNull);
    });
  });
}
