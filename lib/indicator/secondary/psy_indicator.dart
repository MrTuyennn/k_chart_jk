part of '../indicator_template.dart';

/// PSY：心理线 (Psychological Line)
/// 参数：N（chu kỳ đếm phiên tăng），M（chu kỳ MA tín hiệu），默认12、6。
/// 公式：PSY = COUNT(close > REF(close,1), N) / N × 100
///      MAPSY = MA(PSY, M)
class PSYIndicator extends SecondaryIndicator<MACDEntity, PSYStyle> {
  late final Paint _linePaint;

  PSYIndicator({PSYStyle? indicatorStyle})
    : super(
        name: 'psychologicalLine',
        shortName: 'PSY',
        calcParams: const [12, 6],
        indicatorStyle: indicatorStyle ?? const PSYStyle(),
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
    if (entity.psy != null) {
      minV = min(minV, entity.psy!);
      maxV = max(maxV, entity.psy!);
    }
    if (entity.psyMa != null) {
      minV = min(minV, entity.psyMa!);
      maxV = max(maxV, entity.psyMa!);
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
          text: "PSY(${calcParams[0]},${calcParams[1]}) ",
          style: getTextStyle(
            chartColors.defaultTextColor,
            base: indicatorStyle.textStyle,
          ),
        ),
        if (entity.psy != null)
          TextSpan(
            text: "PSY:${formatNumber(entity.psy!, precision)}  ",
            style: getTextStyle(
              indicatorStyle.psyColor,
              base: indicatorStyle.textStyle,
              forceColor: true,
            ),
          ),
        if (entity.psyMa != null)
          TextSpan(
            text: "MAPSY:${formatNumber(entity.psyMa!, precision)}",
            style: getTextStyle(
              indicatorStyle.maPsyColor,
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
    if (lastPoint.psy != null && curPoint.psy != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.psy!)),
        Offset(curX, getY(curPoint.psy!)),
        _linePaint..color = indicatorStyle.psyColor,
      );
    }
    if (lastPoint.psyMa != null && curPoint.psyMa != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.psyMa!)),
        Offset(curX, getY(curPoint.psyMa!)),
        _linePaint..color = indicatorStyle.maPsyColor,
      );
    }
  }

  @override
  void calc(List<KLineEntity> dataList) {
    final n = calcParams[0];
    final m = calcParams[1];

    int upCount = 0;
    final List<bool> upWindow = [];

    double psyMaSum = 0;
    final List<double> psyWindow = [];

    for (int i = 0; i < dataList.length; i++) {
      final entity = dataList[i];

      double? psy;
      if (i >= 1) {
        final isUp = entity.close > dataList[i - 1].close;
        upWindow.add(isUp);
        if (isUp) upCount++;
        if (upWindow.length > n) {
          if (upWindow.removeAt(0)) upCount--;
        }
        if (upWindow.length == n) {
          psy = upCount / n * 100;
        }
      }

      double? maPsy;
      if (psy != null) {
        psyWindow.add(psy);
        psyMaSum += psy;
        if (psyWindow.length > m) {
          psyMaSum -= psyWindow.removeAt(0);
        }
        if (psyWindow.length == m) {
          maPsy = psyMaSum / m;
        }
      }

      entity.psy = psy;
      entity.psyMa = maPsy;
    }
  }
}
