part of '../indicator_template.dart';

/// MTM：动量指标 (Momentum)
/// 参数：N（动量周期），M（信号线MA周期），默认12、6。
/// 公式：MTM = CLOSE - REF(CLOSE, N)
///      MTMMA = MA(MTM, M)
class MTMIndicator extends SecondaryIndicator<MACDEntity, MTMStyle> {
  late final Paint _linePaint;

  MTMIndicator({ MTMStyle indicatorStyle = const MTMStyle() }): super(
    name: 'momentum',
    shortName: 'MTM',
    calcParams: const [12, 6],
    indicatorStyle: indicatorStyle,
  ) {
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = indicatorStyle.lineWidth;
  }

  @override
  (double, double) getMaxMinValue(KLineEntity entity, double minV, double maxV) {
    if (entity.mtm != null) {
      minV = min(minV, entity.mtm!);
      maxV = max(maxV, entity.mtm!);
    }
    if (entity.mtmMa != null) {
      minV = min(minV, entity.mtmMa!);
      maxV = max(maxV, entity.mtmMa!);
    }
    return (minV, maxV);
  }

  @override
  TextSpan? drawFigure(MACDEntity entity, int precision, KChartColors chartColors) {
    return TextSpan(
      children: [
        TextSpan(
          text: "MTM(${calcParams[0]},${calcParams[1]}) ",
          style: getTextStyle(chartColors.defaultTextColor, indicatorStyle.textStyle),
        ),
        if (entity.mtm != null)
          TextSpan(
            text: "MTM:${formatNumber(entity.mtm!, precision)}  ",
            style: getTextStyle(indicatorStyle.mtmColor, indicatorStyle.textStyle, true),
          ),
        if (entity.mtmMa != null)
          TextSpan(
            text: "MTMMA:${formatNumber(entity.mtmMa!, precision)}",
            style: getTextStyle(indicatorStyle.mtmMaColor, indicatorStyle.textStyle, true),
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
    if (lastPoint.mtm != null && curPoint.mtm != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.mtm!)),
        Offset(curX, getY(curPoint.mtm!)),
        _linePaint..color = indicatorStyle.mtmColor,
      );
    }
    if (lastPoint.mtmMa != null && curPoint.mtmMa != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.mtmMa!)),
        Offset(curX, getY(curPoint.mtmMa!)),
        _linePaint..color = indicatorStyle.mtmMaColor,
      );
    }
  }

  @override
  void calc(List<KLineEntity> dataList) {
    final n = calcParams[0];
    final m = calcParams[1];

    double mtmSum = 0;
    final List<double> mtmWindow = [];

    for (int i = 0; i < dataList.length; i++) {
      final entity = dataList[i];

      double? mtm;
      if (i >= n) {
        mtm = entity.close - dataList[i - n].close;
      }

      double? mtmMa;
      if (mtm != null) {
        mtmWindow.add(mtm);
        mtmSum += mtm;
        if (mtmWindow.length > m) {
          mtmSum -= mtmWindow.removeAt(0);
        }
        if (mtmWindow.length == m) {
          mtmMa = mtmSum / m;
        }
      }

      entity.mtm = mtm;
      entity.mtmMa = mtmMa;
    }
  }
}
