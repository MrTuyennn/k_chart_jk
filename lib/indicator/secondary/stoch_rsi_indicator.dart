part of '../indicator_template.dart';

/// StochRSI：随机相对强弱指标 (Stochastic RSI)
/// 参数：N1（RSI周期），N2（Stoch周期），M1（%K平滑），M2（%D平滑），默认14、14、3、3。
/// 公式：RSI = RSI(CLOSE, N1)                    （Wilder smoothing，tính nội bộ）
///      StochRSI = (RSI - MIN(RSI,N2)) / (MAX(RSI,N2) - MIN(RSI,N2)) × 100
///      %K = SMA(StochRSI, M1)
///      %D = SMA(%K, M2)
class StochRSIIndicator extends SecondaryIndicator<MACDEntity, StochRSIStyle> {
  late final Paint _linePaint;

  StochRSIIndicator({ StochRSIStyle? indicatorStyle }): super(
    name: 'stochasticRSI',
    shortName: 'StochRSI',
    calcParams: const [14, 14, 3, 3],
    indicatorStyle: indicatorStyle ?? const StochRSIStyle(),
    isDefaultStyle: indicatorStyle == null,
  ) {
    _linePaint = Paint()
      ..isAntiAlias = true
      ..filterQuality = FilterQuality.high
      ..strokeWidth = this.indicatorStyle.lineWidth;
  }

  /// 2 mốc quá bán / quá mua — vẽ nét đứt như Binance.
  @override
  List<double> get referenceValues => const [20, 80];

  @override
  (double, double) getMaxMinValue(KLineEntity entity, double minV, double maxV) {
    // referenceValues (20/80) tự động được BaseChartPainter.getSecondaryMaxMinValue
    // bao vào range — không cần tự ép ở đây nữa.
    if (entity.stochRsiK != null) {
      minV = min(minV, entity.stochRsiK!);
      maxV = max(maxV, entity.stochRsiK!);
    }
    if (entity.stochRsiD != null) {
      minV = min(minV, entity.stochRsiD!);
      maxV = max(maxV, entity.stochRsiD!);
    }
    return (minV, maxV);
  }

  @override
  TextSpan? drawFigure(MACDEntity entity, int precision, KChartColors chartColors) {
    return TextSpan(
      children: [
        TextSpan(
          text: "StochRSI(${calcParams[0]},${calcParams[1]},${calcParams[2]},${calcParams[3]}) ",
          style: getTextStyle(chartColors.defaultTextColor, base: indicatorStyle.textStyle),
        ),
        if (entity.stochRsiK != null)
          TextSpan(
            text: "K:${formatNumber(entity.stochRsiK!, precision)}  ",
            style: getTextStyle(indicatorStyle.kColor, base: indicatorStyle.textStyle, forceColor: true),
          ),
        if (entity.stochRsiD != null)
          TextSpan(
            text: "D:${formatNumber(entity.stochRsiD!, precision)}",
            style: getTextStyle(indicatorStyle.dColor, base: indicatorStyle.textStyle, forceColor: true),
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
    if (lastPoint.stochRsiK != null && curPoint.stochRsiK != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.stochRsiK!)),
        Offset(curX, getY(curPoint.stochRsiK!)),
        _linePaint..color = indicatorStyle.kColor,
      );
    }
    if (lastPoint.stochRsiD != null && curPoint.stochRsiD != null) {
      canvas.drawLine(
        Offset(lastX, getY(lastPoint.stochRsiD!)),
        Offset(curX, getY(curPoint.stochRsiD!)),
        _linePaint..color = indicatorStyle.dColor,
      );
    }
  }

  @override
  void calc(List<KLineEntity> dataList) {
    final n1 = calcParams[0]; // RSI length
    final n2 = calcParams[1]; // Stoch length
    final m1 = calcParams[2]; // smooth %K
    final m2 = calcParams[3]; // smooth %D

    double avgGain = 0;
    double avgLoss = 0;

    final List<double> rsiWindow = []; // N2 giá trị RSI cho min/max
    final List<double> kWindow = [];   // M1 giá trị stoch cho %K
    double kSum = 0;
    final List<double> dWindow = [];   // M2 giá trị %K cho %D
    double dSum = 0;

    for (int i = 0; i < dataList.length; i++) {
      final entity = dataList[i];

      // 1. RSI nội bộ (Wilder) — không dùng entity.rsi vì RSIIndicator
      // có thể không được bật và period có thể khác.
      double? rsi;
      if (i > 0) {
        final change = entity.close - dataList[i - 1].close;
        final gain = change > 0 ? change : 0.0;
        final loss = change < 0 ? -change : 0.0;
        if (i <= n1) {
          avgGain += gain / n1;
          avgLoss += loss / n1;
        } else {
          avgGain = (avgGain * (n1 - 1) + gain) / n1;
          avgLoss = (avgLoss * (n1 - 1) + loss) / n1;
        }
        if (i >= n1) {
          // Thị trường đi ngang tuyệt đối (không tăng cũng không giảm) → neutral 50,
          // không phải avgLoss == 0 && avgGain > 0 (overbought thực sự) mới cho 100.
          if (avgGain == 0 && avgLoss == 0) {
            rsi = 50;
          } else {
            rsi = avgLoss == 0 ? 100 : 100 - 100 / (1 + avgGain / avgLoss);
          }
        }
      }

      // 2. Stoch trên chuỗi RSI + 3. %K = SMA(stoch, M1)
      double? k;
      if (rsi != null) {
        rsiWindow.add(rsi);
        if (rsiWindow.length > n2) rsiWindow.removeAt(0);
        if (rsiWindow.length == n2) {
          double minRsi = rsiWindow.first;
          double maxRsi = rsiWindow.first;
          for (final v in rsiWindow) {
            if (v < minRsi) minRsi = v;
            if (v > maxRsi) maxRsi = v;
          }
          final range = maxRsi - minRsi;
          // range == 0 (RSI đi ngang tuyệt đối): convention TradingView → 0.
          final stoch = range == 0 ? 0.0 : (rsi - minRsi) / range * 100;
          kWindow.add(stoch);
          kSum += stoch;
          if (kWindow.length > m1) {
            kSum -= kWindow.removeAt(0);
          }
          if (kWindow.length == m1) {
            k = kSum / m1;
          }
        }
      }

      // 4. %D = SMA(%K, M2)
      double? d;
      if (k != null) {
        dWindow.add(k);
        dSum += k;
        if (dWindow.length > m2) {
          dSum -= dWindow.removeAt(0);
        }
        if (dWindow.length == m2) {
          d = dSum / m2;
        }
      }

      entity.stochRsiK = k;
      entity.stochRsiD = d;
    }
  }
}
