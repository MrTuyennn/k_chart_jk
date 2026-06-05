import 'package:k_chart_wikex/indicator/indicator_template.dart';

/// Base Dimension
class BaseDimension {
  // chiều cao vùng main chart (nến + main indicators)
  late double _mBaseHeight;
  // chiều cao mỗi panel secondary indicator (VOL/MACD/RSI/…)
  late double _mSecondaryHeight;
  late double _totalSecondaryHeight;

  final double _mLabelHeight = 12;
  double _totalLabelHeight = 12;

  // tổng chiều cao chart: _mBaseHeight + (_mSecondaryHeight × n) + labelHeight
  // n: số secondary indicator
  double _mDisplayHeight = 0;

  double get mSecondaryHeight => _mSecondaryHeight;
  double get totalSecondaryHeight => _totalSecondaryHeight;

  double get mLabelHeight => _mLabelHeight;
  double get totalLabelHeight => _totalLabelHeight;

  double get mDisplayHeight => _mDisplayHeight;

  BaseDimension({
    required double mBaseHeight,
    required double mSecondaryHeight,
    required List<SecondaryIndicator> secondaryIndicators,
    required List<MainIndicator> mainIndicators,
  }) {
    _mBaseHeight = mBaseHeight;
    _mSecondaryHeight = mSecondaryHeight;

    _totalSecondaryHeight = _mSecondaryHeight * secondaryIndicators.length;
    _totalLabelHeight = _mLabelHeight * mainIndicators.length;

    _mDisplayHeight = _mBaseHeight + _totalSecondaryHeight + _totalLabelHeight;
  }
}
