import 'package:k_chart_wikex/indicator/indicator_template.dart';

/// Base Dimension
class BaseDimension {
  // chiều cao vùng main chart (nến + main indicators)
  late double _mBaseHeight;
  // chiều cao panel volume (0 khi volHidden = true)
  late double _mVolumeHeight;
  // chiều cao mỗi panel secondary indicator (MACD/RSI/…)
  late double _mSecondaryHeight;
  late double _totalSecondaryHeight;

  final double _mLabelHeight = 12;
  double _totalLabelHeight = 12;

  // mDisplayHeight = mBaseHeight + mVolumeHeight + totalSecondaryHeight + totalLabelHeight
  double _mDisplayHeight = 0;

  double get mVolumeHeight => _mVolumeHeight;

  double get mSecondaryHeight => _mSecondaryHeight;
  double get totalSecondaryHeight => _totalSecondaryHeight;

  double get mLabelHeight => _mLabelHeight;
  double get totalLabelHeight => _totalLabelHeight;

  double get mDisplayHeight => _mDisplayHeight;

  BaseDimension({
    required double mBaseHeight,
    required double mSecondaryHeight,
    required bool volHidden,
    required List<SecondaryIndicator> secondaryIndicators,
    required List<MainIndicator> mainIndicators,
  }) {
    _mBaseHeight = mBaseHeight;
    _mVolumeHeight = volHidden ? 0 : mSecondaryHeight;
    _mSecondaryHeight = mSecondaryHeight;

    _totalSecondaryHeight = _mSecondaryHeight * secondaryIndicators.length;
    _totalLabelHeight = _mLabelHeight * mainIndicators.length;

    _mDisplayHeight = _mBaseHeight +
        _mVolumeHeight +
        _totalSecondaryHeight +
        _totalLabelHeight;
  }
}
