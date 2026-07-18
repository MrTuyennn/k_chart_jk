part of '../indicator_template.dart';

/// BRAR：人气意愿指标 (Popularity/Willingness — AR/BR)
/// 参数：N（周期），默认 26。
/// 公式：AR = SUM(HIGH - OPEN, N) / SUM(OPEN - LOW, N) × 100
///      BR = SUM(MAX(0, HIGH - REF(CLOSE,1)), N) / SUM(MAX(0, REF(CLOSE,1) - LOW), N) × 100
class BRARIndicator extends SecondaryIndicator<MACDEntity, BRARStyle> {
  late final Paint _linePaint;

  BRARIndicator({BRARStyle? indicatorStyle})
    : super(
        name: 'braAndAr',
        shortName: 'BRAR',
        calcParams: const [26],
        indicatorStyle: indicatorStyle ?? const BRARStyle(),
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
    if (entity.ar != null) {
      minV = min(minV, entity.ar!);
      maxV = max(maxV, entity.ar!);
    }
    if (entity.br != null) {
      minV = min(minV, entity.br!);
      maxV = max(maxV, entity.br!);
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
          text: "BRAR(${calcParams[0]}) ",
          style: getTextStyle(
            chartColors.defaultTextColor,
            base: indicatorStyle.textStyle,
          ),
        ),
        if (entity.ar != null)
          TextSpan(
            text: "AR:${formatNumber(entity.ar!, precision)}  ",
            style: getTextStyle(
              indicatorStyle.arColor,
              base: indicatorStyle.textStyle,
              forceColor: true,
            ),
          ),
        if (entity.br != null)
          TextSpan(
            text: "BR:${formatNumber(entity.br!, precision)}",
            style: getTextStyle(
              indicatorStyle.brColor,
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
    if (lastPoint.ar != null && curPoint.ar != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.ar!)),
        Offset(curX, getY(curPoint.ar!)),
        _linePaint..color = indicatorStyle.arColor,
      );
    }
    if (lastPoint.br != null && curPoint.br != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.br!)),
        Offset(curX, getY(curPoint.br!)),
        _linePaint..color = indicatorStyle.brColor,
      );
    }
  }

  @override
  void calc(List<KLineEntity> dataList) {
    final n = calcParams[0];

    double sumHO = 0, sumOL = 0, sumHC = 0, sumCL = 0;
    final List<double> hoWindow = [];
    final List<double> olWindow = [];
    final List<double> hcWindow = [];
    final List<double> clWindow = [];

    for (int i = 0; i < dataList.length; i++) {
      final entity = dataList[i];

      final ho = entity.high - entity.open;
      hoWindow.add(ho);
      sumHO += ho;
      if (hoWindow.length > n) sumHO -= hoWindow.removeAt(0);

      final ol = entity.open - entity.low;
      olWindow.add(ol);
      sumOL += ol;
      if (olWindow.length > n) sumOL -= olWindow.removeAt(0);

      if (i >= 1) {
        final prevClose = dataList[i - 1].close;
        final hc = max(0.0, entity.high - prevClose);
        hcWindow.add(hc);
        sumHC += hc;
        if (hcWindow.length > n) sumHC -= hcWindow.removeAt(0);

        final cl = max(0.0, prevClose - entity.low);
        clWindow.add(cl);
        sumCL += cl;
        if (clWindow.length > n) sumCL -= clWindow.removeAt(0);
      }

      entity.ar = hoWindow.length == n
          ? (sumOL == 0 ? 0.0 : sumHO / sumOL * 100)
          : null;
      entity.br = hcWindow.length == n
          ? (sumCL == 0 ? 0.0 : sumHC / sumCL * 100)
          : null;
    }
  }
}
