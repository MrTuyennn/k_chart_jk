part of '../indicator_template.dart';

/// BIAS：乖离率 (Bias Ratio — % lệch giá so với đường MA)
/// 参数：nhiều chu kỳ cùng lúc, mặc định 6/12/24 (kiểu Binance/MEXC).
/// 公式：BIAS(N) = (CLOSE - MA(CLOSE,N)) / MA(CLOSE,N) × 100%
class BIASIndicator extends SecondaryIndicator<MACDEntity, BIASStyle> {
  late final Paint _linePaint;

  BIASIndicator({BIASStyle? indicatorStyle})
    : super(
        name: 'biasRatio',
        shortName: 'BIAS',
        calcParams: const [6, 12, 24],
        indicatorStyle: indicatorStyle ?? const BIASStyle(),
        isDefaultStyle: indicatorStyle == null,
      ) {
    _linePaint = Paint()
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
    final values = entity.biasValueList;
    if (values == null) return (minV, maxV);
    for (final v in values) {
      if (v != null) {
        minV = min(minV, v);
        maxV = max(maxV, v);
      }
    }
    return (minV, maxV);
  }

  @override
  TextSpan? drawFigure(
    MACDEntity entity,
    int precision,
    KChartColors chartColors,
  ) {
    final values = entity.biasValueList;
    if (values == null) return null;
    final List<InlineSpan> result = [];
    for (int i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      result.add(
        TextSpan(
          text: "BIAS${calcParams[i]}:${formatNumber(v, precision)}  ",
          style: getTextStyle(
            indicatorStyle.getBiasColor(i),
            base: indicatorStyle.textStyle,
            forceColor: true,
          ),
        ),
      );
    }
    if (result.isEmpty) return null;
    return TextSpan(children: result);
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
    final lastValues = lastPoint.biasValueList;
    final curValues = curPoint.biasValueList;
    if (lastValues == null ||
        curValues == null ||
        lastValues.length != curValues.length) {
      return;
    }
    for (int i = 0; i < curValues.length; i++) {
      final lastV = lastValues[i];
      final curV = curValues[i];
      if (lastV != null && curV != null) {
        canvas.drawLine(
          Offset(lastX, getY(lastV)),
          Offset(curX, getY(curV)),
          _linePaint..color = indicatorStyle.getBiasColor(i),
        );
      }
    }
  }

  @override
  void calc(List<KLineEntity> dataList) {
    final periods = calcParams;
    final maSums = List<double>.filled(periods.length, 0);

    for (int i = 0; i < dataList.length; i++) {
      final entity = dataList[i];
      final close = entity.close;
      final values = List<double?>.filled(periods.length, null);

      for (int j = 0; j < periods.length; j++) {
        final p = periods[j];
        maSums[j] += close;
        if (i >= p) {
          maSums[j] -= dataList[i - p].close;
        }
        if (i >= p - 1) {
          final ma = maSums[j] / p;
          values[j] = ma == 0 ? 0.0 : (close - ma) / ma * 100;
        }
      }

      entity.biasValueList = values;
    }
  }
}
