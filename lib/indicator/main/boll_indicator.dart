part of '../indicator_template.dart';

class Boll {
  double? up;
  double? mid;
  double? dn;
  double? bollMa;
}

class BOLLIndicator extends MainIndicator<CandleEntity, BOLLStyle> {
  late final Paint _linePaint;
  late final Paint _fillPaint;

  BOLLIndicator({BOLLStyle indicatorStyle = const BOLLStyle()})
    : super(
        name: 'bollingerBands',
        shortName: 'BOLL',
        calcParams: const [20, 2],
        indicatorStyle: indicatorStyle,
      ) {
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = indicatorStyle.lineWidth;

    _fillPaint = Paint();
  }

  @override
  (double, double) getMaxMinValue(
    KLineEntity entity,
    double minV,
    double maxV,
  ) {
    if (entity.boll == null) return (minV, maxV);
    double minValue = minV;
    if (entity.boll!.dn != null) {
      minValue = min(minValue, entity.boll!.dn!);
    }
    double maxValue = maxV;
    if (entity.boll!.up != null) {
      maxValue = max(maxValue, entity.boll!.up!);
    }
    return (minValue, maxValue);
  }

  @override
  TextSpan? drawFigure(
    CandleEntity entity,
    int precision,
    KChartColors chartColors,
  ) {
    if (entity.boll == null) return null;
    Boll value = entity.boll!;
    return TextSpan(
      children: [
        if (value.mid != null && value.mid != 0)
          TextSpan(
            text: "BOLL:${formatNumber(value.mid!, precision)}  ",
            style: getTextStyle(indicatorStyle.bollColor, chartColors.candleStyle.textStyle),
          ),
        if (value.up != null && value.up != 0)
          TextSpan(
            text: "UB:${formatNumber(value.up!, precision)}  ",
            style: getTextStyle(indicatorStyle.ubColor, chartColors.candleStyle.textStyle),
          ),
        if (value.dn != null && value.dn != 0)
          TextSpan(
            text: "LB:${formatNumber(value.dn!, precision)}",
            style: getTextStyle(indicatorStyle.lbColor, chartColors.candleStyle.textStyle),
          ),
      ],
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
    if (lastPoint.boll == null || curPoint.boll == null) return;
    final List<Offset> positionLi = [];

    if (curPoint.boll!.up != null && lastPoint.boll!.up != null) {
      positionLi.add(Offset(curX, getY(curPoint.boll!.up!))); //0
      positionLi.add(Offset(lastX, getY(lastPoint.boll!.up!))); //1
      /// UB
      canvas.drawLine(
        positionLi[0],
        positionLi[1],
        _linePaint..color = indicatorStyle.ubColor,
      );
    }

    if (curPoint.boll!.dn != null && lastPoint.boll!.dn != null) {
      positionLi.add(Offset(lastX, getY(lastPoint.boll!.dn!))); //2
      positionLi.add(Offset(curX, getY(curPoint.boll!.dn!))); //3

      /// LB
      canvas.drawLine(
        positionLi[2],
        positionLi[3],
        _linePaint..color = indicatorStyle.lbColor,
      );
    }

    if (positionLi.length == 4) {
      Path fillPath = Path()
        ..moveTo(positionLi[0].dx, positionLi[0].dy)
        ..lineTo(positionLi[1].dx, positionLi[1].dy)
        ..lineTo(positionLi[2].dx, positionLi[2].dy)
        ..lineTo(positionLi[3].dx, positionLi[3].dy)
        ..close();

      canvas.drawPath(fillPath, _fillPaint..color = indicatorStyle.fillColor);
    }

    if (curPoint.boll!.mid != null && lastPoint.boll!.mid != null) {
      /// BOLL
      canvas.drawLine(
        Offset(curX, getY(curPoint.boll!.mid!)),
        Offset(lastX, getY(lastPoint.boll!.mid!)),
        _linePaint..color = indicatorStyle.bollColor,
      );
    }
  }

  @override
  void calc(List<KLineEntity> dataList) {
    int n = calcParams[0];
    int k = calcParams[1];
    _calcbollMa(n, dataList);
    for (int i = 0; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      if (i >= n) {
        double md = 0;
        for (int j = i - n + 1; j <= i; j++) {
          double c = dataList[j].close;
          double m = entity.boll!.bollMa!;
          double value = c - m;
          md += value * value;
        }
        md = md / (n - 1);
        md = sqrt(md);
        entity.boll!.mid = entity.boll!.bollMa!;
        entity.boll!.up = entity.boll!.mid! + k * md;
        entity.boll!.dn = entity.boll!.mid! - k * md;
      }
    }
  }

  void _calcbollMa(int day, List<KLineEntity> dataList) {
    double ma = 0;
    for (int i = 0; i < dataList.length; i++) {
      KLineEntity entity = dataList[i];
      ma += entity.close;
      entity.boll = Boll();
      if (i == day - 1) {
        entity.boll!.bollMa = ma / day;
      } else if (i >= day) {
        ma -= dataList[i - day].close;
        entity.boll!.bollMa = ma / day;
      } else {
        entity.boll!.bollMa = null;
      }
    }
  }
}
