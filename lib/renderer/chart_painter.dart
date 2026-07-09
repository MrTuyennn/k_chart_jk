import 'dart:async' show StreamSink;
import 'package:flutter/material.dart';
import 'package:k_chart_wikex/extension/canvas_extension.dart';
import 'package:k_chart_wikex/utils/index.dart';
import '../entity/info_window_entity.dart';
import '../entity/k_line_entity.dart';
import 'base_chart_painter.dart';
import 'base_chart_renderer.dart';
import 'main_renderer.dart';
import 'secondary_renderer.dart';
import 'vol_renderer.dart';

class TrendLine {
  final Offset p1;
  final Offset p2;
  final double maxHeight;
  final double scale;

  TrendLine(this.p1, this.p2, this.maxHeight, this.scale);
}

double? trendLineX;

double getTrendLineX() {
  return trendLineX ?? 0;
}

class ChartPainter extends BaseChartPainter {
  final List<TrendLine> lines; //For TrendLine
  final bool isTrendLine; //For TrendLine
  bool isrecordingCord = false; //For TrendLine
  final double selectY; //For TrendLine
  static double get maxScrollX => BaseChartPainter.maxScrollX;
  late BaseChartRenderer mMainRenderer;
  VolRenderer? mVolRenderer;
  Set<BaseChartRenderer> mSecondaryRendererList = {};
  StreamSink<InfoWindowEntity?> sink;
  Color? upColor, dnColor;
  Color? ma5Color, ma10Color, ma30Color;
  Color? volColor;
  Color? macdColor, difColor, deaColor, jColor;
  int fixedLength;
  final KChartColors chartColors;
  late Paint paintCross, selectPointPaint, selectorBorderPaint;
  late Paint nowPriceSelectorPaint, nowPriceSelectorBorderPaint, nowPriceLinePaint;
  late Paint _bgPaint;
  late Paint _trendLinePaint, _trendLineStrokePaint, _trendLineSegmentPaint;
  final bool hideGrid;
  final bool showNowPrice;
  final VerticalTextAlignment verticalTextAlignment;
  final double? livePrice;
  // khi true, bỏ qua drawBg để canvas trong suốt — dùng khi có backgroundLogo widget ở layer dưới
  final bool skipBg;

  ChartPainter(
    super.chartStyle,
    this.chartColors, {
    required this.lines, //For TrendLine
    required this.isTrendLine, //For TrendLine
    required this.selectY, //For TrendLine
    this.livePrice,
    required this.sink,
    required super.datas,
    required super.scaleX,
    required super.scaleY,
    required super.scrollX,
    required super.isLongPress,
    required super.selectX,
    required super.xFrontPadding,
    required super.baseDimension,
    super.isOnTap,
    super.isTapShowInfoDialog,
    required this.verticalTextAlignment,
    super.mainIndicators,
    super.volHidden,
    super.secondaryIndicators,
    super.isLine = false,
    super.offsetY = 0.0,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.fixedLength = 2,
    this.skipBg = false,
  }) {
    paintCross = Paint()
      ..color = chartColors.crossColor
      ..strokeWidth = chartStyle.crossWidth
      ..isAntiAlias = true;
    selectPointPaint = Paint()
      ..isAntiAlias = true
      ..color = chartColors.selectFillColor;
    selectorBorderPaint = Paint()
      ..isAntiAlias = true
      ..strokeWidth = chartStyle.borderWidth
      ..style = PaintingStyle.stroke
      ..color = chartColors.selectBorderColor;

    nowPriceSelectorPaint = Paint()
      ..color = chartColors.bgColor
      ..isAntiAlias = true;
    nowPriceSelectorBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = chartStyle.borderWidth
      ..isAntiAlias = true;
    nowPriceLinePaint = Paint()
      ..strokeWidth = chartStyle.nowPriceLineWidth
      ..isAntiAlias = true;
    _bgPaint = Paint()..color = chartColors.bgColor;
    _trendLinePaint = Paint()
      ..color = chartColors.trendLineColor
      ..strokeWidth = 1
      ..isAntiAlias = true;
    _trendLineStrokePaint = Paint()
      ..color = chartColors.trendLineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    _trendLineSegmentPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2;
  }

  @override
  void initChartRenderer() {
    mMainRenderer = MainRenderer(
      mMainRect,
      mMainMaxValue,
      mMainMinValue,
      mTopPadding,
      mainIndicators,
      isLine,
      fixedLength,
      chartStyle,
      chartColors,
      scaleX,
      verticalTextAlignment,
      mBottomPadding,
      scaleY,
      (mMainRect.top + mMainRect.bottom) / 2,
      offsetY,
    );
    if (mVolRect != null) {
      mVolRenderer = VolRenderer(
        mVolRect!,
        mVolMaxValue,
        mVolMinValue,
        mChildPadding,
        fixedLength,
        chartStyle,
        chartColors,
      );
    } else {
      mVolRenderer = null;
    }
    mSecondaryRendererList.clear();
    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      mSecondaryRendererList.add(
        SecondaryRenderer(
          mSecondaryRectList[i].mRect,
          mSecondaryRectList[i].mMaxValue,
          mSecondaryRectList[i].mMinValue,
          mChildPadding,
          secondaryIndicators[i],
          fixedLength,
          chartStyle,
          chartColors,
        ),
      );
    }
  }

  @override
  void drawBg(Canvas canvas, Size size) {
    if (skipBg) return;
    canvas.drawRect(
      Rect.fromLTRB(0, 0, mMainRect.width, mMainRect.height + mTopPadding),
      _bgPaint,
    );
    if (mVolRect != null) {
      canvas.drawRect(
        Rect.fromLTRB(0, mMainRect.bottom, mVolRect!.width, mVolRect!.bottom),
        _bgPaint,
      );
    }
    for (int i = 0; i < mSecondaryRectList.length; ++i) {
      final r = mSecondaryRectList[i].mRect;
      canvas.drawRect(
        Rect.fromLTRB(0, r.top - mChildPadding, r.width, r.bottom),
        _bgPaint,
      );
    }
    canvas.drawRect(mDateRect, _bgPaint);
  }

  @override
  void drawGrid(canvas) {
    if (!hideGrid) {
      mMainRenderer.drawGrid(canvas, mGridRows, mGridColumns);
      mVolRenderer?.drawGrid(canvas, mGridRows, mGridColumns);
      for (final element in mSecondaryRendererList) {
        element.drawGrid(canvas, mGridRows, mGridColumns);
      }
    }
  }

  @override
  void drawChart(Canvas canvas, Size size) {
    // Đường tham chiếu ngang (vd 20/80 của StochRSI) vẽ ở screen space,
    // trước khi translate/scale để không bị giãn theo scaleX và luôn
    // nằm phía sau đường indicator. Cùng gate bởi hideGrid như drawGrid ở trên,
    // vì đây cũng là một dạng đường lưới nền.
    if (!hideGrid) {
      for (final element in mSecondaryRendererList) {
        element.drawReferenceLines(canvas);
      }
    }

    canvas.save();
    canvas.translate(mTranslateX * scaleX, 0.0);
    canvas.scale(scaleX, 1.0);

    // TODO: scaleY dùng canvas transform thay vì scale value range từng component
    // giúp main chart và volume scale cùng nhau như 1 đơn vị (tương tự cách scaleX hoạt động)
    canvas.save();
    // Clip theo chiều Y vào đúng vùng mMainRect — tránh nội dung tràn ra ngoài
    // đè lên time bar, secondary indicators hoặc top padding khi scaleY thay đổi
    canvas.clipRect(
      Rect.fromLTRB(-mDataLen - mWidth, mMainRect.top, mDataLen + mWidth, mMainRect.bottom),
    );
    final double centerY = (mMainRect.top + mMainRect.bottom) / 2;
    // offsetY dịch chuyển chart dọc (pan Y), neo tại centerY để scaleY không bị lệch
    canvas.translate(0, centerY * (1 - scaleY) + offsetY);
    canvas.scale(1.0, scaleY);
    for (int i = mStartIndex; datas != null && i <= mStopIndex; i++) {
      KLineEntity? curPoint = datas?[i];
      if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : datas![i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);
      mMainRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
    }
    canvas.restore();

    // VolRenderer + SecondaryRenderer cùng nằm ngoài scope scaleY của main
    // → panel volume + indicator phụ không bị giãn khi user zoom dọc nến.
    for (int i = mStartIndex; datas != null && i <= mStopIndex; i++) {
      KLineEntity? curPoint = datas?[i];
      if (curPoint == null) continue;
      KLineEntity lastPoint = i == 0 ? curPoint : datas![i - 1];
      double curX = getX(i);
      double lastX = i == 0 ? curX : getX(i - 1);
      mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      for (final element in mSecondaryRendererList) {
        element.drawChart(lastPoint, curPoint, lastX, curX, size, canvas);
      }
    }

    if ((isLongPress || (isTapShowInfoDialog && isOnTap)) && !isTrendLine) {
      drawCrossLine(canvas, size);
    }
    if (isTrendLine) drawTrendLines(canvas, size);
    canvas.restore();
  }

  @override
  void drawVerticalText(canvas) {
    var textStyle = getTextStyle(chartColors.defaultTextColor);
    if (!hideGrid) {
      mMainRenderer.drawVerticalText(canvas, textStyle, mGridRows);
    }
    mVolRenderer?.drawVerticalText(canvas, textStyle, mGridRows);
    for (final element in mSecondaryRendererList) {
      element.drawVerticalText(canvas, textStyle, mGridRows);
    }
  }

  @override
  void drawDate(Canvas canvas, Size size) {
    if (datas == null) return;

    double columnSpace = size.width / mGridColumns;
    double startX = getX(mStartIndex) - mPointWidth / 2;
    double stopX = getX(mStopIndex) + mPointWidth / 2;
    double x = 0.0;
    double y = 0.0;

    for (var i = 0; i <= mGridColumns; ++i) {
      double translateX = xToTranslateX(columnSpace * i);
      if (translateX < startX || translateX > stopX) continue;

      int index = indexOfTranslateX(translateX);
      TextPainter tp = getTextPainter(getDate(datas![index].time), null);
      y = mDateRect.top + (mBottomPadding - tp.height) / 2;
      x = columnSpace * i - tp.width / 2;
      if (x < 0) x = 0;
      if (x > size.width - tp.width) x = size.width - tp.width;
      tp.paint(canvas, Offset(x, y));
    }
  }

  /// draw the cross line. when user focus
  @override
  void drawCrossLineText(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);

    TextPainter tp = getTextPainter(
      NumberUtil.formatFixed(point.close, fixedLength),
      chartColors.crossTextColor,
    );
    double textHeight = tp.height;
    double textWidth = tp.width;

    double w1 = 5;
    double w2 = 3;
    double r = textHeight / 2 + w2;
    double y = getMainY(point.close);
    double x;
    double space = 4.0;
    bool isLeft = false;
    if (translateXtoX(getX(index)) < mWidth / 2) {
      isLeft = false;
      x = space;
      RRect rect = RRect.fromLTRBR(
        x,
        y - r,
        x + textWidth + 2 * w1,
        y + r,
        Radius.circular(2.0),
      );
      canvas.drawRRect(rect, selectPointPaint);
      canvas.drawRRect(rect, selectorBorderPaint);
      tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
    } else {
      isLeft = true;
      x = mWidth - textWidth - 2 * w1 - space;
      RRect rect = RRect.fromLTRBR(
        x,
        y - r,
        mWidth - space,
        y + r,
        Radius.circular(2.0),
      );
      canvas.drawRRect(rect, selectPointPaint);
      canvas.drawRRect(rect, selectorBorderPaint);
      tp.paint(canvas, Offset(x + w1, y - textHeight / 2));
    }

    TextPainter dateTp = getTextPainter(
      getDate(point.time),
      chartColors.crossTextColor,
    );
    textWidth = dateTp.width;
    r = textHeight / 2;
    x = translateXtoX(getX(index));
    y = mDateRect.top;

    if (x < textWidth + 2 * w1) {
      x = 1 + textWidth / 2 + w1;
    } else if (mWidth - x < textWidth + 2 * w1) {
      x = mWidth - 1 - textWidth / 2 - w1;
    }

    RRect rectBox = RRect.fromLTRBR(
      x - textWidth / 2 - w1,
      y,
      x + textWidth / 2 + w1,
      mDateRect.bottom,
      Radius.circular(2.0),
    );

    // double baseLine = textHeight / 2;
    canvas.drawRRect(rectBox, selectPointPaint);
    canvas.drawRRect(rectBox, selectorBorderPaint);

    dateTp.paint(
      canvas,
      Offset(
        x - textWidth / 2,
        mDateRect.top + (mDateRect.height - dateTp.height) / 2,
      ),
    );

    //Long press to display the details of this data
    sink.add(InfoWindowEntity(point, isLeft: isLeft));
  }

  @override
  void drawText(Canvas canvas, KLineEntity data, double x) {
    // Khi long press / tap: hiển thị data của nến được chọn (cross line)
    // Bình thường: data đến từ getItem(mStopIndex) — candle phải nhất đang thấy
    if (isLongPress || (isTapShowInfoDialog && isOnTap)) {
      var index = calculateSelectedX(selectX);
      data = getItem(index);
    }
    mMainRenderer.drawText(canvas, data, x);
    mVolRenderer?.drawText(canvas, data, x);
    for (final element in mSecondaryRendererList) {
      element.drawText(canvas, data, x);
    }
  }

  @override
  void drawMaxAndMin(Canvas canvas) {
    if (isLine) return;
    //plot maxima and minima
    double x = translateXtoX(getX(mMainMinIndex));
    double y = _applyScaleY(getMainY(mMainLowMinValue));
    if (x < mWidth / 2) {
      //draw right
      TextPainter tp = getTextPainter(
        "── ${NumberUtil.formatFixed(mMainLowMinValue, fixedLength) ?? ''}",
        chartColors.minColor,
      );
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
        "${NumberUtil.formatFixed(mMainLowMinValue, fixedLength) ?? ''} ──",
        chartColors.minColor,
      );
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
    x = translateXtoX(getX(mMainMaxIndex));
    y = _applyScaleY(getMainY(mMainHighMaxValue));
    if (x < mWidth / 2) {
      //draw right
      TextPainter tp = getTextPainter(
        "── ${NumberUtil.formatFixed(mMainHighMaxValue, fixedLength) ?? ''}",
        chartColors.maxColor,
      );
      tp.paint(canvas, Offset(x, y - tp.height / 2));
    } else {
      TextPainter tp = getTextPainter(
        "${NumberUtil.formatFixed(mMainHighMaxValue, fixedLength) ?? ''} ──",
        chartColors.maxColor,
      );
      tp.paint(canvas, Offset(x - tp.width, y - tp.height / 2));
    }
  }

  @override
  void drawNowPrice(Canvas canvas) {
    if (!showNowPrice) return;
    if (datas == null) return;

    // ưu tiên livePrice từ socket, fallback về datas.last.close
    final double value = livePrice ?? datas!.last.close;

    double y = _applyScaleY(getMainY(value));

    // giữ trong vùng hiển thị (đã tính scaleY)
    if (y > _applyScaleY(getMainY(mMainLowMinValue))) y = _applyScaleY(getMainY(mMainLowMinValue));
    if (y < _applyScaleY(getMainY(mMainHighMaxValue))) y = _applyScaleY(getMainY(mMainHighMaxValue));

    // màu dựa theo livePrice so với open của nến cuối
    Color priceColor = value >= datas!.last.open
        ? chartColors.nowPriceUpColor
        : chartColors.nowPriceDnColor;

    nowPriceSelectorBorderPaint.color = priceColor;
    nowPriceLinePaint.color = priceColor;

    // vẽ đường kẻ ngang
    canvas.drawDashLine(
      Offset(0, y),
      Offset(-mTranslateX + mWidth / scaleX, y),
      nowPriceLinePaint,
    );

    // vẽ label giá
    TextPainter tp = getTextPainter(
      NumberUtil.formatFixed(value, fixedLength) ?? '',
      priceColor,
    );

    double paddingX = 3, paddingY = 1.5;
    double space = 5.0;
    double offsetX;
    switch (verticalTextAlignment) {
      case VerticalTextAlignment.left:
        offsetX = space;
        break;
      case VerticalTextAlignment.right:
        offsetX = mWidth - tp.width - paddingX * 2 - space;
        break;
    }

    double top = y - tp.height / 2;
    RRect rect = RRect.fromLTRBR(
      offsetX,
      top - paddingY,
      offsetX + tp.width + paddingX * 2,
      top + tp.height + paddingY * 2,
      Radius.circular(2.0),
    );
    canvas.drawRRect(rect, nowPriceSelectorPaint);
    canvas.drawRRect(rect, nowPriceSelectorBorderPaint);
    tp.paint(canvas, Offset(offsetX + paddingX, top));
  }

  void drawTrendLines(Canvas canvas, Size size) {
    final index = calculateSelectedX(selectX);
    final double x = getX(index);
    trendLineX = x;
    final double y = selectY;

    canvas.drawLine(Offset(x, mTopPadding), Offset(x, size.height), _trendLinePaint);
    canvas.drawLine(
      Offset(-mTranslateX, y),
      Offset(-mTranslateX + mWidth / scaleX, y),
      _trendLinePaint,
    );
    canvas.drawOval(
      scaleX >= 1
          ? Rect.fromCenter(center: Offset(x, y), height: 15.0 * scaleX, width: 15.0)
          : Rect.fromCenter(center: Offset(x, y), height: 10.0, width: 10.0 / scaleX),
      _trendLineStrokePaint,
    );

    for (final element in lines) {
      final y1 = -((element.p1.dy - 35) / element.scale) + element.maxHeight;
      final y2 = -((element.p2.dy - 35) / element.scale) + element.maxHeight;
      final a = (trendLineMax! - y1) * trendLineScale! + trendLineContentRec!;
      final b = (trendLineMax! - y2) * trendLineScale! + trendLineContentRec!;
      canvas.drawLine(
        Offset(element.p1.dx, a),
        element.p2 == Offset(-1, -1) ? Offset(x, y) : Offset(element.p2.dx, b),
        _trendLineSegmentPaint,
      );
    }
  }

  ///draw cross lines
  @override
  void drawCrossLine(Canvas canvas, Size size) {
    var index = calculateSelectedX(selectX);
    KLineEntity point = getItem(index);
    double x = getX(index);
    double y = getMainY(point.close);

    // K-line chart vertical line
    canvas.drawDashLine(Offset(x, 0), Offset(x, size.height), paintCross);

    // K-line chart horizontal line
    canvas.drawDashLine(
      Offset(-mTranslateX, y),
      Offset(-mTranslateX + mWidth / scaleX, y),
      paintCross,
    );

    if (scaleX >= 1) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), height: 4.0 * scaleX, width: 4.0),
        paintCross,
      );
    } else {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), height: 4.0, width: 4.0 / scaleX),
        paintCross,
      );
    }
  }

  TextPainter getTextPainter(String? text, Color? color) {
    color ??= chartColors.defaultTextColor;
    TextSpan span = TextSpan(text: text, style: getTextStyle(color));
    TextPainter tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    return tp;
  }

  static final Map<int, String> _dateStringCache = {};
  static List<String>? _cacheFormats;

  String getDate(int? date) {
    if (date == null) return '';
    if (!_formatsEqual(_cacheFormats, mFormats)) {
      _dateStringCache.clear();
      _cacheFormats = mFormats;
    }
    return _dateStringCache.putIfAbsent(
      date,
      () => dateFormat(DateTime.fromMillisecondsSinceEpoch(date), mFormats),
    );
  }

  static bool _formatsEqual(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  double getMainY(double y) => mMainRenderer.getY(y);

  // Chuyển Y gốc sang Y screen — dùng cho labels vẽ ngoài canvas transform (nowPrice, maxMin)
  // công thức đảo ngược của canvas.translate + canvas.scale, có tính offsetY
  double _applyScaleY(double rawY) {
    final double centerY = (mMainRect.top + mMainRect.bottom) / 2;
    return (centerY + (rawY - centerY) * scaleY + offsetY)
        .clamp(mMainRect.top, mMainRect.bottom);
  }

  @override
  bool shouldRepaint(BaseChartPainter oldDelegate) {
    if (oldDelegate is ChartPainter) {
      if (oldDelegate.livePrice != livePrice ||
          oldDelegate.isTrendLine != isTrendLine ||
          oldDelegate.selectY != selectY ||
          !_trendLinesEqual(oldDelegate.lines, lines)) {
        return true;
      }
    }
    return super.shouldRepaint(oldDelegate);
  }

  static bool _trendLinesEqual(List<TrendLine> a, List<TrendLine> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      final TrendLine x = a[i], y = b[i];
      if (x.p1 != y.p1 ||
          x.p2 != y.p2 ||
          x.maxHeight != y.maxHeight ||
          x.scale != y.scale) {
        return false;
      }
    }
    return true;
  }

  bool isInMainRect(Offset point) => mMainRect.contains(point);
}
