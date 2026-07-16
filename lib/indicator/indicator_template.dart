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

  /// Snapshot của [indicatorStyle] tại thời điểm khởi tạo — dùng để phát hiện
  /// "caller có tự truyền indicatorStyle riêng không", KHÔNG dùng giá trị
  /// hiện tại của [indicatorStyle] (vì [applyIndicatorColorStyles] đã ghi đè
  /// nó rồi thì so với giá trị hiện tại sẽ luôn sai — xem [applyIndicatorColorStyles]).
  final K _originalIndicatorStyle;

  IndicatorTemplate({
    required this.name,
    required this.shortName,
    required this.calcParams,
    required this.indicatorStyle,
  }) : _originalIndicatorStyle = indicatorStyle;

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
    Color? color, [
    TextStyle base = const TextStyle(fontSize: 10),
    bool forceColor = false,
  ]) {
    if (!forceColor && base.color != null) return base;
    return base.copyWith(color: color);
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
/// NGUYÊN — không bị `KChartColors` ghi đè. Phát hiện qua `identical()` với
/// [IndicatorTemplate._originalIndicatorStyle] — snapshot chụp 1 lần lúc khởi
/// tạo, KHÔNG phải giá trị `indicatorStyle` hiện tại. Quan trọng vì hàm này
/// chạy lại mỗi lần `ChartPainter` được dựng (mỗi build/repaint): nếu so với
/// `indicatorStyle` hiện tại, sau lần gán đầu tiên nó không còn `identical`
/// với default const nữa → các lần build sau sẽ không bao giờ áp lại màu mới
/// dù `KChartColors` đã đổi (vd đổi theme). So với snapshot bất biến thì mỗi
/// build đều tự quyết định lại đúng, không bị "đơ" màu sau lần đầu.
void applyIndicatorColorStyles(
  List<MainIndicator> mainIndicators,
  List<SecondaryIndicator> secondaryIndicators,
  KChartColors colors,
) {
  for (final ind in mainIndicators) {
    switch (ind) {
      case MAIndicator m:
        _applyDefaultStyle(m, const MAStyle(), colors.maStyle);
      case EMAIndicator m:
        _applyDefaultStyle(m, const MAStyle(), colors.emaStyle);
      case BOLLIndicator m:
        _applyDefaultStyle(m, const BOLLStyle(), colors.bollStyle);
      case SARIndicator m:
        _applyDefaultStyle(m, const SARStyle(), colors.sarStyle);
      case ZigZagIndicator m:
        _applyDefaultStyle(m, const ZigZagStyle(), colors.zigzagStyle);
      case SuperTrendIndicator m:
        _applyDefaultStyle(m, const SuperTrendStyle(), colors.superTrendStyle);
      case AVLIndicator m:
        _applyDefaultStyle(m, const AVLStyle(), colors.avlStyle);
    }
  }
  for (final ind in secondaryIndicators) {
    switch (ind) {
      case MACDIndicator s:
        _applyDefaultStyle(s, const MACDStyle(), colors.macdStyle);
      case KDJIndicator s:
        _applyDefaultStyle(s, const KDJStyle(), colors.kdjStyle);
      case RSIIndicator s:
        _applyDefaultStyle(s, const RSIStyle(), colors.rsiStyle);
      case WRIndicator s:
        _applyDefaultStyle(s, const WRStyle(), colors.wrStyle);
      case CCIIndicator s:
        _applyDefaultStyle(s, const CCIStyle(), colors.cciStyle);
      case OBVIndicator s:
        _applyDefaultStyle(s, const OBVStyle(), colors.obvStyle);
      case TRIXIndicator s:
        _applyDefaultStyle(s, const TRIXStyle(), colors.trixStyle);
      case MTMIndicator s:
        _applyDefaultStyle(s, const MTMStyle(), colors.mtmStyle);
      case StochRSIIndicator s:
        _applyDefaultStyle(s, const StochRSIStyle(), colors.stochRsiStyle);
    }
  }
}

/// Gán [override] vào `ind.indicatorStyle` chỉ khi instance chưa từng được
/// caller tự truyền `indicatorStyle` riêng (so bằng `_originalIndicatorStyle`
/// snapshot, không phải giá trị `indicatorStyle` hiện tại — xem giải thích ở
/// [applyIndicatorColorStyles]).
void _applyDefaultStyle<K>(
  IndicatorTemplate<dynamic, K> ind,
  K defaultStyle,
  K override,
) {
  if (identical(ind._originalIndicatorStyle, defaultStyle)) {
    ind.indicatorStyle = override;
  }
}
