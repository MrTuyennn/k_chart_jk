import 'package:flutter/material.dart';
import 'package:k_chart_wikex/indicator/indicator_template.dart';
import '../entity/macd_entity.dart';
import 'base_chart_renderer.dart';

class SecondaryRenderer extends BaseChartRenderer<MACDEntity> {
  SecondaryIndicator indicator;
  final KChartStyle chartStyle;
  final KChartColors chartColors;

  SecondaryRenderer(
    Rect mainRect,
    double maxValue,
    double minValue,
    double topPadding,
    this.indicator,
    int fixedLength,
    this.chartStyle,
    this.chartColors,
  ) : super(
        chartRect: mainRect,
        maxValue: maxValue,
        minValue: minValue,
        topPadding: topPadding,
        fixedLength: fixedLength,
        gridColor: chartColors.gridColor,
      );

  @override
  void drawChart(
    MACDEntity lastPoint,
    MACDEntity curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas,
  ) {
    indicator.drawChart(
      lastPoint,
      curPoint,
      lastX,
      curX,
      getY,
      canvas,
      chartColors,
    );
  }

  /// Vẽ các đường tham chiếu ngang nét đứt (indicator.referenceValues).
  /// Gọi 1 lần mỗi frame ở screen space, TRƯỚC vòng drawChart để vạch
  /// nằm phía sau đường indicator.
  void drawReferenceLines(Canvas canvas) {
    if (indicator.referenceValues.isEmpty) return;
    final paint = Paint()
      ..color = chartColors.defaultTextColor.withAlpha(90)
      ..strokeWidth = 0.5;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    for (final value in indicator.referenceValues) {
      final y = getY(value);
      double x = 0;
      while (x < chartRect.width) {
        canvas.drawLine(Offset(x, y), Offset(x + dashWidth, y), paint);
        x += dashWidth + dashSpace;
      }
    }
  }

  @override
  void drawText(Canvas canvas, MACDEntity data, double x) {
    TextSpan? span = indicator.drawFigure(data, fixedLength, chartColors);
    if (span == null) return;
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(x, chartRect.top - topPadding));
  }

  @override
  void drawVerticalText(canvas, textStyle, int gridRows) {
    indicator.drawVerticalText(
      canvas: canvas,
      style: textStyle,
      maxValue: maxValue,
      minValue: minValue,
      fixedLength: fixedLength,
      chartRect: Rect.fromLTRB(
        chartRect.left,
        chartRect.top - topPadding,
        chartRect.right - chartStyle.space,
        chartRect.bottom,
      ),
    );
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    // canvas.drawLine(Offset(0, chartRect.top), Offset(chartRect.width, chartRect.top), gridPaint); //hidden line
    canvas.drawLine(
      Offset(0, chartRect.bottom),
      Offset(chartRect.width, chartRect.bottom),
      gridPaint,
    );
    double columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= gridColumns; i++) {
      canvas.drawLine(
        Offset(columnSpace * i, chartRect.top - topPadding),
        Offset(columnSpace * i, chartRect.bottom),
        gridPaint,
      );
    }
  }
}
