import 'package:flutter/material.dart';
import 'package:k_chart_wikex/entity/index.dart';
import 'package:k_chart_wikex/utils/index.dart';
import 'package:k_chart_wikex/renderer/index.dart';

/// VolRenderer
///
/// Vẽ panel volume độc lập (không overlay trong main chart). Layout đi qua
/// `mVolRect` được `BaseChartPainter.initRect` tạo riêng ngay sau `mMainRect`,
/// trước các secondary panel và `mDateRect` (ở đáy cùng). Bật/tắt panel bằng
/// cờ `volHidden` ở `KChartWidget`.
///
/// Render:
///   - Cột vol xanh/đỏ theo `close > open`, opacity tuỳ `chartStyle.volBarOpacity`.
///   - 2 đường MA5/MA10 (lấy từ `MA5Volume`/`MA10Volume` đã tính trong
///     `DataUtil.calcVolumeMA`).
///   - Label `VOL : … MA5 : … MA10 : …` ở đầu panel.
///   - Nhãn max ở góc phải (min ≈ 0 nên bỏ qua để không đè đường lưới đáy).
class VolRenderer extends BaseChartRenderer<VolumeEntity> {
  final KChartStyle chartStyle;
  final KChartColors chartColors;
  late final double _volWidth;

  VolRenderer(
    Rect volRect,
    double maxValue,
    double minValue,
    double topPadding,
    int fixedLength,
    this.chartStyle,
    this.chartColors,
  ) : super(
          chartRect: volRect,
          maxValue: maxValue,
          minValue: minValue,
          topPadding: topPadding,
          fixedLength: fixedLength,
          gridColor: chartColors.gridColor,
        ) {
    _volWidth = chartStyle.volWidth;
  }

  @override
  void drawChart(
    VolumeEntity lastPoint,
    VolumeEntity curPoint,
    double lastX,
    double curX,
    Size size,
    Canvas canvas,
  ) {
    if (curPoint.vol != 0) {
      final r = _volWidth / 2;
      final top = getY(curPoint.vol);
      final bottom = chartRect.bottom;
      final base = curPoint.close > curPoint.open
          ? chartColors.volumeStyle.upColor
          : chartColors.volumeStyle.dnColor;
      canvas.drawRect(
        Rect.fromLTRB(curX - r, top, curX + r, bottom),
        chartPaint
          ..color = base.withValues(alpha: chartStyle.volBarOpacity),
      );
    }
    if (lastPoint.MA5Volume != null &&
        lastPoint.MA5Volume != 0 &&
        curPoint.MA5Volume != null) {
      drawLine(
        lastPoint.MA5Volume,
        curPoint.MA5Volume,
        canvas,
        lastX,
        curX,
        chartColors.volumeStyle.ma5Color,
      );
    }
    if (lastPoint.MA10Volume != null &&
        lastPoint.MA10Volume != 0 &&
        curPoint.MA10Volume != null) {
      drawLine(
        lastPoint.MA10Volume,
        curPoint.MA10Volume,
        canvas,
        lastX,
        curX,
        chartColors.volumeStyle.ma10Color,
      );
    }
  }

  /// `getY` luôn chốt min = 0 (giả định volume không âm) để cột vol neo đáy panel.
  @override
  double getY(double y) =>
      (maxValue - y) * (chartRect.height / maxValue) + chartRect.top;

  @override
  TextStyle getTextStyle(Color color) {
    return chartColors.volumeStyle.textStyle.copyWith(color: color);
  }

  @override
  void drawText(Canvas canvas, VolumeEntity data, double x) {
    final span = TextSpan(
      children: [
        TextSpan(
          text: 'VOL:${NumberUtil.formatCompact(data.vol)}  ',
          style: getTextStyle(chartColors.defaultTextColor),
        ),
        if (NumberUtil.checkNotNullOrZero(data.MA5Volume))
          TextSpan(
            text: 'MA5:${NumberUtil.formatCompact(data.MA5Volume!)}  ',
            style: getTextStyle(chartColors.volumeStyle.ma5Color),
          ),
        if (NumberUtil.checkNotNullOrZero(data.MA10Volume))
          TextSpan(
            text: 'MA10:${NumberUtil.formatCompact(data.MA10Volume!)}',
            style: getTextStyle(chartColors.volumeStyle.ma10Color),
          ),
      ],
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(canvas, Offset(x, chartRect.top - topPadding));
  }

  @override
  void drawVerticalText(Canvas canvas, TextStyle textStyle, int gridRows) {
    final maxTp = TextPainter(
      text: TextSpan(
        text: NumberUtil.formatCompact(maxValue),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(
      canvas,
      Offset(
        chartRect.width - maxTp.width - chartStyle.space,
        chartRect.top - topPadding,
      ),
    );
    final minTp = TextPainter(
      text: TextSpan(
        text: NumberUtil.formatCompact(minValue),
        style: textStyle,
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    minTp.paint(
      canvas,
      Offset(
        chartRect.width - minTp.width - chartStyle.space,
        chartRect.bottom - minTp.height,
      ),
    );
  }

  @override
  void drawGrid(Canvas canvas, int gridRows, int gridColumns) {
    canvas.drawLine(
      Offset(0, chartRect.bottom),
      Offset(chartRect.width, chartRect.bottom),
      gridPaint,
    );
    final columnSpace = chartRect.width / gridColumns;
    for (int i = 0; i <= gridColumns; i++) {
      canvas.drawLine(
        Offset(columnSpace * i, chartRect.top - topPadding),
        Offset(columnSpace * i, chartRect.bottom),
        gridPaint,
      );
    }
  }
}
