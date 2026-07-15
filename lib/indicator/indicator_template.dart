import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:k_chart_wikex/entity/index.dart';
import 'package:k_chart_wikex/renderer/index.dart';
import 'package:k_chart_wikex/utils/index.dart';

import 'indicator_style.dart';
export 'indicator_style.dart';

part 'main/sar_indicator.dart';
part 'main/ma_indicator.dart';
part 'main/boll_indicator.dart';
part 'main/ema_indicator.dart';
part 'main/zigzag_indicator.dart';
part 'main/super_trend_indicator.dart';
part 'main/avl_indicator.dart';

part 'secondary/macd_indicator.dart';
part 'secondary/cci_indicator.dart';
part 'secondary/kdj_indicator.dart';
part 'secondary/rsi_indicator.dart';
part 'secondary/wr_indicator.dart';
part 'secondary/obv_indicator.dart';
part 'secondary/trix_indicator.dart';
part 'secondary/mtm_indicator.dart';
part 'secondary/stoch_rsi_indicator.dart';

typedef GetYFunction = double Function(double y);

abstract class IndicatorTemplate<T, K> {
  final String name;

  final String shortName;

  final List<int> calcParams;

  /// Không `final` — cho phép [applyIndicatorColorStyles] override bằng style
  /// khai báo trong `KChartColors` khi instance vẫn còn dùng default `const`.
  K indicatorStyle;

  IndicatorTemplate({
    required this.name,
    required this.shortName,
    required this.calcParams,
    required this.indicatorStyle,
  });

  /// record.$1 : min value
  /// record.$2: max value
  (double, double) getMaxMinValue(KLineEntity entity, double minV, double maxV);

  TextSpan? drawFigure(T value, int precision, KChartColors chartColors);

  void drawChart(
    T lastPoint,
    T curPoint,
    double lastX,
    double curX,
    GetYFunction getY,
    Canvas canvas,
    KChartColors chartColors,
  );

  void calc(List<KLineEntity> dataList);

  /// text format
  TextStyle getTextStyle(Color? color) {
    return TextStyle(fontSize: 10, color: color);
  }

  String formatNumber(double value, int precision) {
    return NumberUtil.format(value, precision) ?? '--';
  }
}

abstract class MainIndicator<T, K> extends IndicatorTemplate<T, K> {
  MainIndicator({
    required super.name,
    required super.shortName,
    required super.calcParams,
    required super.indicatorStyle,
  });
}

abstract class SecondaryIndicator<T, K> extends IndicatorTemplate<T, K> {
  SecondaryIndicator({
    required super.name,
    required super.shortName,
    required super.calcParams,
    required super.indicatorStyle,
  });

  /// Các mốc ngang tham chiếu vẽ nét đứt trong panel (vd [20, 80] cho StochRSI).
  /// Mặc định rỗng — không vẽ gì. SecondaryRenderer vẽ 1 lần mỗi frame,
  /// phía sau đường indicator, không phụ thuộc hideGrid.
  List<double> get referenceValues => const [];

  void drawVerticalText({
    required Canvas canvas,
    required TextStyle style,
    required double maxValue,
    required double minValue,
    required int fixedLength,
    required Rect chartRect,
  });
}

/// Áp style theo `KChartColors` (vd `colors.avlStyle`, `colors.maStyle`...) cho
/// những indicator instance vẫn còn dùng style mặc định — tức caller khởi tạo
/// kiểu `AVLIndicator()` mà không tự truyền `indicatorStyle` riêng. Cho phép
/// cấu hình màu toàn bộ indicator từ một chỗ duy nhất (`KChartColors`) khi build
/// `KChartWidget`, thay vì phải set rời `indicatorStyle` ở từng instance.
///
/// Instance nào đã tự truyền `indicatorStyle` khác `const` mặc định (vd
/// `AVLIndicator(indicatorStyle: AVLStyle(avlColor: Colors.purple))`) thì GIỮ
/// NGUYÊN — không bị `KChartColors` ghi đè. Phát hiện qua `identical()` vì các
/// class Style đều `const` — hai lần gọi `const AVLStyle()` cho cùng 1 object
/// đã được Dart canonical hoá.
void applyIndicatorColorStyles(
  List<MainIndicator> mainIndicators,
  List<SecondaryIndicator> secondaryIndicators,
  KChartColors colors,
) {
  for (final ind in mainIndicators) {
    switch (ind) {
      case MAIndicator m:
        if (identical(m.indicatorStyle, const MAStyle())) {
          m.indicatorStyle = colors.maStyle;
        }
      case EMAIndicator m:
        if (identical(m.indicatorStyle, const MAStyle())) {
          m.indicatorStyle = colors.emaStyle;
        }
      case BOLLIndicator m:
        if (identical(m.indicatorStyle, const BOLLStyle())) {
          m.indicatorStyle = colors.bollStyle;
        }
      case SARIndicator m:
        if (identical(m.indicatorStyle, const SARStyle())) {
          m.indicatorStyle = colors.sarStyle;
        }
      case ZigZagIndicator m:
        if (identical(m.indicatorStyle, const ZigZagStyle())) {
          m.indicatorStyle = colors.zigzagStyle;
        }
      case SuperTrendIndicator m:
        if (identical(m.indicatorStyle, const SuperTrendStyle())) {
          m.indicatorStyle = colors.superTrendStyle;
        }
      case AVLIndicator m:
        if (identical(m.indicatorStyle, const AVLStyle())) {
          m.indicatorStyle = colors.avlStyle;
        }
    }
  }
  for (final ind in secondaryIndicators) {
    switch (ind) {
      case MACDIndicator s:
        if (identical(s.indicatorStyle, const MACDStyle())) {
          s.indicatorStyle = colors.macdStyle;
        }
      case KDJIndicator s:
        if (identical(s.indicatorStyle, const KDJStyle())) {
          s.indicatorStyle = colors.kdjStyle;
        }
      case RSIIndicator s:
        if (identical(s.indicatorStyle, const RSIStyle())) {
          s.indicatorStyle = colors.rsiStyle;
        }
      case WRIndicator s:
        if (identical(s.indicatorStyle, const WRStyle())) {
          s.indicatorStyle = colors.wrStyle;
        }
      case CCIIndicator s:
        if (identical(s.indicatorStyle, const CCIStyle())) {
          s.indicatorStyle = colors.cciStyle;
        }
      case OBVIndicator s:
        if (identical(s.indicatorStyle, const OBVStyle())) {
          s.indicatorStyle = colors.obvStyle;
        }
      case TRIXIndicator s:
        if (identical(s.indicatorStyle, const TRIXStyle())) {
          s.indicatorStyle = colors.trixStyle;
        }
      case MTMIndicator s:
        if (identical(s.indicatorStyle, const MTMStyle())) {
          s.indicatorStyle = colors.mtmStyle;
        }
      case StochRSIIndicator s:
        if (identical(s.indicatorStyle, const StochRSIStyle())) {
          s.indicatorStyle = colors.stochRsiStyle;
        }
    }
  }
}
