part of '../indicator_template.dart';

/// ATR — Average True Range (Wilder, 1978)
/// 参数：N（Wilder 平滑周期），M（信号线MA周期），默认 14、6。
/// 公式：TR = MAX(HIGH-LOW, ABS(HIGH-REF(CLOSE,1)), ABS(LOW-REF(CLOSE,1)))
///      ATR[0] = SMA(TR, N)（前 N 个 TR 的简单平均，作为 Wilder 平滑的种子值）
///      ATR[i] = (TR[i] + (N-1) × ATR[i-1]) / N   (i >= N)
///      MAATR = MA(ATR, M)
class ATRIndicator extends SecondaryIndicator<MACDEntity, ATRStyle> {
  late final Paint _linePaint;
  late final Paint _maPaint;

  ATRIndicator({ATRStyle? indicatorStyle})
    : super(
        name: 'averageTrueRange',
        shortName: 'ATR',
        calcParams: const [14, 6],
        indicatorStyle: indicatorStyle ?? const ATRStyle(),
        isDefaultStyle: indicatorStyle == null,
      ) {
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = this.indicatorStyle.lineWidth;
    _maPaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = this.indicatorStyle.lineWidth;
  }

  @override
  (double, double) getMaxMinValue(
    KLineEntity entity,
    double minV,
    double maxV,
  ) {
    if (entity.atr != null) {
      minV = min(minV, entity.atr!);
      maxV = max(maxV, entity.atr!);
    }
    if (entity.atrMa != null) {
      minV = min(minV, entity.atrMa!);
      maxV = max(maxV, entity.atrMa!);
    }
    return (minV, maxV);
  }

  @override
  TextSpan? drawFigure(
    MACDEntity entity,
    int precision,
    KChartColors chartColors,
  ) {
    return TextSpan(
      children: [
        TextSpan(
          text: "ATR(${calcParams[0]},${calcParams[1]}) ",
          style: getTextStyle(
            chartColors.defaultTextColor,
            base: indicatorStyle.textStyle,
          ),
        ),
        if (entity.atr != null)
          TextSpan(
            text: "ATR:${formatNumber(entity.atr!, precision)}  ",
            style: getTextStyle(
              indicatorStyle.atrColor,
              base: indicatorStyle.textStyle,
              forceColor: true,
            ),
          ),
        if (entity.atrMa != null)
          TextSpan(
            text: "MAATR:${formatNumber(entity.atrMa!, precision)}",
            style: getTextStyle(
              indicatorStyle.atrMaColor,
              base: indicatorStyle.textStyle,
              forceColor: true,
            ),
          ),
      ],
    );
  }

  @override
  void drawVerticalText({
    required Canvas canvas,
    required TextStyle style,
    required double maxValue,
    required double minValue,
    required int fixedLength,
    required Rect chartRect,
  }) {
    TextPainter maxTp = TextPainter(
      text: TextSpan(
        text: NumberUtil.formatFixed(maxValue, fixedLength) ?? '',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    );
    maxTp.layout();

    TextPainter minTp = TextPainter(
      text: TextSpan(
        text: NumberUtil.formatFixed(minValue, fixedLength) ?? '',
        style: style,
      ),
      textDirection: TextDirection.ltr,
    );
    minTp.layout();

    maxTp.paint(canvas, Offset(chartRect.width - maxTp.width, chartRect.top));
    minTp.paint(
      canvas,
      Offset(chartRect.width - minTp.width, chartRect.bottom - minTp.height),
    );
  }

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
    if (lastPoint.atr != null && curPoint.atr != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.atr!)),
        Offset(curX, getY(curPoint.atr!)),
        _linePaint..color = indicatorStyle.atrColor,
      );
    }
    if (lastPoint.atrMa != null && curPoint.atrMa != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.atrMa!)),
        Offset(curX, getY(curPoint.atrMa!)),
        _maPaint..color = indicatorStyle.atrMaColor,
      );
    }
  }

  @override
  void calc(List<KLineEntity> dataList) {
    final n = calcParams[0];
    final m = calcParams[1];

    double trSum = 0;
    double? atrPrev;
    double maSum = 0;
    final List<double> maWindow = [];

    for (int i = 0; i < dataList.length; i++) {
      final entity = dataList[i];

      final double tr;
      if (i == 0) {
        tr = entity.high - entity.low;
      } else {
        final prevClose = dataList[i - 1].close;
        tr = max(
          entity.high - entity.low,
          max((entity.high - prevClose).abs(), (entity.low - prevClose).abs()),
        );
      }

      double? atr;
      if (i < n - 1) {
        trSum += tr;
      } else if (i == n - 1) {
        trSum += tr;
        atr = trSum / n; // seed Wilder smoothing bằng SMA của N TR đầu tiên
      } else {
        atr = (tr + (n - 1) * atrPrev!) / n;
      }
      if (atr != null) atrPrev = atr;

      double? atrMa;
      if (atr != null) {
        maWindow.add(atr);
        maSum += atr;
        if (maWindow.length > m) maSum -= maWindow.removeAt(0);
        if (maWindow.length == m) atrMa = maSum / m;
      }

      entity.atr = atr;
      entity.atrMa = atrMa;
    }
  }
}
