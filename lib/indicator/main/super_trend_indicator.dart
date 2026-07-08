part of '../indicator_template.dart';

class SuperTrend {
  double? value;
  bool? isUp;
}

class SuperTrendIndicator extends MainIndicator<CandleEntity, SuperTrendStyle> {
  late final Paint _linePaint;
  late final Paint _fillPaint;

  SuperTrendIndicator({SuperTrendStyle indicatorStyle = const SuperTrendStyle()})
    : super(
        name: 'superTrend',
        shortName: 'SUPER',
        calcParams: const [10, 30],
        indicatorStyle: indicatorStyle,
      ) {
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..style = PaintingStyle.stroke
      ..strokeWidth = indicatorStyle.lineWidth;

    _fillPaint = Paint()..isAntiAlias = true;
  }

  @override
  (double, double) getMaxMinValue(KLineEntity entity, double minV, double maxV) {
    final value = entity.superTrend?.value;
    if (value == null) return (minV, maxV);
    return (min(value, minV), max(value, maxV));
  }

  @override
  TextSpan? drawFigure(CandleEntity entity, int precision, KChartColors chartColors) {
    final st = entity.superTrend;
    if (st?.value == null) return null;
    final color = st!.isUp == true ? indicatorStyle.upColor : indicatorStyle.dnColor;
    return TextSpan(
      text: "SUPER: ${formatNumber(st.value!, precision)}",
      style: TextStyle(fontSize: 10, color: color),
    );
  }

  @override
  void drawChart(
    CandleEntity lastPoint,
    CandleEntity curPoint,
    double lastX,
    double curX,
    GetYFunction getY,
    Canvas canvas,
    KChartColors chartColors,
  ) {
    final lastValue = lastPoint.superTrend?.value;
    final curValue = curPoint.superTrend?.value;
    if (lastValue == null || curValue == null) return;

    final isUp = curPoint.superTrend!.isUp == true;
    final color = isUp ? indicatorStyle.upColor : indicatorStyle.dnColor;
    final fillColor = isUp ? indicatorStyle.upFillColor : indicatorStyle.dnFillColor;

    final fillPath = Path()
      ..moveTo(lastX, getY(lastValue))
      ..lineTo(curX, getY(curValue))
      ..lineTo(curX, getY(curPoint.close))
      ..lineTo(lastX, getY(lastPoint.close))
      ..close();
    canvas.drawPath(fillPath, _fillPaint..color = fillColor);

    canvas.drawLine(
      Offset(lastX, getY(lastValue)),
      Offset(curX, getY(curValue)),
      _linePaint..color = color,
    );
  }

  @override
  void calc(List<KLineEntity> dataList) {
    final period = calcParams[0];
    final multiplier = calcParams[1] / 10;

    double atr = 0;
    double sumTr = 0;
    double? prevFinalUpperBand;
    double? prevFinalLowerBand;
    double? prevSuperTrend;

    for (int i = 0; i < dataList.length; ++i) {
      final entity = dataList[i];
      final high = entity.high;
      final low = entity.low;
      final close = entity.close;

      final tr = i == 0
          ? high - low
          : max(
              high - low,
              max(
                (high - dataList[i - 1].close).abs(),
                (low - dataList[i - 1].close).abs(),
              ),
            );

      if (i < period) {
        sumTr += tr;
        entity.superTrend = SuperTrend();
        if (i == period - 1) atr = sumTr / period;
        continue;
      }

      // Wilder's smoothing
      atr = (atr * (period - 1) + tr) / period;

      final mid = (high + low) / 2;
      final basicUpperBand = mid + multiplier * atr;
      final basicLowerBand = mid - multiplier * atr;
      final prevClose = dataList[i - 1].close;

      final finalUpperBand =
          (prevFinalUpperBand == null ||
              basicUpperBand < prevFinalUpperBand ||
              prevClose > prevFinalUpperBand)
          ? basicUpperBand
          : prevFinalUpperBand;

      final finalLowerBand =
          (prevFinalLowerBand == null ||
              basicLowerBand > prevFinalLowerBand ||
              prevClose < prevFinalLowerBand)
          ? basicLowerBand
          : prevFinalLowerBand;

      final isUp = prevSuperTrend == null
          ? close > finalUpperBand
          : prevSuperTrend == prevFinalUpperBand
          ? close > finalUpperBand
          : close >= finalLowerBand;

      final value = isUp ? finalLowerBand : finalUpperBand;

      entity.superTrend = SuperTrend()
        ..value = value
        ..isUp = isUp;

      prevFinalUpperBand = finalUpperBand;
      prevFinalLowerBand = finalLowerBand;
      prevSuperTrend = value;
    }
  }
}
