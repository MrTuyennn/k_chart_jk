part of '../indicator_template.dart';

/// VOL — Volume secondary panel.
///
/// Vẽ cột volume (xanh/đỏ theo close vs open) + 2 đường MA5/MA10 trên panel
/// phụ giống MACD/KDJ/RSI/OBV. Trước đây volume là overlay 20% bên trong
/// `mMainRect`; nay tách hẳn thành secondary indicator để user toggle on/off
/// như các indicator khác.
///
/// `calc` là no-op vì `DataUtil.calcVolumeMA` đã chạy trong `calculateAll`
/// và gán `MA5Volume` / `MA10Volume` vào từng KLineEntity.
class VolIndicator extends SecondaryIndicator<MACDEntity, VolStyle> {
  late final Paint _barPaint;
  late final Paint _linePaint;

  VolIndicator({VolStyle indicatorStyle = const VolStyle()})
    : super(
        name: 'volume',
        shortName: 'VOL',
        calcParams: const [5, 10],
        indicatorStyle: indicatorStyle,
      ) {
    _barPaint = Paint()..isAntiAlias = true;
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = indicatorStyle.lineWidth;
  }

  @override
  (double, double) getMaxMinValue(KLineEntity entity, double minV, double maxV) {
    final ma5 = entity.MA5Volume ?? 0;
    final ma10 = entity.MA10Volume ?? 0;
    maxV = max(maxV, max(entity.vol, max(ma5, ma10)));
    // Min của vol thường là 0 — không quan tâm giá trị âm.
    minV = min(minV, 0);
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
          text: 'VOL:${NumberUtil.formatCompact(entity.vol)}  ',
          style: getTextStyle(chartColors.defaultTextColor),
        ),
        if (NumberUtil.checkNotNullOrZero(entity.MA5Volume))
          TextSpan(
            text:
                'MA${calcParams[0]}:${NumberUtil.formatCompact(entity.MA5Volume!)}  ',
            style: getTextStyle(indicatorStyle.ma5Color),
          ),
        if (NumberUtil.checkNotNullOrZero(entity.MA10Volume))
          TextSpan(
            text:
                'MA${calcParams[1]}:${NumberUtil.formatCompact(entity.MA10Volume!)}',
            style: getTextStyle(indicatorStyle.ma10Color),
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
    final maxTp = TextPainter(
      text: TextSpan(text: NumberUtil.formatCompact(maxValue), style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    maxTp.paint(canvas, Offset(chartRect.width - maxTp.width, chartRect.top));
    // Min volume luôn ≈ 0 → bỏ qua label bottom để tránh đè lên đường lưới đáy.
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
    if (curPoint.vol != 0) {
      final r = indicatorStyle.volWidth / 2;
      final top = getY(curPoint.vol);
      final bottom = getY(0);
      final base = curPoint.close > curPoint.open
          ? indicatorStyle.volUpColor
          : indicatorStyle.volDnColor;
      _barPaint.color = base.withValues(alpha: indicatorStyle.barOpacity);
      canvas.drawRect(Rect.fromLTRB(curX - r, top, curX + r, bottom), _barPaint);
    }

    if (lastPoint.MA5Volume != null &&
        lastPoint.MA5Volume != 0 &&
        curPoint.MA5Volume != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.MA5Volume!)),
        Offset(curX, getY(curPoint.MA5Volume!)),
        _linePaint..color = indicatorStyle.ma5Color,
      );
    }
    if (lastPoint.MA10Volume != null &&
        lastPoint.MA10Volume != 0 &&
        curPoint.MA10Volume != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.MA10Volume!)),
        Offset(curX, getY(curPoint.MA10Volume!)),
        _linePaint..color = indicatorStyle.ma10Color,
      );
    }
  }

  /// MA volume đã được tính sẵn trong `DataUtil.calcVolumeMA` → không cần lặp lại.
  @override
  void calc(List<KLineEntity> dataList) {}
}
