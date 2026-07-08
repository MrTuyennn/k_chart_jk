part of '../indicator_template.dart';

/// AVL：均价线 — Average Value Line (kiểu Binance)
/// Giá khớp lệnh trung bình của TỪNG nến — đường luôn đi xuyên qua thân nến,
/// bám sát giá như trên app Binance.
/// Công thức：AVL = AMOUNT / VOL       (quote volume ÷ base volume của nến)
///           fallback khi thiếu amount: AVL = (HIGH + LOW + CLOSE) / 3
/// Không có tham số chu kỳ.
class AVLIndicator extends MainIndicator<CandleEntity, AVLStyle> {
  late final Paint _linePaint;

  AVLIndicator({
    super.indicatorStyle = const AVLStyle(),
  }) : super(
          name: 'averageValueLine',
          shortName: 'AVL',
          calcParams: const [],
        ) {
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..style = PaintingStyle.stroke
      ..strokeWidth = indicatorStyle.lineWidth
      ..color = indicatorStyle.avlColor;
  }

  @override
  (double, double) getMaxMinValue(
      KLineEntity entity, double minV, double maxV) {
    if (entity.avl == null) return (minV, maxV);
    return (min(minV, entity.avl!), max(maxV, entity.avl!));
  }

  @override
  TextSpan? drawFigure(
      CandleEntity entity, int precision, KChartColors chartColors) {
    if (entity is! AVLEntity) return null;
    final aEntity = entity as AVLEntity;

    if (aEntity.avl == null) return null;
    return TextSpan(
      text: "$shortName: ${formatNumber(aEntity.avl!, precision)}    ",
      style: getTextStyle(indicatorStyle.avlColor),
    );
  }

  @override
  void drawChart(CandleEntity lastPoint, CandleEntity curPoint, double lastX,
      double curX, GetYFunction getY, Canvas canvas, KChartColors chartColors) {
    if (lastPoint is! AVLEntity || curPoint is! AVLEntity) return;
    final lastA = lastPoint as AVLEntity;
    final curA = curPoint as AVLEntity;

    if (lastA.avl == null || curA.avl == null) return;

    canvas.drawLine(
      Offset(lastX, getY(lastA.avl!)),
      Offset(curX, getY(curA.avl!)),
      _linePaint,
    );
  }

  @override
  void calc(List<KLineEntity> dataList) {
    for (var entity in dataList) {
      final amount = entity.amount;
      if (amount != null && amount > 0 && entity.vol > 0) {
        // Giá khớp lệnh trung bình thực của nến (quote/base volume).
        entity.avl = amount / entity.vol;
      } else {
        // Thiếu amount (API không trả hoặc = 0): xấp xỉ bằng typical price
        // — vẫn luôn nằm trong range high-low của nến.
        entity.avl = (entity.high + entity.low + entity.close) / 3;
      }
    }
  }
}
