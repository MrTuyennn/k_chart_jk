part of '../indicator_template.dart';

/// TRIX：三重指数平滑移动平均的变化率
/// 参数：N（三重EMA周期），M（信号线MA周期），默认12、20。
/// 公式：EMA1 = EMA(CLOSE, N)；EMA2 = EMA(EMA1, N)；EMA3 = EMA(EMA2, N)
///      TRIX = (EMA3 - REF(EMA3, 1)) / REF(EMA3, 1) × 100
///      MATRIX = MA(TRIX, M)
class TRIXIndicator extends SecondaryIndicator<MACDEntity, TRIXStyle> {
  late final Paint _linePaint;

  TRIXIndicator({ TRIXStyle indicatorStyle = const TRIXStyle() }): super(
    name: 'tripleExponentialAverage',
    shortName: 'TRIX',
    calcParams: const [12, 20],
    indicatorStyle: indicatorStyle,
  ) {
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = indicatorStyle.lineWidth;
  }

  @override
  (double, double) getMaxMinValue(KLineEntity entity, double minV, double maxV) {
    if (entity.trix != null) {
      minV = min(minV, entity.trix!);
      maxV = max(maxV, entity.trix!);
    }
    if (entity.trixMa != null) {
      minV = min(minV, entity.trixMa!);
      maxV = max(maxV, entity.trixMa!);
    }
    return (minV, maxV);
  }

  @override
  TextSpan? drawFigure(MACDEntity entity, int precision, KChartColors chartColors) {
    return TextSpan(
      children: [
        TextSpan(
          text: "TRIX(${calcParams[0]},${calcParams[1]}) ",
          style: getTextStyle(chartColors.defaultTextColor),
        ),
        if (entity.trix != null)
          TextSpan(
            text: "TRIX:${formatNumber(entity.trix!, precision)}  ",
            style: getTextStyle(indicatorStyle.trixColor),
          ),
        if (entity.trixMa != null)
          TextSpan(
            text: "MATRIX:${formatNumber(entity.trixMa!, precision)}",
            style: getTextStyle(indicatorStyle.trixMaColor),
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

    maxTp.paint(
      canvas,
      Offset(chartRect.width - maxTp.width, chartRect.top),
    );
    minTp.paint(
      canvas,
      Offset(chartRect.width - minTp.width, chartRect.bottom - minTp.height),
    );
  }

  @override
  void drawChart(MACDEntity lastPoint, MACDEntity curPoint, double lastX, double curX, GetYFunction getY, Canvas canvas, KChartColors chartColors) {
    if (lastPoint.trix != null && curPoint.trix != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.trix!)),
        Offset(curX, getY(curPoint.trix!)),
        _linePaint..color = indicatorStyle.trixColor,
      );
    }
    if (lastPoint.trixMa != null && curPoint.trixMa != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.trixMa!)),
        Offset(curX, getY(curPoint.trixMa!)),
        _linePaint..color = indicatorStyle.trixMaColor,
      );
    }
  }

  @override
  void calc(List<KLineEntity> dataList) {
    final n = calcParams[0];
    final m = calcParams[1];
    final multiplier = 2 / (n + 1);

    double ema1 = 0;
    double ema2 = 0;
    double ema3 = 0;
    double? prevEma3;
    double trixSum = 0;
    final List<double> trixWindow = [];

    for (int i = 0; i < dataList.length; i++) {
      final entity = dataList[i];
      final close = entity.close;

      if (i == 0) {
        ema1 = close;
        ema2 = ema1;
        ema3 = ema2;
      } else {
        ema1 = (close - ema1) * multiplier + ema1;
        ema2 = (ema1 - ema2) * multiplier + ema2;
        ema3 = (ema2 - ema3) * multiplier + ema3;
      }

      double? trix;
      if (prevEma3 != null && prevEma3 != 0) {
        trix = (ema3 - prevEma3) / prevEma3 * 100;
      }
      prevEma3 = ema3;

      double? trixMa;
      if (trix != null) {
        trixWindow.add(trix);
        trixSum += trix;
        if (trixWindow.length > m) {
          trixSum -= trixWindow.removeAt(0);
        }
        if (trixWindow.length == m) {
          trixMa = trixSum / m;
        }
      }

      entity.trix = trix;
      entity.trixMa = trixMa;
    }
  }
}
