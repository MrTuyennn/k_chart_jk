import 'package:flutter/material.dart';
import 'package:k_chart_jk/indicator/indicator_template.dart';
import '../entity/macd_entity.dart';
import 'base_chart_renderer.dart';

class SecondaryRenderer extends BaseChartRenderer<MACDEntity> {
  SecondaryIndicator indicator;
  final KChartStyle chartStyle;
  final KChartColors chartColors;
  late final Paint _referencePaint;

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
      ) {
    _referencePaint = Paint()
      ..color = chartColors.defaultTextColor.withAlpha(90)
      ..strokeWidth = 0.5;
  }

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
  @override
  void drawReferenceLines(Canvas canvas) {
    if (indicator.referenceValues.isEmpty) return;
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    for (final value in indicator.referenceValues) {
      final y = getY(value);
      // Gom toàn bộ các đoạn nét đứt vào 1 Path, vẽ bằng 1 lệnh drawPath
      // thay vì hàng chục/hàng trăm lệnh drawLine riêng lẻ mỗi frame.
      final path = Path();
      double x = 0;
      while (x < chartRect.width) {
        path.moveTo(x, y);
        path.lineTo(x + dashWidth, y);
        x += dashWidth + dashSpace;
      }
      canvas.drawPath(path, _referencePaint);
    }
  }

  /// Panel secondary dùng textStyle riêng của chính indicator đó
  /// (`indicator.indicatorStyle.textStyle`) — KHÔNG dùng chung `candleStyle.textStyle`
  /// của main chart, để mỗi panel (StochRSI/KDJ/MACD/...) tự chỉnh font/màu độc lập.
  @override
  TextStyle getTextStyle(Color color) {
    final TextStyle textStyle = indicator.indicatorStyle.textStyle;
    return textStyle.color != null
        ? textStyle
        : textStyle.copyWith(color: color);
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
