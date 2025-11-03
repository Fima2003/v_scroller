import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:v_scroller/src/app_colors.dart';
import 'number_picker.dart';

/// Styling configuration for the scroller widgets. Provides sensible defaults
/// but is fully overrideable by consumers of the package.
class VScrollerStyle {
  final Color background;
  final Color primary;
  final TextStyle secondaryTextStyle;
  final TextStyle selectedTextStyle;
  final Color accent;

  const VScrollerStyle({
    this.background = AppColors.background,
    this.primary = AppColors.primary,
    this.secondaryTextStyle = const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    this.selectedTextStyle = const TextStyle(color: AppColors.primary, fontSize: 18, fontWeight: FontWeight.w600),
    this.accent = AppColors.accent,
  });

  VScrollerStyle copyWith({
    Color? background,
    Color? primary,
    TextStyle? secondaryTextStyle,
    TextStyle? selectedTextStyle,
    Color? accent,
  }) {
    return VScrollerStyle(
      background: background ?? this.background,
      primary: primary ?? this.primary,
      secondaryTextStyle: secondaryTextStyle ?? this.secondaryTextStyle,
      selectedTextStyle: selectedTextStyle ?? this.selectedTextStyle,
      accent: accent ?? this.accent,
    );
  }
}

/// A velocity-aware value selector using 0.5 unit steps and scroll physics that
/// scale user scrolling based on velocity. Does not replace existing selector yet.
class ValueSelectorVelocity extends StatefulWidget {
  /// Initial value to select.
  final double initialValue;

  /// Callback when the selected value changes.
  final ValueChanged<double> onValueChanged;

  /// Minimum selectable value.
  final double minValue;

  /// Maximum selectable value.
  final double maxValue;

  /// Styling overrides for colors used by the widget.
  final VScrollerStyle style;

  /// Step size for the value selector.
  final double step;

  /// Width of each item in the picker.
  final double itemWidth;

  /// Height of each item in the picker.
  final double itemHeight;

  /// Number of visible items in the picker. If null it's computed from screen
  /// width (same as previous behavior).
  final int? itemCount;

  /// Height of the outer container.
  final double containerHeight;

  /// Whether to emit haptics on selection.
  final bool haptics;

  /// Orientation of the picker.
  final Axis axis;

  /// Optional custom ScrollPhysics. If provided it will be used directly.
  /// Otherwise the widget will create a `VelocityScaledFixedExtentPhysics`
  /// using the tuning values above.
  final ScrollPhysics? physics;

  /// Optional overrides for the item text styles.
  final TextStyle? itemTextStyle;
  final TextStyle? selectedItemTextStyle;

  /// Optional mapper to convert a numeric value to the displayed string.
  /// If null, the widget will default to one decimal place.
  final String Function(double value)? valueToString;

  const ValueSelectorVelocity({
    super.key,
    required this.onValueChanged,
    this.initialValue = 15.0,
    this.minValue = 0.5,
    this.maxValue = 200.0,
    this.style = const VScrollerStyle(),
    this.step = 0.5,
    this.itemWidth = 65.0,
    this.itemHeight = 80.0,
    this.itemCount,
    this.containerHeight = 100.0,
    this.haptics = true,
    this.axis = Axis.horizontal,
    this.physics = const VelocityScaledFixedExtentPhysics(),
    this.itemTextStyle,
    this.selectedItemTextStyle,
    this.valueToString,
  }) : assert(step > 0, 'step must be > 0'),
       assert(minValue <= maxValue, 'minValue must be <= maxValue');

  /// Ensure constructor invariants
  

  @override
  State<ValueSelectorVelocity> createState() => _ValueSelectorVelocityState();
}

class _ValueSelectorVelocityState extends State<ValueSelectorVelocity> {
  late int _currentIndex;

  int get _minIndex => 1;
  int get _maxIndex =>
      ((widget.maxValue - widget.minValue) / widget.step).round() + 1;

  double get _currentValue =>
      widget.minValue + ((_currentIndex - 1) * widget.step);

  @override
  void initState() {
    super.initState();
    final rawIndex =
        ((widget.initialValue - widget.minValue) / widget.step).round() + 1;
    _currentIndex = rawIndex.clamp(_minIndex, _maxIndex);
  }

  void _onChanged(int value) {
    setState(() => _currentIndex = value);
    widget.onValueChanged(_currentValue);
  }

  @override
  Widget build(BuildContext context) {
    final itemWidth = widget.itemWidth;
    final visibleCount =
        widget.itemCount ??
        ((MediaQuery.of(context).size.width / 85).floor() / 2).floor() * 2 + 1;

    final style = widget.style;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: widget.containerHeight,
          decoration: BoxDecoration(
            color: style.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (style.secondaryTextStyle.color ?? Colors.black).withOpacity(0.3)),
          ),
          child: NumberPicker(
            value: _currentIndex,
            minValue: _minIndex,
            maxValue: _maxIndex,
            axis: widget.axis,
            itemHeight: widget.itemHeight,
            itemWidth: itemWidth,
            itemCount: visibleCount,
            step: 1,
            haptics: widget.haptics,
            physics: widget.physics,
            onChanged: _onChanged,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: style.primary, width: 2),
              color: style.accent,
            ),
            textMapper: (numberText) {
              final int index = int.parse(numberText);
              final double valueBase =
                  widget.minValue + ((index - 1) * widget.step);
              if (widget.valueToString != null)
                return widget.valueToString!(valueBase);
              return valueBase.toStringAsFixed(1);
            },
            textStyle: widget.itemTextStyle ?? style.secondaryTextStyle,
            selectedTextStyle: widget.selectedItemTextStyle ?? style.selectedTextStyle,
          ),
        ),
      ],
    );
  }
}

/// ScrollPhysics that scale the user offset and fling velocity based on how fast
/// the finger/scroll is moving; designed for fixed-extent lists (step=1).
class VelocityScaledFixedExtentPhysics extends ScrollPhysics {
  /// Base pixel distance per step (item) at normal speed.
  final double basePixelsPerStep;

  /// Velocity at which the scaling multiplier is ~2x.
  final double v0;

  /// Maximum scaling multiplier.
  final double maxMultiplier;

  const VelocityScaledFixedExtentPhysics({
    super.parent,
    this.basePixelsPerStep = 20.0,
    this.v0 = 1200.0,
    this.maxMultiplier = 4.0,
  });

  @override
  VelocityScaledFixedExtentPhysics applyTo(ScrollPhysics? ancestor) {
    return VelocityScaledFixedExtentPhysics(
      parent: buildParent(ancestor),
      basePixelsPerStep: basePixelsPerStep,
      v0: v0,
      maxMultiplier: maxMultiplier,
    );
  }

  double _multiplierForVelocity(double velocity) {
    final speed = velocity.abs();
    final norm = speed / v0;
    // Smooth curve 1..max
    final m = 1 + (maxMultiplier - 1) * (1 - math.exp(-norm));
    return m.clamp(1.0, maxMultiplier);
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // When user drags, scale offset by a factor based on current activity velocity if available.
    // As a proxy, use recent offset magnitude: faster drags produce larger raw offsets per frame.
    // Keep it simple here: compute a heuristic velocity from offset per animation tick.
    final estVelocity = (offset / (1 / 60.0)); // px per second approx at 60fps
    final m = _multiplierForVelocity(estVelocity);
    return offset * m;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Inflate fling velocity so it travels further when fast.
    final m = _multiplierForVelocity(velocity);
    return super.createBallisticSimulation(position, velocity * m);
  }
}
