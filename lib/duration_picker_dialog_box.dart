library duration_picker_dialog_box;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum _ScreenSize { mobile, desktop, tablet }

const _smallBreakPoint = 700.0;
const _mediumBreakPoint = 940.0;

// ignore: library_private_types_in_public_api
_ScreenSize getScreenSize(double width) {
  if (width < _smallBreakPoint) {
    return _ScreenSize.mobile;
  } else if (width < _mediumBreakPoint) {
    return _ScreenSize.tablet;
  } else {
    return _ScreenSize.desktop;
  }
}

const Duration _kDialAnimateDuration = Duration(milliseconds: 200);
const double _kDefaultPadding = 8;

// const double _kDurationPickerWidthPortrait = 650.0;
// const double _kDurationPickerWidthLandscape = 600.0;

//const double _kDurationPickerHeightPortrait = 380.0;
// const double _kDurationPickerHeightPortrait = 480.0;
// const double _kDurationPickerHeightLandscape = 310.0;

const double _kTwoPi = 2 * math.pi;

enum DurationPickerMode {
  // ignore: constant_identifier_names
  Day,
  // ignore: constant_identifier_names
  Hour,
  // ignore: constant_identifier_names
  Minute,
  // ignore: constant_identifier_names
  Second,
  // ignore: constant_identifier_names
  MilliSecond,
  // ignore: constant_identifier_names
  MicroSecond,
}

extension _DurationPickerModeExtenstion on DurationPickerMode {
  static const nextItems = {
    DurationPickerMode.Day: DurationPickerMode.Hour,
    DurationPickerMode.Hour: DurationPickerMode.Minute,
    DurationPickerMode.Minute: DurationPickerMode.Day,
  };
  static const prevItems = {
    DurationPickerMode.Day: DurationPickerMode.Minute,
    DurationPickerMode.Hour: DurationPickerMode.Day,
    DurationPickerMode.Minute: DurationPickerMode.Hour,
  };

  // DurationPickerMode? get next => nextItems[this];

  // DurationPickerMode? get prev => prevItems[this];
}

class _TappableLabel {
  _TappableLabel({
    required this.value,
    required this.painter,
    required this.onTap,
  });

  /// The value this label is displaying.
  final int value;

  /// Paints the text of the label.
  final TextPainter painter;

  /// Called when a tap gesture is detected on the label.
  final VoidCallback onTap;
}

class _DialPainterNew extends CustomPainter {
  _DialPainterNew({
    required this.primaryLabels,
    required this.secondaryLabels,
    required this.backgroundColor,
    required this.accentColor,
    required this.dotColor,
    required this.theta,
    required this.textDirection,
    required this.selectedValue,
  }) : super(repaint: PaintingBinding.instance.systemFonts);

  final List<_TappableLabel> primaryLabels;
  final List<_TappableLabel> secondaryLabels;
  final Color backgroundColor;
  final Color accentColor;
  final Color dotColor;
  final double theta;
  final TextDirection textDirection;
  final int selectedValue;

  static const double _labelPadding = 28.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.shortestSide / 2.0;
    final Offset center = Offset(size.width / 2.0, size.height / 2.0);
    final Offset centerPoint = center;
    canvas.drawCircle(centerPoint, radius, Paint()..color = backgroundColor);

    final double labelRadius = radius - _labelPadding;
    Offset getOffsetForTheta(double theta) {
      return center +
          Offset(labelRadius * math.cos(theta), -labelRadius * math.sin(theta));
    }

    void paintLabels(List<_TappableLabel> labels) {
      final double labelThetaIncrement = -_kTwoPi / labels.length;
      double labelTheta = math.pi / 2.0;

      for (final _TappableLabel label in labels) {
        final TextPainter labelPainter = label.painter;
        final Offset labelOffset =
            Offset(-labelPainter.width / 2.0, -labelPainter.height / 2.0);
        labelPainter.paint(canvas, getOffsetForTheta(labelTheta) + labelOffset);
        labelTheta += labelThetaIncrement;
      }
    }

    paintLabels(primaryLabels);

    final Paint selectorPaint = Paint()..color = accentColor;
    final Offset focusedPoint = getOffsetForTheta(theta);
    const double focusedRadius = _labelPadding - 4.0;
    canvas.drawCircle(centerPoint, 4.0, selectorPaint);
    canvas.drawCircle(focusedPoint, focusedRadius, selectorPaint);
    selectorPaint.strokeWidth = 2.0;
    canvas.drawLine(centerPoint, focusedPoint, selectorPaint);

    int len = primaryLabels.length;
    //len = 14;
    final double labelThetaIncrement = -_kTwoPi / len;
    bool flag = len == 10
        ? !(theta % labelThetaIncrement > 0.25 &&
            theta % labelThetaIncrement < 0.4)
        : (theta % labelThetaIncrement > 0.1 &&
            theta % labelThetaIncrement < 0.45);
    if (flag) {
      canvas.drawCircle(focusedPoint, 2.0, selectorPaint..color = dotColor);
    }

    final Rect focusedRect = Rect.fromCircle(
      center: focusedPoint,
      radius: focusedRadius,
    );
    canvas
      ..save()
      ..clipPath(Path()..addOval(focusedRect));
    paintLabels(secondaryLabels);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_DialPainterNew oldPainter) {
    return oldPainter.primaryLabels != primaryLabels ||
        oldPainter.secondaryLabels != secondaryLabels ||
        oldPainter.backgroundColor != backgroundColor ||
        oldPainter.accentColor != accentColor ||
        oldPainter.theta != theta;
  }
}

class _Dial extends StatefulWidget {
  const _Dial({
    required this.value,
    required this.mode,
    required this.onChanged,
  });

  final int value;
  final DurationPickerMode mode;
  final ValueChanged<int> onChanged;

  @override
  _DialState createState() => _DialState();
}

class _DialState extends State<_Dial> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _thetaController = AnimationController(
      duration: _kDialAnimateDuration,
      vsync: this,
    );
    _thetaTween = Tween<double>(begin: _getThetaForTime(widget.value));
    _theta = _thetaController!
        .drive(CurveTween(curve: standardEasing))
        .drive(_thetaTween!)
      ..addListener(() => setState(() {
            /* _theta.value has changed */
          }));
  }

  ThemeData? themeData;
  MaterialLocalizations? localizations;
  MediaQueryData? media;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(debugCheckHasMediaQuery(context));
    themeData = Theme.of(context);
    localizations = MaterialLocalizations.of(context);
    media = MediaQuery.of(context);
  }

  @override
  void didUpdateWidget(_Dial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode != oldWidget.mode || widget.value != oldWidget.value) {
      if (!_dragging) _animateTo(_getThetaForTime(widget.value));
    }
  }

  @override
  void dispose() {
    _thetaController!.dispose();
    super.dispose();
  }

  Tween<double>? _thetaTween;
  Animation<double>? _theta;
  AnimationController? _thetaController;
  bool _dragging = false;

  static double _nearest(double target, double a, double b) {
    return ((target - a).abs() < (target - b).abs()) ? a : b;
  }

  void _animateTo(double targetTheta) {
    final double currentTheta = _theta!.value;
    double beginTheta =
        _nearest(targetTheta, currentTheta, currentTheta + _kTwoPi);
    beginTheta = _nearest(targetTheta, beginTheta, currentTheta - _kTwoPi);
    _thetaTween!
      ..begin = beginTheta
      ..end = targetTheta;
    _thetaController!
      ..value = 0.0
      ..forward();
  }

  double _getThetaForTime(int value) {
    double fraction;
    switch (widget.mode) {
      case DurationPickerMode.Hour:
        fraction = (value / Duration.hoursPerDay) % Duration.hoursPerDay;
        break;
      case DurationPickerMode.Minute:
        fraction = (value / Duration.minutesPerHour) % Duration.minutesPerHour;
        break;
      case DurationPickerMode.Second:
        fraction =
            (value / Duration.secondsPerMinute) % Duration.secondsPerMinute;
        break;
      case DurationPickerMode.MilliSecond:
        fraction = (value / Duration.millisecondsPerSecond) %
            Duration.millisecondsPerSecond;
        break;
      case DurationPickerMode.MicroSecond:
        fraction = (value / Duration.microsecondsPerMillisecond) %
            Duration.microsecondsPerMillisecond;

        break;
      default:
        fraction = -1;
        break;
    }
    return (math.pi / 2.0 - fraction * _kTwoPi) % _kTwoPi;
  }

  int _getTimeForTheta(double theta) {
    final double fraction = (0.25 - (theta % _kTwoPi) / _kTwoPi) % 1.0;
    int result;
    switch (widget.mode) {
      case DurationPickerMode.Hour:
        result =
            (fraction * Duration.hoursPerDay).round() % Duration.hoursPerDay;
        break;
      case DurationPickerMode.Minute:
        result = (fraction * Duration.minutesPerHour).round() %
            Duration.minutesPerHour;
        break;
      case DurationPickerMode.Second:
        result = (fraction * Duration.secondsPerMinute).round() %
            Duration.secondsPerMinute;
        break;
      case DurationPickerMode.MilliSecond:
        result = (fraction * Duration.millisecondsPerSecond).round() %
            Duration.millisecondsPerSecond;
        break;
      case DurationPickerMode.MicroSecond:
        result = (fraction * Duration.microsecondsPerMillisecond).round() %
            Duration.microsecondsPerMillisecond;
        break;
      default:
        result = -1;
        break;
    }
    return result;
  }

  int _notifyOnChangedIfNeeded() {
    final int current = _getTimeForTheta(_theta!.value);
    if (current != widget.value) widget.onChanged(current);
    return current;
  }

  void _updateThetaForPan({bool roundMinutes = false}) {
    setState(() {
      final Offset offset = _position! - _center!;
      double angle =
          (math.atan2(offset.dx, offset.dy) - math.pi / 2.0) % _kTwoPi;
      if (roundMinutes) {
        angle = _getThetaForTime(_getTimeForTheta(angle));
      }
      _thetaTween!
        ..begin = angle
        ..end = angle;
    });
  }

  Offset? _position;
  Offset? _center;

  void _handlePanStart(DragStartDetails details) {
    assert(!_dragging);
    _dragging = true;
    final RenderBox box = context.findRenderObject() as RenderBox;
    _position = box.globalToLocal(details.globalPosition);
    _center = box.size.center(Offset.zero);
    _updateThetaForPan();
    _notifyOnChangedIfNeeded();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    _position = _position! + details.delta;
    _updateThetaForPan();
    _notifyOnChangedIfNeeded();
  }

  void _handlePanEnd(DragEndDetails details) {
    assert(_dragging);
    _dragging = false;
    _position = null;
    _center = null;
    _animateTo(_getThetaForTime(widget.value));
  }

  void _handleTapUp(TapUpDetails details) {
    final RenderBox box = context.findRenderObject() as RenderBox;
    _position = box.globalToLocal(details.globalPosition);
    _center = box.size.center(Offset.zero);
    _updateThetaForPan(roundMinutes: true);
    final int newValue = _notifyOnChangedIfNeeded();

    _announceToAccessibility(context, localizations!.formatDecimal(newValue));
    _animateTo(_getThetaForTime(_getTimeForTheta(_theta!.value)));
    _dragging = false;

    _position = null;
    _center = null;
  }

  void _selectValue(int value) {
    _announceToAccessibility(context, localizations!.formatDecimal(value));
    final double angle = _getThetaForTime(widget.value);
    _thetaTween!
      ..begin = angle
      ..end = angle;
    _notifyOnChangedIfNeeded();
  }

  static const List<int> _twentyFourHours = <int>[
    0,
    2,
    4,
    6,
    8,
    10,
    12,
    14,
    16,
    18,
    20,
    22
  ];

  _TappableLabel _buildTappableLabel(TextTheme textTheme, Color color,
      int value, String label, VoidCallback onTap) {
    final TextStyle style = textTheme.bodyText1!.copyWith(color: color);
    final double labelScaleFactor =
        math.min(MediaQuery.of(context).textScaleFactor, 2.0);
    return _TappableLabel(
      value: value,
      painter: TextPainter(
        text: TextSpan(style: style, text: label),
        textDirection: TextDirection.ltr,
        textScaleFactor: labelScaleFactor,
      )..layout(),
      onTap: onTap,
    );
  }

  List<_TappableLabel> _build24HourRing(TextTheme textTheme, Color color) =>
      <_TappableLabel>[
        for (final int hour in _twentyFourHours)
          _buildTappableLabel(
            textTheme,
            color,
            hour,
            hour.toString(),
            () {
              _selectValue(hour);
            },
          ),
      ];

  List<_TappableLabel> _buildMinutes(TextTheme textTheme, Color color) {
    const List<int> minuteMarkerValues = <int>[
      0,
      5,
      10,
      15,
      20,
      25,
      30,
      35,
      40,
      45,
      50,
      55
    ];

    return <_TappableLabel>[
      for (final int minute in minuteMarkerValues)
        _buildTappableLabel(
          textTheme,
          color,
          minute,
          minute.toString(),
          () {
            _selectValue(minute);
          },
        ),
    ];
  }

  List<_TappableLabel> _buildMSeconds(TextTheme textTheme, Color color) {
    const List<int> minuteMarkerValues = <int>[
      0,
      100,
      200,
      300,
      400,
      500,
      600,
      700,
      800,
      900
    ];

    return <_TappableLabel>[
      for (final int minute in minuteMarkerValues)
        _buildTappableLabel(
          textTheme,
          color,
          minute,
          minute.toString(),
          () {
            _selectValue(minute);
          },
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TimePickerThemeData pickerTheme = TimePickerTheme.of(context);
    final Color backgroundColor = pickerTheme.dialBackgroundColor ??
        themeData!.colorScheme.onBackground.withOpacity(0.12);
    final Color accentColor =
        pickerTheme.dialHandColor ?? themeData!.colorScheme.primary;
    final Color primaryLabelColor = MaterialStateProperty.resolveAs(
            pickerTheme.dialTextColor, <MaterialState>{}) ??
        themeData!.colorScheme.onSurface;
    final Color secondaryLabelColor = MaterialStateProperty.resolveAs(
            pickerTheme.dialTextColor,
            <MaterialState>{MaterialState.selected}) ??
        themeData!.colorScheme.onPrimary;
    List<_TappableLabel> primaryLabels;
    List<_TappableLabel> secondaryLabels;
    int selectedDialValue;
    switch (widget.mode) {
      case DurationPickerMode.Hour:
        selectedDialValue = widget.value;
        primaryLabels = _build24HourRing(theme.textTheme, primaryLabelColor);
        secondaryLabels =
            _build24HourRing(theme.textTheme, secondaryLabelColor);
        break;
      case DurationPickerMode.Minute:
        selectedDialValue = widget.value;
        primaryLabels = _buildMinutes(theme.textTheme, primaryLabelColor);
        secondaryLabels = _buildMinutes(theme.textTheme, secondaryLabelColor);
        break;
      case DurationPickerMode.Second:
        selectedDialValue = widget.value;
        primaryLabels = _buildMinutes(theme.textTheme, primaryLabelColor);
        secondaryLabels = _buildMinutes(theme.textTheme, secondaryLabelColor);
        break;
      case DurationPickerMode.MilliSecond:
        selectedDialValue = widget.value;
        primaryLabels = _buildMSeconds(theme.textTheme, primaryLabelColor);
        secondaryLabels = _buildMSeconds(theme.textTheme, secondaryLabelColor);
        break;
      case DurationPickerMode.MicroSecond:
        selectedDialValue = widget.value;
        primaryLabels = _buildMSeconds(theme.textTheme, primaryLabelColor);
        secondaryLabels = _buildMSeconds(theme.textTheme, secondaryLabelColor);
        break;
      default:
        selectedDialValue = -1;
        primaryLabels = <_TappableLabel>[];
        secondaryLabels = <_TappableLabel>[];
    }

    return GestureDetector(
      excludeFromSemantics: true,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      onPanEnd: _handlePanEnd,
      onTapUp: _handleTapUp,
      child: CustomPaint(
        key: const ValueKey<String>('duration-picker-dial'),
        painter: _DialPainterNew(
          selectedValue: selectedDialValue,
          primaryLabels: primaryLabels,
          secondaryLabels: secondaryLabels,
          backgroundColor: backgroundColor,
          accentColor: accentColor,
          dotColor: theme.colorScheme.surface,
          theta: _theta!.value,
          textDirection: Directionality.of(context),
        ),
      ),
    );
  }
}

/// A duration picker designed to appear inside a popup dialog.
///
/// Pass this widget to [showDialog]. The value returned by [showDialog] is the
/// selected [Duration] if the user taps the "Confirm" or "Default" button, or
/// null if the user taps the "CANCEL" button. The selected time is
/// reported by calling  [Navigator.pop].
class _DurationPickerDialog extends StatefulWidget {
  /// Creates a duration picker.
  ///
  /// [initialDuration] must not be null.
  ///
  /// [defaultDuration] must not be null.
  const _DurationPickerDialog({
    Key? key,
    required this.initialDuration,
    required this.defaultDuration,
    this.cancelText,
    this.confirmText,
    this.defaultText,
    this.showHead = true,
    this.durationPickerMode,
    this.allowedModes,
  }) : super(key: key);

  /// The duration initially selected when the dialog is shown.
  final Duration initialDuration;

  /// Optionally provide your own text for the cancel button.
  ///
  /// If null, the button uses "Done".
  final String? cancelText;

  /// Optionally provide your own text for the confirm button.
  ///
  /// If null, the button uses "Cancel".
  final String? confirmText;

  /// Optionally provide your own text for the default button.
  ///
  /// If null, the button uses "Default".
  final String? defaultText;

  final bool showHead;

  final DurationPickerMode? durationPickerMode;

  final Duration? defaultDuration;

  /// If null then all modes are allowed from Days to MicroSeconds.
  final List<DurationPickerMode>? allowedModes;

  @override
  _DurationPickerState createState() => _DurationPickerState();
}

class _DurationPickerState extends State<_DurationPickerDialog> {
  Duration? get selectedDuration => _selectedDuration;
  Duration? _selectedDuration;

  @override
  void initState() {
    super.initState();
    _selectedDuration = widget.initialDuration;
  }

  void _handleDurationChanged(Duration value) {
    setState(() {
      _selectedDuration = value;
    });
  }

  void _handleDefault() {
    if (widget.defaultDuration != null) {
      Navigator.pop(context, widget.defaultDuration);
    }
  }

  void _handleCancel() {
    Navigator.pop(context);
  }

  void _handleOk() {
    Navigator.pop(context, _selectedDuration ?? const Duration());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    /// Duration Picker Widget.
    final Widget picker = DurationPicker(
      duration: _selectedDuration ?? const Duration(),
      onChange: _handleDurationChanged,
      durationPickerMode: widget.durationPickerMode,
      showHead: widget.showHead,
      allowedModes: widget.allowedModes ??
          const [
            DurationPickerMode.Day,
            DurationPickerMode.Hour,
            DurationPickerMode.Minute,
            DurationPickerMode.Second,
            DurationPickerMode.MilliSecond,
            DurationPickerMode.MicroSecond,
          ],
    );

    /// Action Buttons - Cancel and OK
    final Widget actions = Container(
      margin: const EdgeInsets.only(top: _kDefaultPadding * 3),
      alignment: AlignmentDirectional.centerEnd,
      constraints: const BoxConstraints(minHeight: 42.0),
      child: OverflowBar(
        overflowAlignment: OverflowBarAlignment.end,
        children: <Widget>[
          if (widget.defaultDuration != null)
            TextButton(
              onPressed: _handleDefault,
              child: Text(widget.defaultText ?? 'Default'),
            ),
          TextButton(
            onPressed: _handleCancel,
            child: Text(widget.cancelText ?? 'Cancel'),
          ),
          TextButton(
            onPressed: _handleOk,
            child: Text(widget.confirmText ?? 'Done'),
          ),
        ],
      ),
    );

    /// Widget with Duration Picker Widget and Dialog as Actions - Default, Cancel and OK.
    final Widget pickerAndActions = SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          picker,
          actions,
        ],
      ),
    );

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      elevation: 3,
      child: Container(
        padding: const EdgeInsets.all(_kDefaultPadding * 3),
        child: OrientationBuilder(
          builder: (BuildContext context, Orientation orientation) {
            switch (orientation) {
              case Orientation.portrait:
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    pickerAndActions,
                  ],
                );
              case Orientation.landscape:
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    pickerAndActions,
                  ],
                );
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

void _announceToAccessibility(BuildContext context, String message) {
  SemanticsService.announce(message, Directionality.of(context));
}

/// Shows a dialog containing the duration picker.
///
/// The returned Future resolves to the duration selected by the user when the user
/// closes the dialog. If the user cancels the dialog, null is returned.
///
/// To show a dialog with [initialDuration] equal to the Duration with 0 milliseconds:
/// To show a dialog with [DurationPickerMode] equal to the Duration Mode like hour, second,etc.:
/// To show a dialog with [showHead] equal to boolean (Default is true) to show Head as Duration:
///
/// Optionally provide your own text for the confirm button [confirmText].
///
/// Optionally provide your own text for the cancel button [cancelText].
///
/// ```dart
/// showDurationPicker(
///   initialDuration: initialDuration,
///   durationPickerMode: durationPickerMode,
///   showHead: showHead,
///   confirmText: confirmText,
///   cancelText: cancelText,
///    );
/// ```
Future<Duration?> showDurationPicker({
  required BuildContext context,
  required Duration initialDuration,
  Duration? defaultDuration,
  DurationPickerMode? durationPickerMode,
  bool showHead = true,
  String? confirmText,
  String? cancelText,
  String? defaultText,
  List<DurationPickerMode>? allowedModes,
}) async {
  return await showDialog<Duration>(
    context: context,
    builder: (BuildContext context) => _DurationPickerDialog(
      initialDuration: initialDuration,
      defaultDuration: defaultDuration,
      durationPickerMode: durationPickerMode,
      showHead: showHead,
      confirmText: confirmText,
      cancelText: cancelText,
      defaultText: defaultText,
      allowedModes: allowedModes,
    ),
  );
}

/// A Widget for duration picker.
///
/// [duration] - a initial Duration for Duration Picker when not provided initialize with Duration().
/// [onChange] - a function to be called when duration changed and cannot be null.
/// [durationPickerMode] - Duration Picker Mode to show Widget with Days,  Hours, Minutes, Seconds, Milliseconds, Microseconds, By default Duration Picker Mode is Minute.
///
/// ```dart
/// DurationPicker(
///   duration: Duration(),
///   onChange: onChange,
/// );
/// ```
class DurationPicker extends StatefulWidget {
  final Duration duration;
  final ValueChanged<Duration> onChange;
  final DurationPickerMode? durationPickerMode;
  final bool showHead;
  final List<DurationPickerMode> allowedModes;

  const DurationPicker({
    Key? key,
    this.duration = const Duration(minutes: 0),
    required this.onChange,
    required this.showHead,
    required this.allowedModes,
    this.durationPickerMode,
  }) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _DurationPicker createState() => _DurationPicker();
}

class _DurationPicker extends State<DurationPicker> {
  late DurationPickerMode currentDurationType;

  int days = 0;
  int hours = 0;
  int minutes = 0;
  int seconds = 0;
  int milliseconds = 0;
  int microseconds = 0;
  int currentValue = 0;
  Duration duration = const Duration();

  @override
  void initState() {
    super.initState();
    currentDurationType =
        widget.durationPickerMode ?? DurationPickerMode.Minute;
    currentValue = getCurrentValue();
    days = widget.duration.inDays;
    hours = (widget.duration.inHours) % Duration.hoursPerDay;
    minutes = widget.duration.inMinutes % Duration.minutesPerHour;
    seconds = widget.duration.inSeconds % Duration.secondsPerMinute;
    milliseconds =
        widget.duration.inMilliseconds % Duration.millisecondsPerSecond;
    microseconds =
        widget.duration.inMicroseconds % Duration.microsecondsPerMillisecond;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.showHead) getCurrentSelectionTitleText(),
            currentDurationType == DurationPickerMode.Day
                ? Container(
                    margin: const EdgeInsets.symmetric(
                      vertical: _kDefaultPadding,
                    ),
                    width: 200,
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _ShowTimeArgs(
                          durationMode: DurationPickerMode.Day,
                          onChanged: updateValue,
                          onTextChanged: updateDurationFields,
                          value: days,
                          formatWidth: 2,
                          desc: 'Days',
                          start: 0,
                          end: -1,
                          allowedModes: widget.allowedModes,
                        ),
                      ],
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.only(top: _kDefaultPadding * 2),
                    //decoration: BoxDecoration(border: Border.all(width: 2)),
                    width: 200,
                    height: 200,
                    child: _Dial(
                      value: currentValue,
                      mode: currentDurationType,
                      onChanged: updateDurationFields,
                    ),
                  ),
            getFieldChanger(),
          ],
        ),
      ],
    );
  }

  /// Returns a material3 style IconButton
  Widget durationTypeChangeButton({
    required Function()? onPressed,
    required IconData iconData,
  }) {
    return IconButton(
      isSelected: onPressed != null,
      style: ButtonStyle(
        backgroundColor: MaterialStatePropertyAll(
          onPressed == null
              ? Theme.of(context).colorScheme.onSurface.withOpacity(0.12)
              : Theme.of(context).colorScheme.primary,
        ),
        elevation: const MaterialStatePropertyAll(0),
      ),
      onPressed: onPressed,
      icon: Icon(
        iconData,
        size: 24,
        color: onPressed == null
            ? Theme.of(context).colorScheme.onSurface.withOpacity(0.38)
            : Theme.of(context).colorScheme.onPrimary,
      ),
    );
  }

  Widget getFieldChanger() {
    return Container(
      margin: const EdgeInsets.only(top: _kDefaultPadding * 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        mainAxisSize: MainAxisSize.max,
        children: [
          currentDurationType == DurationPickerMode.Day
              ? durationTypeChangeButton(
                  onPressed: null,
                  iconData: Icons.keyboard_arrow_left_rounded,
                )
              : durationTypeChangeButton(
                  onPressed: () {
                    updateValue(_getPrevMode(
                      currentDurationType,
                      widget.allowedModes,
                    ));
                  },
                  iconData: Icons.keyboard_arrow_left_rounded,
                ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _kDefaultPadding),
            child: Text(
              '${describeEnum(currentDurationType)}s',
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ),
          currentDurationType == DurationPickerMode.Minute
              ? durationTypeChangeButton(
                  onPressed: null,
                  iconData: Icons.keyboard_arrow_right_rounded,
                )
              : durationTypeChangeButton(
                  onPressed: () {
                    updateValue(_getNextMode(
                      currentDurationType,
                      widget.allowedModes,
                    ));
                  },
                  iconData: Icons.keyboard_arrow_right_rounded,
                ),
        ],
      ),
    );
  }

  Widget getCurrentSelectionTitleText() {
    return Text(
      'Select ${describeEnum(currentDurationType)}s',
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
      textAlign: TextAlign.left,
    );
  }

  int getCurrentValue() {
    switch (currentDurationType) {
      case DurationPickerMode.Day:
        return days;
      case DurationPickerMode.Hour:
        return hours;
      case DurationPickerMode.Minute:
        return minutes;
      case DurationPickerMode.Second:
        return seconds;
      case DurationPickerMode.MilliSecond:
        return milliseconds;
      case DurationPickerMode.MicroSecond:
        return microseconds;
      default:
        return -1;
    }
  }

  void updateDurationFields(value) {
    setState(() {
      switch (currentDurationType) {
        case DurationPickerMode.Day:
          days = value;
          break;
        case DurationPickerMode.Hour:
          hours = value;
          break;
        case DurationPickerMode.Minute:
          minutes = value;
          break;
        case DurationPickerMode.Second:
          seconds = value;
          break;
        case DurationPickerMode.MilliSecond:
          milliseconds = value;
          break;
        case DurationPickerMode.MicroSecond:
          microseconds = value;
          break;
      }
      currentValue = value;
    });

    widget.onChange(Duration(
        days: days,
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
        microseconds: microseconds));
  }

  void updateValue(value) {
    setState(() {
      currentDurationType = value;
      currentValue = getCurrentValue();
    });
  }

  String getFormattedStringWithLeadingZeros(int number, int formatWidth) {
    var result = StringBuffer();
    while (formatWidth > 0) {
      int temp = number % 10;
      result.write(temp);
      number = (number ~/ 10);
      formatWidth--;
    }
    return result.toString();
  }
}

DurationPickerMode _getPrevMode(
  DurationPickerMode currentMode,
  final List<DurationPickerMode> allowedModes,
) {
  int currIdx = allowedModes.indexOf(currentMode);

  if (currIdx == -1) return currentMode;

  if (currIdx == 0) return allowedModes.last;

  return allowedModes[currIdx - 1];
}

DurationPickerMode _getNextMode(
  DurationPickerMode currentMode,
  final List<DurationPickerMode> allowedModes,
) {
  int currIdx = allowedModes.indexOf(currentMode);

  if (currIdx == -1) return currentMode;

  if (currIdx == allowedModes.length - 1) {
    return allowedModes.first;
  }

  return allowedModes[currIdx + 1];
}

class _ShowTimeArgs extends StatefulWidget {
  final int value;
  final int formatWidth;
  final String desc;
  final DurationPickerMode durationMode;
  final Function onChanged;
  final Function onTextChanged;
  final int start;
  final int end;
  final List<DurationPickerMode> allowedModes;

  const _ShowTimeArgs({
    required this.value,
    required this.formatWidth,
    required this.desc,
    required this.durationMode,
    required this.onChanged,
    required this.onTextChanged,
    required this.start,
    required this.end,
    required this.allowedModes,
  });

  @override
  _ShowTimeArgsState createState() => _ShowTimeArgsState();
}

class _ShowTimeArgsState extends State<_ShowTimeArgs> {
  TextEditingController? controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller = getTextEditingController(getFormattedText());
  }

  @override
  void initState() {
    super.initState();
    controller = getTextEditingController(getFormattedText());
  }

  @override
  void didUpdateWidget(_ShowTimeArgs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      controller = getTextEditingController(getFormattedText());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: getTextFormFieldWidth(widget.durationMode),
          child: RawKeyboardListener(
            focusNode: FocusNode(),
            onKey: (event) {
              if (event.runtimeType == RawKeyDownEvent) {
                switch (event.logicalKey.keyId) {
                  case 4295426091: //Enter Key ID from keyboard
                    widget.onChanged(_getNextMode(
                      widget.durationMode,
                      widget.allowedModes,
                    ));
                    break;
                  case 4295426130:
                    widget.onTextChanged(
                        (widget.value + 1) % (widget.end + 1) + widget.start);
                    break;
                  case 4295426129:
                    widget.onTextChanged(
                        (widget.value - 1) % (widget.end + 1) + widget.start);
                    break;
                }
              }
            },
            child: TextFormField(
              onChanged: (text) {
                if (text.trim() == '') {
                  text = '0';
                }
                widget.onTextChanged(int.parse(text));
              },
              inputFormatters: [
                FilteringTextInputFormatter.deny('\n'),
                FilteringTextInputFormatter.deny('\t'),
                _DurationFieldsFormatter(
                  start: widget.start,
                  end: widget.end,
                  useFinal: widget.durationMode != DurationPickerMode.Day,
                )
              ],
              controller: controller,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
            ),
          ),
        )
      ],
    );
  }

  double getTextFormFieldWidth(currentDurationField) {
    switch (currentDurationField) {
      case DurationPickerMode.Hour:
      case DurationPickerMode.Minute:
      case DurationPickerMode.Second:
        return 45;
      case DurationPickerMode.MilliSecond:
      case DurationPickerMode.MicroSecond:
        return 56;
      case DurationPickerMode.Day:
        return 100;
      default:
        return 0;
    }
  }

  String getFormattedText() {
    return widget.value.toString();
  }

  TextEditingController getTextEditingController(value) {
    return TextEditingController.fromValue(TextEditingValue(
        text: value, selection: TextSelection.collapsed(offset: value.length)));
  }

  String getFormattedStringWithLeadingZeros(int number, int formatWidth) {
    var result = StringBuffer();
    while (formatWidth > 0) {
      int temp = number % 10;
      result.write(temp);
      number = (number ~/ 10);
      formatWidth--;
    }
    return result.toString().split('').reversed.join();
  }
}

class _DurationFieldsFormatter extends TextInputFormatter {
  final int? start;
  final int? end;
  final bool? useFinal;

  _DurationFieldsFormatter({this.start, this.end, this.useFinal});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final String text = newValue.text;
    int selectionIndex = newValue.selection.end;
    int value = 0;
    try {
      if (text.trim() != '') {
        value = int.parse(text);
      }
    } catch (ex) {
      return oldValue;
    }

    if (value == 0) {
      return newValue;
    }

    if (!(start! <= value && (!useFinal! || value <= end!))) {
      return oldValue;
    }
    return newValue.copyWith(
      text: value.toString(),
      selection: TextSelection.collapsed(offset: selectionIndex),
    );
  }
}
