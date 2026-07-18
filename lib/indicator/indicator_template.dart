import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:k_chart_jk/entity/index.dart';
import 'package:k_chart_jk/renderer/index.dart';
import 'package:k_chart_jk/utils/index.dart';

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
part 'secondary/brar_indicator.dart';
part 'secondary/bias_indicator.dart';

typedef GetYFunction = double Function(double y);

abstract class IndicatorTemplate<T, K> {
  final String name;

  final String shortName;

  final List<int> calcParams;

  /// Không `final` — cho phép [applyIndicatorColorStyles] override bằng style
  /// khai báo trong `KChartColors` khi instance vẫn còn dùng default `const`.
  K indicatorStyle;

  /// true khi caller KHÔNG tự truyền `indicatorStyle` (constructor nhận `null`
  /// và tự resolve về default `const XxxStyle()`) — dùng để phát hiện "caller
  /// có tự truyền indicatorStyle riêng không". Cờ tường minh thay vì so sánh
  /// `identical()` với 1 giá trị `const` mới dựng, vì Dart const-canonicalization
  /// khiến `identical()` luôn đúng ngay cả khi caller CHỦ ĐỘNG truyền
  /// `const XxxStyle()` với field y hệt default — trường hợp đó vẫn bị nhận
  /// nhầm là "chưa customize" và bị [applyIndicatorColorStyles] ghi đè.
  final bool isDefaultStyle;

  IndicatorTemplate({
    required this.name,
    required this.shortName,
    required this.calcParams,
    required this.indicatorStyle,
    required this.isDefaultStyle,
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

  /// text format — [base] mặc định fontSize 10; `drawFigure` truyền
  /// `indicatorStyle.textStyle` (mỗi indicator tự có `textStyle` riêng trong
  /// `XxxStyle`, đặt trong `IndicatorStyle` base class) để label theo đúng
  /// font đã cấu hình cho indicator đó.
  ///
  /// [forceColor] = true: LUÔN dùng [color] truyền vào, bỏ qua `base.color`
  /// dù đã set — dùng cho label mà màu mang ý nghĩa riêng (khớp màu đường
  /// tương ứng, vd K/D/J của KDJ, MACD/DIF/DEA) — không được đồng loạt bị
  /// `textStyle.color` ghi đè như prefix tên indicator (`"KDJ(9,1,3) "`...).
  TextStyle getTextStyle(
    Color? color, {
    TextStyle base = const TextStyle(fontSize: 10),
    bool forceColor = false,
  }) =>
      resolveTextStyle(base, color, forceColor: forceColor);

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
    required super.isDefaultStyle,
  });
}

abstract class SecondaryIndicator<T, K> extends IndicatorTemplate<T, K> {
  SecondaryIndicator({
    required super.name,
    required super.shortName,
    required super.calcParams,
    required super.indicatorStyle,
    required super.isDefaultStyle,
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
/// NGUYÊN — không bị `KChartColors` ghi đè. Phát hiện qua cờ tường minh
/// [IndicatorTemplate.isDefaultStyle] (set 1 lần lúc khởi tạo dựa trên
/// constructor có nhận `null` hay không), KHÔNG so `identical()` với giá trị
/// hiện tại của `indicatorStyle` — sau lần gán đầu tiên nó không còn giữ
/// nguyên giá trị khởi tạo nữa nên so với hiện tại sẽ luôn sai. Hàm này chạy
/// lại mỗi lần `ChartPainter` được dựng (mỗi build/repaint); vì `isDefaultStyle`
/// bất biến, mỗi build đều tự quyết định lại đúng, không bị "đơ" màu sau lần đầu.
///
/// Bản thân hàm này (switch + gán) tốn chi phí không đáng kể mỗi lần gọi —
/// nhưng `ChartPainter` được dựng lại mỗi build/tick giá, nên vẫn cache theo
/// `identical()` của bộ 3 tham số để bỏ qua hoàn toàn khi
/// `mainIndicators`/`secondaryIndicators`/`colors` chưa đổi giữa 2 lần gọi
/// liên tiếp (trường hợp phổ biến nhất: rebuild do tick giá, không đổi style).
List<MainIndicator>? _lastMainIndicators;
List<SecondaryIndicator>? _lastSecondaryIndicators;
KChartColors? _lastColors;

void applyIndicatorColorStyles(
  List<MainIndicator> mainIndicators,
  List<SecondaryIndicator> secondaryIndicators,
  KChartColors colors,
) {
  if (identical(_lastMainIndicators, mainIndicators) &&
      identical(_lastSecondaryIndicators, secondaryIndicators) &&
      identical(_lastColors, colors)) {
    return;
  }
  _lastMainIndicators = mainIndicators;
  _lastSecondaryIndicators = secondaryIndicators;
  _lastColors = colors;

  for (final ind in mainIndicators) {
    switch (ind) {
      case MAIndicator m:
        _applyDefaultStyle(m, colors.maStyle);
      case EMAIndicator m:
        _applyDefaultStyle(m, colors.emaStyle);
      case BOLLIndicator m:
        _applyDefaultStyle(m, colors.bollStyle);
      case SARIndicator m:
        _applyDefaultStyle(m, colors.sarStyle);
      case ZigZagIndicator m:
        _applyDefaultStyle(m, colors.zigzagStyle);
      case SuperTrendIndicator m:
        _applyDefaultStyle(m, colors.superTrendStyle);
      case AVLIndicator m:
        _applyDefaultStyle(m, colors.avlStyle);
    }
  }
  for (final ind in secondaryIndicators) {
    switch (ind) {
      case MACDIndicator s:
        _applyDefaultStyle(s, colors.macdStyle);
      case KDJIndicator s:
        _applyDefaultStyle(s, colors.kdjStyle);
      case RSIIndicator s:
        _applyDefaultStyle(s, colors.rsiStyle);
      case WRIndicator s:
        _applyDefaultStyle(s, colors.wrStyle);
      case CCIIndicator s:
        _applyDefaultStyle(s, colors.cciStyle);
      case OBVIndicator s:
        _applyDefaultStyle(s, colors.obvStyle);
      case TRIXIndicator s:
        _applyDefaultStyle(s, colors.trixStyle);
      case MTMIndicator s:
        _applyDefaultStyle(s, colors.mtmStyle);
      case StochRSIIndicator s:
        _applyDefaultStyle(s, colors.stochRsiStyle);
      case BRARIndicator s:
        _applyDefaultStyle(s, colors.brarStyle);
      case BIASIndicator s:
        _applyDefaultStyle(s, colors.biasStyle);
    }
  }
}

/// Gán [override] vào `ind.indicatorStyle` chỉ khi instance chưa từng được
/// caller tự truyền `indicatorStyle` riêng (xem [IndicatorTemplate.isDefaultStyle]).
void _applyDefaultStyle<K>(
  IndicatorTemplate<dynamic, K> ind,
  K override,
) {
  if (ind.isDefaultStyle) {
    ind.indicatorStyle = override;
  }
}
