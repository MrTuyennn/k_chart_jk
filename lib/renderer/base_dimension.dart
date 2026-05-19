import 'package:k_chart_wikex/indicator/indicator_template.dart';

/// Base Dimension
class BaseDimension {
  // the height of base chart
  late double _mBaseHeight;
  // default: 0
  // the height of volume chart
  late double _mVolumeHeight;
  // default: 0
  // the height of a secondary chart
  late double _mSecondaryHeight;
  late double _totalSecondaryHeight;

  final double _mLabelHeight = 12;
  double _totalLabelHeight = 12;

  // total height of chart: _mBaseHeight + _mVolumeHeight + (_mSecondaryHeight * n)
  // n : number of secondary charts
  //
  double _mDisplayHeight = 0;

  // getter the vol height
  double get mVolumeHeight => _mVolumeHeight;

  // getter the secondary height
  double get mSecondaryHeight => _mSecondaryHeight;
  double get totalSecondaryHeight => _totalSecondaryHeight;

  double get mLabelHeight => _mLabelHeight;
  double get totalLabelHeight => _totalLabelHeight;

  // getter the total height
  double get mDisplayHeight => _mDisplayHeight;

  /// constructor
  ///
  /// BaseDimension
  /// set _mBaseHeight
  /// compute value of _mVolumeHeight, _mSecondaryHeight, _mDisplayHeight
  BaseDimension({
    required double mBaseHeight,
    required double mSecondaryHeight,
    required bool volHidden,
    required List<SecondaryIndicator> secondaryIndicators,
    required List<MainIndicator> mainIndicators,
  }) {
    _mBaseHeight = mBaseHeight;
    // TODO: bật lại nếu muốn volume có panel riêng bên dưới chart chính
    // _mVolumeHeight = volHidden != true ? mSecondaryHeight : 0;
    _mVolumeHeight = 0; // volume gộp vào main chart dưới dạng overlay
    _mSecondaryHeight = mSecondaryHeight;

    _totalSecondaryHeight = _mSecondaryHeight * secondaryIndicators.length;
    _totalLabelHeight = _mLabelHeight * mainIndicators.length;

    _mDisplayHeight =
        _mBaseHeight +
        _mVolumeHeight +
        _totalSecondaryHeight +
        _totalLabelHeight;
  }
}
