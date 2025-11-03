<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# v_scroller

> A compact, velocity-aware value picker for Flutter. Smooth, configurable
> scrolling that scales with user fling velocity, plus easy theming via a
> single style object.

v_scroller provides a lightweight, customizable widget for selecting numeric
values (e.g., weights, measurements, counts) using a horizontal or vertical
picker. It adapts the scroll distance to the speed of the user's fling so
fast swipes cover more values while slow drags remain precise.

---

## Features

- Velocity-aware fling behavior — faster swipes travel further using a
	tunable physics implementation (no extra configuration required).
- Simple theming via `VScrollerStyle` (background, accent, primary color and
	text styles) with sensible defaults.
- Easy value formatting via `valueToString` or sensible default formatting.
- Widget-level overrides for typography and physics when you need fine control.
- Unit-tested (widget + physics tests) and includes golden-test scaffolding.

---

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
	v_scroller: ^0.0.1
```

Then run:

```bash
flutter pub get
```

---

## Quick example

Here's a minimal example showing the default usage inside a `MaterialApp`:

```dart
import 'package:flutter/material.dart';
import 'package:v_scroller/src/v_scroller.dart';

class DemoPage extends StatefulWidget {
	@override
	_DemoPageState createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
	double _value = 15.0;

	@override
	Widget build(BuildContext context) {
		return Scaffold(
			appBar: AppBar(title: Text('v_scroller demo')),
			body: Center(
				child: ValueSelectorVelocity(
					initialValue: _value,
					minValue: 0.0,
					maxValue: 100.0,
					onValueChanged: (v) => setState(() => _value = v),
				),
			),
		);
	}
}
```

---

## Theming & customization

You can customize colors and typography with `VScrollerStyle`:

```dart
final style = VScrollerStyle(
	background: Colors.grey.shade50,
	primary: Colors.indigo,
	accent: Colors.indigo.shade50,
	secondaryTextStyle: TextStyle(color: Colors.grey[700], fontSize: 14),
	selectedTextStyle: TextStyle(color: Colors.indigo, fontSize: 18, fontWeight: FontWeight.w600),
);

ValueSelectorVelocity(
	initialValue: 5.0,
	minValue: 0,
	maxValue: 20,
	style: style,
	onValueChanged: (v) => print('value: $v'),
)
```

You may also provide `itemTextStyle` / `selectedItemTextStyle` directly to the
widget if you prefer to override typography per-instance.

Tuning physics is supported by passing a custom `ScrollPhysics` instance to
`physics`, or by adjusting the defaults inside `VelocityScaledFixedExtentPhysics`.

---

## API highlights

- `ValueSelectorVelocity` — main widget
	- `initialValue`, `minValue`, `maxValue`, `step` — value domain and granularity
	- `onValueChanged` — callback when selection changes
	- `style` — `VScrollerStyle` instance for colors and text styles
	- `physics` — optional `ScrollPhysics` to override default behavior

- `VScrollerStyle` — central style object
	- `background`, `primary`, `accent` — palette colors
	- `secondaryTextStyle`, `selectedTextStyle` — editable `TextStyle`s used by
		the picker

See the code comments and tests for additional details and edge-case behavior.

---

## Tests

This package includes widget tests and deterministic physics tests. To run the
tests locally:

```bash
flutter test
```

There is also a golden test scaffold in `test/v_scroller_golden_test.dart`. To
update the golden images run:

```bash
flutter test --update-goldens
```

---

## Contributing

Contributions, issues and feature requests are welcome. The project follows a
straightforward development flow:

- Fork the repository
- Create a branch for your change
- Add tests for new behavior
- Open a PR and describe the change

Please follow existing code styles; prefer small, well-scoped commits.

---

## License

This project is licensed under the terms in the `LICENSE` file.

---

## Contact

If you have questions or need help integrating the widget, open an issue or
send a PR with details.
