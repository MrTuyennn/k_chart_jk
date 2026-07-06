part of '../indicator_template.dart';

/// OBV — On-Balance Volume
///
/// Công thức:
/// ```
///   obv[0] = vol[0]
///   obv[i] = obv[i-1] + vol[i]   nếu close[i] > close[i-1]  (nến tăng → cộng vol)
///   obv[i] = obv[i-1] - vol[i]   nếu close[i] < close[i-1]  (nến giảm → trừ vol)
///   obv[i] = obv[i-1]            nếu close[i] == close[i-1] (không đổi)
///
///   signal = SMA(obv, calcParams[0])  — mặc định MA5
/// ```
///
/// Cách đọc tín hiệu:
///   - OBV tăng + giá tăng  → xu hướng được xác nhận
///   - OBV tăng + giá đi ngang/giảm → bullish divergence (tiền đang vào)
///   - OBV giảm + giá giảm  → xu hướng giảm được xác nhận
///   - OBV giảm + giá đi ngang/tăng → bearish divergence (tiền đang thoát)
///
/// Tham số:
///   `calcParams[0]` = period của signal MA (mặc định 5)
///
/// Generic type T = MACDEntity (nhất quán với RSI/KDJ/WR/CCI) thay vì OBVEntity.
/// Lý do: MACDEntity khai báo `on OBVEntity` nên có thể truy cập .obv / .obvSignal
/// trực tiếp không cần cast. Nhờ đó OBVIndicator fit vào
/// `List<SecondaryIndicator<MACDEntity, dynamic>>` mà không gây lỗi type.
class OBVIndicator extends SecondaryIndicator<MACDEntity, OBVStyle> {
  // Paint cho đường OBV chính (màu obvColor)
  late final Paint _linePaint;
  // Paint cho đường signal MA (màu signalColor)
  late final Paint _signalPaint;

  OBVIndicator({OBVStyle indicatorStyle = const OBVStyle()})
    : super(
        name: 'onBalanceVolume',
        shortName: 'OBV',
        calcParams: const [5], // MA5 signal mặc định
        indicatorStyle: indicatorStyle,
      ) {
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = indicatorStyle.lineWidth;
    _signalPaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = indicatorStyle.lineWidth;
  }

  /// Trả về min/max trong vùng hiển thị để secondary renderer scale đúng
  @override
  (double, double) getMaxMinValue(KLineEntity entity, double minV, double maxV) {
    if (entity.obv != null) {
      minV = min(minV, entity.obv!);
      maxV = max(maxV, entity.obv!);
    }
    if (entity.obvSignal != null) {
      minV = min(minV, entity.obvSignal!);
      maxV = max(maxV, entity.obvSignal!);
    }
    return (minV, maxV);
  }

  /// Label text hiển thị ở đầu panel khi scroll / long press
  /// Dùng formatCompact vì OBV là giá trị tích lũy — có thể rất lớn
  @override
  TextSpan? drawFigure(MACDEntity entity, int precision, KChartColors chartColors) {
    return TextSpan(
      children: [
        TextSpan(
          text: 'OBV(${calcParams[0]}) ',
          style: getTextStyle(chartColors.defaultTextColor),
        ),
        if (entity.obv != null)
          TextSpan(
            text: 'OBV:${NumberUtil.formatCompact(entity.obv!)}  ',
            style: getTextStyle(indicatorStyle.obvColor),
          ),
        if (entity.obvSignal != null)
          TextSpan(
            text: 'MA${calcParams[0]}:${NumberUtil.formatCompact(entity.obvSignal!)}',
            style: getTextStyle(indicatorStyle.signalColor),
          ),
      ],
    );
  }

  /// Nhãn giá max/min bên phải panel (dùng compact vì OBV rất lớn)
  @override
  void drawVerticalText({
    required Canvas canvas,
    required TextStyle style,
    required double maxValue,
    required double minValue,
    required int fixedLength,
    required Rect chartRect,
  }) {
    final maxTp = TextPainter(
      text: TextSpan(text: NumberUtil.formatCompact(maxValue), style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final minTp = TextPainter(
      text: TextSpan(text: NumberUtil.formatCompact(minValue), style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(canvas, Offset(chartRect.width - maxTp.width, chartRect.top));
    minTp.paint(canvas, Offset(chartRect.width - minTp.width, chartRect.bottom - minTp.height));
  }

  /// Vẽ 2 đường: OBV chính và signal MA
  @override
  void drawChart(
    MACDEntity lastPoint,
    MACDEntity curPoint,
    double lastX,
    double curX,
    GetYFunction getY,
    Canvas canvas,
    KChartColors chartColors,
  ) {
    // Đường OBV chính
    if (curPoint.obv != null && lastPoint.obv != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.obv!)),
        Offset(curX, getY(curPoint.obv!)),
        _linePaint..color = indicatorStyle.obvColor,
      );
    }
    // Đường signal MA — chỉ vẽ từ nến đủ period trở đi
    if (curPoint.obvSignal != null && lastPoint.obvSignal != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.obvSignal!)),
        Offset(curX, getY(curPoint.obvSignal!)),
        _signalPaint..color = indicatorStyle.signalColor,
      );
    }
  }

  /// Tính OBV tích lũy và signal MA trên toàn bộ dataList.
  /// Gọi một lần qua DataUtil.calculateAll() trước khi render.
  @override
  void calc(List<KLineEntity> dataList) {
    final period = calcParams[0]; // period của signal MA
    double obvSum = 0;

    for (int i = 0; i < dataList.length; i++) {
      final cur = dataList[i];

      // Tính OBV tích lũy
      if (i == 0) {
        obvSum = cur.vol; // nến đầu tiên: khởi tạo bằng vol của nó
      } else {
        final prev = dataList[i - 1];
        if (cur.close > prev.close) {
          obvSum += cur.vol; // nến tăng: cộng dồn vol
        } else if (cur.close < prev.close) {
          obvSum -= cur.vol; // nến giảm: trừ vol
        }
        // close bằng nhau: OBV không đổi
      }
      cur.obv = obvSum;

      // Tính signal = SMA(obv, period) — chỉ tính từ khi đủ period nến
      if (i >= period - 1) {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += dataList[j].obv!;
        }
        cur.obvSignal = sum / period;
      }
    }
  }
}
