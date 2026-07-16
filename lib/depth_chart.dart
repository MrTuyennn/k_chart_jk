import 'dart:math';
import 'package:flutter/material.dart';
import 'package:k_chart_wikex/chart_translations.dart';
import 'package:k_chart_wikex/extension/canvas_extension.dart';
import 'package:k_chart_wikex/styles/depth_chart_style.dart';
import 'package:k_chart_wikex/utils/number_util.dart';
import 'entity/depth_entity.dart';

class DepthChart extends StatefulWidget {
  final List<DepthEntity> bids, asks;
  final int baseUnit;
  final int quoteUnit;
  final Offset offset;
  final DepthChartColors chartColors;
  final DepthChartStyle chartStyle;
  final DepthChartTranslations chartTranslations;

  /// Widget hiển thị như watermark ở giữa vùng depth chart (vd: SvgPicture.asset(...))
  final Widget? backgroundLogo;

  /// Độ trong suốt của backgroundLogo (0.0 = ẩn hoàn toàn, 1.0 = hiện đầy đủ)
  final double backgroundLogoOpacity;

  /// Số mốc giá hiển thị ở trục dưới (>=2). Mặc định 5.
  final int bottomLabelCount;

  DepthChart(
    this.bids,
    this.asks,
    this.chartColors, {
    this.baseUnit = 2,
    this.quoteUnit = 6,
    this.offset = const Offset(8, 0),
    this.chartTranslations = const DepthChartTranslations(),
    this.chartStyle = const DepthChartStyle(),
    this.backgroundLogo,
    this.backgroundLogoOpacity = 1,
    this.bottomLabelCount = 5,
  });

  @override
  _DepthChartState createState() => _DepthChartState();
}

class _DepthChartState extends State<DepthChart> {
  Offset? pressOffset;
  bool isLongPress = false;

  @override
  Widget build(BuildContext context) {
    final bool hasLogo = widget.backgroundLogo != null;
    final chart = CustomPaint(
      size: Size(double.infinity, double.infinity),
      painter: DepthChartPainter(
        widget.bids,
        widget.asks,
        pressOffset,
        isLongPress,
        widget.baseUnit,
        widget.quoteUnit,
        widget.chartColors,
        widget.chartStyle,
        widget.offset,
        widget.chartTranslations,
        bottomLabelCount: widget.bottomLabelCount,
      ),
    );

    return GestureDetector(
      onLongPressStart: (details) {
        pressOffset = details.localPosition;
        isLongPress = true;
        setState(() {});
      },
      onLongPressMoveUpdate: (details) {
        pressOffset = details.localPosition;
        isLongPress = true;
        setState(() {});
      },
      onLongPressEnd: (details) {
        pressOffset = null;
        isLongPress = false;
        setState(() {});
      },
      child: hasLogo
          ? Stack(
              children: [
                // layer 1: logo watermark ở giữa vùng depth chart
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Opacity(
                        opacity: widget.backgroundLogoOpacity.clamp(0.0, 1.0),
                        child: widget.backgroundLogo!,
                      ),
                    ),
                  ),
                ),
                // layer 2: chart content
                Positioned.fill(child: chart),
              ],
            )
          : chart,
    );
  }
}

class DepthChartPainter extends CustomPainter {
  List<DepthEntity>? mBuyData, mSellData;
  Offset? pressOffset;
  bool isLongPress;
  int baseUnit;
  int quoteUnit;
  DepthChartColors chartColors;
  DepthChartStyle chartStyle;

  double mPaddingBottom = 32.0;
  double mWidth = 0.0, mDrawHeight = 0.0, mDrawWidth = 0.0;
  double? mBuyPointWidth, mSellPointWidth;

  Offset offset;
  DepthChartTranslations chartTranslations;

  /// Số mốc giá hiển thị ở trục dưới (>=2).
  final int bottomLabelCount;

  double? mMaxVolume, mMultiple;
  int mLineCount = 4;

  Path? mBuyPath, mSellPath;

  Paint? mBuyLinePaint,
      mSellLinePaint,
      mBuyPathPaint,
      mSellPathPaint,
      mBarrierPathPaint,
      selectPaint,
      selectBorderPaint,
      crossPaint;

  DepthChartPainter(
    this.mBuyData,
    this.mSellData,
    this.pressOffset,
    this.isLongPress,
    this.baseUnit,
    this.quoteUnit,
    this.chartColors,
    this.chartStyle,
    this.offset,
    this.chartTranslations, {
    this.bottomLabelCount = 5,
  }) {
    mBuyLinePaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.upColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = chartStyle.lineWidth;
    mSellLinePaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.dnColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = chartStyle.lineWidth;
    mBuyPathPaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.upFillPathColor;
    mSellPathPaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.dnFillPathColor;
    mBarrierPathPaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.barrierColor;
    crossPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = chartStyle.crossWidth
      ..color = chartColors.crossColor;
    selectPaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.selectFillColor;
    selectBorderPaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.selectBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = chartStyle.strokeWidth;
    mBuyPath = Path();
    mSellPath = Path();

    if (mBuyData != null &&
        mSellData != null &&
        mBuyData!.isNotEmpty &&
        mSellData!.isNotEmpty) {
      mMaxVolume = max(mBuyData!.first.vol, mSellData!.last.vol) * 1.08;
      mMultiple = mMaxVolume! / mLineCount;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (mBuyData == null ||
        mSellData == null ||
        mBuyData!.isEmpty ||
        mSellData!.isEmpty) {
      return;
    }
    mWidth = size.width;
    mDrawWidth = mWidth / 2;
    mDrawHeight = size.height - mPaddingBottom;
    canvas.save();
    drawBuy(canvas);
    drawSell(canvas);
    drawText(canvas);
    canvas.restore();
  }

  void drawBuy(Canvas canvas) {
    mBuyPointWidth =
        mDrawWidth / (mBuyData!.length <= 1 ? 1 : mBuyData!.length - 1);
    mBuyPath!.reset();
    double prevX = 0, prevY = 0;
    for (int i = 0; i < mBuyData!.length; i++) {
      final double x = mBuyPointWidth! * i;
      final double y = getY(mBuyData![i].vol);
      if (i == 0) {
        mBuyPath!.moveTo(0, y);
      } else {
        canvas.drawLine(Offset(prevX, prevY), Offset(x, y), mBuyLinePaint!);
      }
      if (i != mBuyData!.length - 1) {
        mBuyPath!.quadraticBezierTo(
          x,
          y,
          mBuyPointWidth! * (i + 1),
          getY(mBuyData![i + 1].vol),
        );
      } else {
        if (i == 0) {
          mBuyPath!.lineTo(mDrawWidth, y);
          mBuyPath!.lineTo(mDrawWidth, mDrawHeight);
          mBuyPath!.lineTo(0, mDrawHeight);
        } else {
          mBuyPath!.quadraticBezierTo(x, y, x, mDrawHeight);
          mBuyPath!.quadraticBezierTo(x, mDrawHeight, 0, mDrawHeight);
        }
        mBuyPath!.close();
      }
      prevX = x;
      prevY = y;
    }
    canvas.drawPath(mBuyPath!, mBuyPathPaint!);
  }

  void drawSell(Canvas canvas) {
    mSellPointWidth =
        mDrawWidth / (mSellData!.length <= 1 ? 1 : mSellData!.length - 1);
    mSellPath!.reset();
    double prevX = 0, prevY = 0;
    for (int i = 0; i < mSellData!.length; i++) {
      final double x = mSellPointWidth! * i + mDrawWidth;
      final double y = getY(mSellData![i].vol);
      if (i == 0) {
        mSellPath!.moveTo(mDrawWidth, y);
      } else {
        canvas.drawLine(Offset(prevX, prevY), Offset(x, y), mSellLinePaint!);
      }
      if (i != mSellData!.length - 1) {
        mSellPath!.quadraticBezierTo(
          x,
          y,
          mSellPointWidth! * (i + 1) + mDrawWidth,
          getY(mSellData![i + 1].vol),
        );
      } else {
        if (i == 0) {
          mSellPath!.lineTo(mWidth, y);
          mSellPath!.lineTo(mWidth, mDrawHeight);
          mSellPath!.lineTo(mDrawWidth, mDrawHeight);
        } else {
          mSellPath!.quadraticBezierTo(mWidth, y, x, mDrawHeight);
          mSellPath!.quadraticBezierTo(x, mDrawHeight, mDrawWidth, mDrawHeight);
        }
        mSellPath!.close();
      }
      prevX = x;
      prevY = y;
    }
    canvas.drawPath(mSellPath!, mSellPathPaint!);
  }

  void drawText(Canvas canvas) {
    double value;
    String str;
    for (int j = 0; j < mLineCount; j++) {
      value = mMaxVolume! - mMultiple! * j;
      str = NumberUtil.formatCompact(value, baseUnit);
      var tp = getTextPainter(str);
      tp.layout();
      tp.paint(
        canvas,
        Offset(mWidth - tp.width, mDrawHeight / mLineCount * j + tp.height / 2),
      );
    }

    final double startPrice = mBuyData!.first.price;
    final double endPrice = mSellData!.last.price;
    final double centerPrice =
        (mBuyData!.last.price + mSellData!.first.price) / 2;

    // Vẽ bottomLabelCount mốc giá, phân bố đều theo trục X.
    // Giá nội suy tuyến tính từng đoạn: [start..center] ở nửa trái, [center..end] ở nửa phải.
    final int n = bottomLabelCount < 2 ? 2 : bottomLabelCount;
    for (int i = 0; i < n; i++) {
      final double t = i / (n - 1); // 0..1
      final double x = t * mWidth;
      final double price = t <= 0.5
          ? startPrice + (centerPrice - startPrice) * (t * 2)
          : centerPrice + (endPrice - centerPrice) * ((t - 0.5) * 2);
      final String label = NumberUtil.formatFixed(price, quoteUnit) ?? '';
      final TextPainter tp = getTextPainter(label);
      tp.layout();
      final double dx;
      if (i == 0) {
        dx = 0;
      } else if (i == n - 1) {
        dx = mWidth - tp.width;
      } else {
        dx = (x - tp.width / 2).clamp(0.0, mWidth - tp.width);
      }
      tp.paint(canvas, Offset(dx, getBottomTextY(tp.height)));
    }

    if (isLongPress) {
      if (pressOffset!.dx <= mDrawWidth) {
        int index = _indexOfTranslateX(
          pressOffset!.dx,
          0,
          mBuyData!.length - 1,
          getBuyX,
        );
        drawLeftSelectView(canvas, index); // buy

        int indexRight = mBuyData!.length - index - 1;
        if (indexRight < mSellData!.length) {
          drawRightSelectView(canvas, indexRight);
        }
      } else {
        int index = _indexOfTranslateX(
          pressOffset!.dx,
          0,
          mSellData!.length - 1,
          getSellX,
        );
        drawRightSelectView(canvas, index); // sell
        int indexLeft = mBuyData!.length - index - 1;
        if (indexLeft >= 0 && indexLeft < mBuyData!.length) {
          drawLeftSelectView(canvas, indexLeft);
        }
      }
    }
  }

  void drawLeftSelectView(Canvas canvas, int index) {
    DepthEntity entity = mBuyData![index];
    double dx = getBuyX(index);
    double dy = getY(entity.vol);

    // draw overlay barrier model
    canvas.drawRect(Rect.fromLTRB(0, 0, dx, mDrawHeight), mBarrierPathPaint!);

    /// draw cross line
    canvas.drawDashLine(
      Offset(dx, 0),
      Offset(dx, mDrawHeight),
      crossPaint ?? Paint(),
    );

    /// draw dot
    canvas.drawCircle(
      Offset(dx, dy),
      chartStyle.dotRadius * .6,
      mBuyLinePaint!..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(dx, dy),
      chartStyle.dotRadius,
      mBuyLinePaint!..style = PaintingStyle.stroke,
    );

    _PopupPainter popupPainter = _PopupPainter(
      translations: chartTranslations,
      chartColors: chartColors,
      chartStyle: chartStyle,
      price: NumberUtil.format(entity.price, quoteUnit) ?? '',
      amount: NumberUtil.formatCompact(entity.vol, baseUnit),
    );

    dx = dx < mWidth * 0.25
        ? dx + offset.dx
        : dx - offset.dx - popupPainter.width;
    dy = (dy - popupPainter.height / 2).clamp(
      offset.dy,
      mDrawHeight - popupPainter.height - offset.dy,
    );

    Rect rect = Rect.fromLTWH(dx, dy, popupPainter.width, popupPainter.height);
    RRect boxRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(chartStyle.radius),
    );

    canvas.drawRRect(boxRect, selectPaint!);
    canvas.drawRRect(boxRect, selectBorderPaint!);
    popupPainter.paint(canvas, rect.topLeft);
  }

  void drawRightSelectView(Canvas canvas, int index) {
    DepthEntity entity = mSellData![index];
    double dx = getSellX(index);
    double dy = getY(entity.vol);

    /// draw overlay barrier model
    canvas.drawRect(
      Rect.fromLTRB(dx, 0, mWidth, mDrawHeight),
      mBarrierPathPaint!,
    );

    /// draw cross line
    canvas.drawDashLine(
      Offset(dx, 0),
      Offset(dx, mDrawHeight),
      crossPaint ?? Paint(),
    );

    /// draw dot
    canvas.drawCircle(
      Offset(dx, dy),
      chartStyle.dotRadius * .6,
      mSellLinePaint!..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(dx, dy),
      chartStyle.dotRadius,
      mSellLinePaint!..style = PaintingStyle.stroke,
    );

    _PopupPainter popupPainter = _PopupPainter(
      translations: chartTranslations,
      chartColors: chartColors,
      chartStyle: chartStyle,
      price: NumberUtil.format(entity.price, quoteUnit) ?? '',
      amount: NumberUtil.formatCompact(entity.vol, baseUnit),
    );

    dx = dx < mWidth * 0.75
        ? dx + offset.dx
        : dx - offset.dx - popupPainter.width;
    dy = (dy - popupPainter.height / 2).clamp(
      offset.dy,
      mDrawHeight - popupPainter.height - offset.dy,
    );

    Rect rect = Rect.fromLTWH(dx, dy, popupPainter.width, popupPainter.height);
    RRect boxRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(chartStyle.radius),
    );

    canvas.drawRRect(boxRect, selectPaint!);
    canvas.drawRRect(boxRect, selectBorderPaint!);
    popupPainter.paint(canvas, rect.topLeft);
  }

  int _indexOfTranslateX(
    double translateX,
    int start,
    int end,
    double Function(int) getX,
  ) {
    if (end == start || end == -1) {
      return start;
    }
    if (end - start == 1) {
      double startValue = getX(start);
      double endValue = getX(end);
      return (translateX - startValue).abs() < (translateX - endValue).abs()
          ? start
          : end;
    }
    int mid = start + (end - start) ~/ 2;
    double midValue = getX(mid);
    if (translateX < midValue) {
      return _indexOfTranslateX(translateX, start, mid, getX);
    } else if (translateX > midValue) {
      return _indexOfTranslateX(translateX, mid, end, getX);
    } else {
      return mid;
    }
  }

  double getBuyX(int position) => position * mBuyPointWidth!;

  double getSellX(int position) => position * mSellPointWidth! + mDrawWidth;

  TextPainter getTextPainter(String text) => TextPainter(
    text: TextSpan(
      text: text,
      style: chartStyle.textStyle.color != null
          ? chartStyle.textStyle
          : chartStyle.textStyle.copyWith(color: chartColors.defaultTextColor),
    ),
    textDirection: TextDirection.ltr,
  );

  double getBottomTextY(double textHeight) =>
      (mPaddingBottom - textHeight) / 2 + mDrawHeight;

  double getY(double volume) =>
      mDrawHeight - (mDrawHeight) * volume / mMaxVolume!;

  @override
  bool shouldRepaint(DepthChartPainter oldDelegate) {
    return oldDelegate.mBuyData != mBuyData ||
        oldDelegate.mSellData != mSellData ||
        oldDelegate.isLongPress != isLongPress ||
        oldDelegate.pressOffset != pressOffset;
  }
}

class _PopupPainter {
  final DepthChartColors chartColors;
  final DepthChartStyle chartStyle;

  late final TextPainter annotationsPaint;
  late final TextPainter pricePaint;
  late final TextPainter amountPaint;

  ///getter
  double get width =>
      max(pricePaint.width, amountPaint.width) + 2 * chartStyle.padding;
  double get height =>
      pricePaint.height +
      amountPaint.height +
      chartStyle.space +
      2 * chartStyle.padding;

  _PopupPainter({
    required DepthChartTranslations translations,
    required this.chartColors,
    required this.chartStyle,
    required String price,
    required String amount,
  }) {
    pricePaint = _getTextPainter(translations.price, price);
    amountPaint = _getTextPainter(translations.amount, amount);
    pricePaint.layout();
    amountPaint.layout();
  }

  void paint(Canvas canvas, Offset offset) {
    pricePaint.paint(
      canvas,
      offset + Offset(chartStyle.padding, chartStyle.padding),
    );
    amountPaint.paint(
      canvas,
      offset +
          Offset(
            chartStyle.padding,
            pricePaint.height + chartStyle.space + chartStyle.padding,
          ),
    );
  }

  TextPainter _getTextPainter(String label, String content) {
    final style = chartStyle.annotationTextStyle.color != null
        ? chartStyle.annotationTextStyle
        : chartStyle.annotationTextStyle.copyWith(
            color: chartColors.annotationColor,
          );
    return TextPainter(
      text: TextSpan(text: '$label $content', style: style),
      textAlign: TextAlign.start,
      textDirection: TextDirection.ltr,
    );
  }
}
