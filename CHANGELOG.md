## 0.0.1

Initial release — a compact, velocity-aware value selector for Flutter.

Notable changes

- Add `ValueSelectorVelocity` widget: a numeric value picker that supports
	horizontal and vertical layouts, configurable step sizes, and clamped
	min/max values.
- Introduce `VScrollerStyle` to centralize styling and theming. `VScrollerStyle`
	includes color and typography defaults and can be overridden by consumers.
- Implement `VelocityScaledFixedExtentPhysics` — a tuned `ScrollPhysics` that
	scales fling velocity to make fast swipes traverse more values while
	preserving precision for slow drags.
- Add widget-level overrides: `itemTextStyle`, `selectedItemTextStyle`, `physics`,
	and `valueToString` formatting hook.
- Add a comprehensive widget test suite including deterministic physics tests
	and a golden-test scaffold.

Notes

- The package ships with sensible defaults, but styling and physics can be
	customized for different UX targets.
- Golden images are scaffolded under `test/` but not included in this release.
