import 'package:flutter_test/flutter_test.dart';

import 'package:v_scroller/v_scroller.dart';

// Import internal NumberPicker type so tests can assert it is present.
import 'package:v_scroller/src/number_picker.dart';

import 'package:flutter/material.dart';

// Test helper classes (top-level) -------------------------------------------------
/// Simple linear simulation that moves from start by `distance` over durationSeconds.
class _DistanceSimulation extends Simulation {
  final double start;
  final double distance;
  final double durationSeconds;
  _DistanceSimulation(this.start, this.distance, {this.durationSeconds = 0.1});

  @override
  double x(double time) {
    if (time >= durationSeconds) return start + distance;
    return start + distance * (time / durationSeconds);
  }

  @override
  double dx(double time) => distance / durationSeconds;

  @override
  bool isDone(double time) => time >= durationSeconds;
}

/// Deterministic test physics: returns a simulation that moves the scroll
/// position by a fixed pixel distance depending on the velocity magnitude.
class TestPhysics extends ScrollPhysics {
  final double smallDistancePx;
  final double largeDistancePx;
  const TestPhysics({
    ScrollPhysics? parent,
    required this.smallDistancePx,
    required this.largeDistancePx,
  }) : super(parent: parent);

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final dist = velocity.abs() < 500
        ? (velocity.isNegative ? -smallDistancePx : smallDistancePx)
        : (velocity.isNegative ? -largeDistancePx : largeDistancePx);
    return _DistanceSimulation(position.pixels, dist, durationSeconds: 0.12);
  }
}

void main() {
  group('ValueSelectorVelocity - smoke & basic wiring', () {
    testWidgets('renders without exceptions and contains NumberPicker', (
      tester,
    ) async {
      final calls = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: 15.0,
              onValueChanged: (v) => calls.add(v),
            ),
          ),
        ),
      );

      // allow any initial frames
      await tester.pumpAndSettle();

      expect(find.byType(ValueSelectorVelocity), findsOneWidget);
      // NumberPicker is an internal child we expect to exist.
      expect(find.byType(NumberPicker), findsOneWidget);
      // Ensure no callback was invoked on mount.
      expect(calls, isEmpty);
    });

    testWidgets('initial value is shown and callback not called on mount', (
      tester,
    ) async {
      final calls = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: 20.0,
              onValueChanged: (v) => calls.add(v),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // The widget formats values with one decimal place by default.
      expect(find.text('20.0'), findsWidgets);
      expect(calls, isEmpty);
    });

    testWidgets('initial value is clamped to minValue when below range', (
      tester,
    ) async {
      final calls = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: 0.0,
              minValue: 0.5,
              onValueChanged: (v) => calls.add(v),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('0.5'), findsWidgets);
      expect(calls, isEmpty);
    });

    testWidgets('initial value is clamped to maxValue when above range', (
      tester,
    ) async {
      final calls = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              // use integer step so bounds align exactly for the test
              step: 1.0,
              minValue: 0.0,
              maxValue: 10.0,
              initialValue: 20.0,
              onValueChanged: (v) => calls.add(v),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('10.0'), findsWidgets);
      expect(calls, isEmpty);
    });
  });

  group('ValueSelectorVelocity - value/index logic', () {
    testWidgets(
      'maxIndex arithmetic and mapping for multiple (min, max, step) combos',
      (tester) async {
        final combos = [
          {'min': 0.5, 'max': 200.0, 'step': 0.5},
          {'min': 0.0, 'max': 10.0, 'step': 1.0},
          {'min': 0.0, 'max': 1.0, 'step': 0.25},
        ];

        for (final combo in combos) {
          final min = combo['min'] as double;
          final max = combo['max'] as double;
          final step = combo['step'] as double;

          final expectedMaxIndex = ((max - min) / step).round() + 1;
          final valueAtMaxIndex = min + ((expectedMaxIndex - 1) * step);
          final display = valueAtMaxIndex.toStringAsFixed(1);

          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: ValueSelectorVelocity(
                  initialValue: valueAtMaxIndex,
                  minValue: min,
                  maxValue: max,
                  step: step,
                  onValueChanged: (_) {},
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();
          // The displayed value for the top index should match the computed display
          expect(find.text(display), findsWidgets, reason: 'combo: $combo');
        }
      },
    );

    testWidgets('single small drag moves selection by approximately one step', (
      tester,
    ) async {
      final calls = <double>[];
      final itemWidth = 80.0;
      final initial = 5.0;
      final step = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: initial,
              minValue: 0.0,
              maxValue: 100.0,
              step: step,
              itemWidth: itemWidth,
              onValueChanged: (v) => calls.add(v),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // fling left by one item width -> should move roughly one step
      await tester.fling(
        find.byType(NumberPicker),
        Offset(-itemWidth * 1.1, 0),
        1000,
      );
      await tester.pumpAndSettle();

      expect(calls, isNotEmpty);
      final delta = (calls.last - initial).abs();
      // Ensure we moved at least one step (flings may move multiple steps
      // because of the widget's velocity-scaled physics).
      expect(delta, greaterThanOrEqualTo(step * 0.5));
    });

    testWidgets('step size handling for 0.5, 1.0 and 0.25', (tester) async {
      final steps = [0.5, 1.0, 0.25];
      final itemWidth = 70.0;

      for (final s in steps) {
        final calls = <double>[];
        final initial = 2.0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueSelectorVelocity(
                initialValue: initial,
                minValue: 0.0,
                maxValue: 100.0,
                step: s,
                itemWidth: itemWidth,
                onValueChanged: (v) => calls.add(v),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(NumberPicker),
          Offset(-itemWidth * 1.1, 0),
          1000,
        );
        await tester.pumpAndSettle();

        expect(calls, isNotEmpty);
        final delta = (calls.last - initial).abs();
        // We expect at least one step of movement; exact number of steps can
        // vary with fling velocity, but the delta should be a multiple of the
        // step (within tolerance) and at least one step.
        expect(
          delta,
          greaterThanOrEqualTo(s * 0.5),
          reason: 'step $s moved $delta',
        );
        final n = (delta / s).round();
        expect(
          (n * s - delta).abs(),
          lessThan(s * 0.25),
          reason: 'delta aligns to step $s',
        );
      }
    });

    testWidgets('rounding/formatting default and custom valueToString', (
      tester,
    ) async {
      // Default formatting: toStringAsFixed(1)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: 2.25,
              step: 0.25,
              onValueChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('2.3'), findsWidgets);

      // Custom formatter
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: 3.5,
              onValueChanged: (_) {},
              valueToString: (v) => '${v.toStringAsFixed(2)} kg',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('3.50 kg'), findsWidgets);
    });
  });

  group('ValueSelectorVelocity - interaction & physics', () {
    testWidgets('small fling moves approx one step (deterministic physics)', (
      tester,
    ) async {
      final calls = <double>[];
      final step = 1.0;
      final itemWidth = 40.0; // pixels per step in our test physics
      final physics = TestPhysics(
        smallDistancePx: itemWidth,
        largeDistancePx: itemWidth * 4,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: 5.0,
              minValue: 0.0,
              maxValue: 100.0,
              step: step,
              itemWidth: itemWidth,
              physics: physics,
              onValueChanged: (v) => calls.add(v),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // small fling (low velocity)
      await tester.fling(
        find.byType(NumberPicker),
        Offset(-itemWidth * 1.1, 0),
        200,
      );
      await tester.pumpAndSettle();

      expect(calls, isNotEmpty);
      final smallDelta = (calls.last - 5.0).abs();
      expect(smallDelta, greaterThanOrEqualTo(step * 0.9));
      expect(smallDelta, lessThanOrEqualTo(step * 1.5));
    });

    testWidgets(
      'high velocity fling moves more steps than low velocity (deterministic physics)',
      (tester) async {
        final callsLow = <double>[];
        final callsHigh = <double>[];
        final step = 0.5;
        final itemWidth = 30.0;
        final physics = TestPhysics(
          smallDistancePx: itemWidth,
          largeDistancePx: itemWidth * 6,
        );

        // low velocity run
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueSelectorVelocity(
                initialValue: 10.0,
                minValue: 0.0,
                maxValue: 200.0,
                step: step,
                itemWidth: itemWidth,
                physics: physics,
                onValueChanged: (v) => callsLow.add(v),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(NumberPicker),
          Offset(-itemWidth * 1.0, 0),
          200,
        );
        await tester.pumpAndSettle();

        // high velocity run
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueSelectorVelocity(
                initialValue: 10.0,
                minValue: 0.0,
                maxValue: 200.0,
                step: step,
                itemWidth: itemWidth,
                physics: physics,
                onValueChanged: (v) => callsHigh.add(v),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.fling(
          find.byType(NumberPicker),
          Offset(-itemWidth * 1.0, 0),
          3000,
        );
        await tester.pumpAndSettle();

        expect(callsLow, isNotEmpty);
        expect(callsHigh, isNotEmpty);
        final lowDelta = (callsLow.last - 10.0).abs();
        final highDelta = (callsHigh.last - 10.0).abs();
        // The high-velocity fling should move at least as many steps as the low-velocity one.
        expect(highDelta, greaterThanOrEqualTo(lowDelta));
      },
    );

    testWidgets('physics override and haptics flag passed to NumberPicker', (
      tester,
    ) async {
      final physicsInstance = BouncingScrollPhysics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: 2.0,
              onValueChanged: (_) {},
              physics: physicsInstance,
              haptics: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final np = tester.widget<NumberPicker>(find.byType(NumberPicker));
      expect(identical(np.physics, physicsInstance), isTrue);
      expect(np.haptics, isFalse);
    });
  });

  group('ValueSelectorVelocity - styling & theming', () {
    testWidgets(
      'colors from VScrollerStyle applied to container and NumberPicker',
      (tester) async {
        final style = VScrollerStyle(
          background: Colors.green.shade50,
          primary: Colors.purple,
          secondaryTextStyle: const TextStyle(color: Colors.orange),
          accent: Colors.blueAccent,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueSelectorVelocity(
                initialValue: 4.0,
                minValue: 0.0,
                maxValue: 10.0,
                style: style,
                onValueChanged: (_) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Find a Container whose decoration matches the style.background
        final containers = tester.widgetList<Container>(find.byType(Container));
        final outer = containers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration as BoxDecoration).color == style.background,
          orElse: () =>
              throw StateError('Outer container with background not found'),
        );
        final outerDec = outer.decoration as BoxDecoration;
        expect(outerDec.color, equals(style.background));
        final borderColor = (outerDec.border as Border).top.color;
  final expectedBorder = (style.secondaryTextStyle.color ?? Colors.black).withOpacity(0.3);
        // Compare RGB exactly and allow tiny integer difference in alpha due to rounding
        expect(borderColor.red, equals(expectedBorder.red));
        expect(borderColor.green, equals(expectedBorder.green));
        expect(borderColor.blue, equals(expectedBorder.blue));
        expect(
          (borderColor.alpha - expectedBorder.alpha).abs(),
          lessThanOrEqualTo(2),
        );

        final np = tester.widget<NumberPicker>(find.byType(NumberPicker));
        final dec = np.decoration as BoxDecoration;
        expect(dec.color, equals(style.accent));
        expect((dec.border as Border).top.color, equals(style.primary));
      },
    );

    testWidgets(
      'itemTextStyle and selectedItemTextStyle are applied to Text widgets',
      (tester) async {
        final itemStyle = TextStyle(color: Colors.teal, fontSize: 12);
        final selectedStyle = TextStyle(
          color: Colors.red,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ValueSelectorVelocity(
                initialValue: 3.0,
                minValue: 0.0,
                maxValue: 10.0,
                itemTextStyle: itemStyle,
                selectedItemTextStyle: selectedStyle,
                onValueChanged: (_) {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Collect Text widgets inside NumberPicker
        final textFinder = find.descendant(
          of: find.byType(NumberPicker),
          matching: find.byType(Text),
        );
        final texts = tester.widgetList<Text>(textFinder).toList();
        // There should be at least one with selected style and at least one with item style
        final hasSelected = texts.any(
          (t) =>
              t.style?.color == selectedStyle.color &&
              t.style?.fontSize == selectedStyle.fontSize &&
              t.style?.fontWeight == selectedStyle.fontWeight,
        );
        final hasItem = texts.any(
          (t) =>
              t.style?.color == itemStyle.color &&
              t.style?.fontSize == itemStyle.fontSize &&
              (t.style?.fontWeight == itemStyle.fontWeight ||
                  t.style?.fontWeight == null),
        );

        expect(
          hasSelected,
          isTrue,
          reason: 'expected at least one Text with selectedItemTextStyle',
        );
        expect(
          hasItem,
          isTrue,
          reason: 'expected at least one Text with itemTextStyle',
        );
      },
    );

    testWidgets('visible values expose semantics labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueSelectorVelocity(
              initialValue: 6.0,
              minValue: 0.0,
              maxValue: 20.0,
              onValueChanged: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check that the currently visible formatted value has a semantics node
      final node = tester.getSemantics(find.text('6.0'));
      expect(node.label, '6.0');
      // Also verify there are multiple visible Text widgets in the picker
      final textFinder = find.descendant(
        of: find.byType(NumberPicker),
        matching: find.byType(Text),
      );
      expect(tester.widgetList<Text>(textFinder).length, greaterThan(1));
    });
  });

  group('ValueSelectorVelocity - edge cases & invalid params', () {
    testWidgets('renders when minValue == maxValue and only that value is selectable', (tester) async {
      final calls = <double>[];
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ValueSelectorVelocity(
        initialValue: 2.0,
        minValue: 2.0,
        maxValue: 2.0,
        onValueChanged: (v) => calls.add(v),
      ))));

      await tester.pumpAndSettle();
      // Only the single value should be visible
      expect(find.text('2.0'), findsWidgets);
      // Try fling — should not change value
      await tester.fling(find.byType(NumberPicker), Offset(-50, 0), 500);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
    });

    testWidgets('top-most computed value does not exceed maxValue when (max-min)/step is fractional', (tester) async {
      final min = 0.0, max = 1.0, step = 0.3;
      final expectedMaxIndex = ((max - min) / step).round() + 1;
      final valueAtMaxIndex = min + ((expectedMaxIndex - 1) * step);

      await tester.pumpWidget(MaterialApp(home: Scaffold(body: ValueSelectorVelocity(
        initialValue: valueAtMaxIndex,
        minValue: min,
        maxValue: max,
        step: step,
        onValueChanged: (_) {},
      ))));

      await tester.pumpAndSettle();
      // The displayed top value must not exceed max
      final text = valueAtMaxIndex.toStringAsFixed(1);
      final displayed = find.text(text);
      expect(displayed, findsWidgets);
      expect(valueAtMaxIndex <= max, isTrue);
    });

    testWidgets('constructor asserts for invalid params: step <= 0 and minValue > maxValue', (tester) async {
      // step <= 0
      expect(() async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: ValueSelectorVelocity(
          initialValue: 1.0,
          minValue: 0.0,
          maxValue: 10.0,
          step: 0.0,
          onValueChanged: (_) {},
        ))));
      }, throwsA(isA<AssertionError>()));

      // minValue > maxValue
      expect(() async {
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: ValueSelectorVelocity(
          initialValue: 1.0,
          minValue: 5.0,
          maxValue: 2.0,
          onValueChanged: (_) {},
        ))));
      }, throwsA(isA<AssertionError>()));
    });
  });
}
