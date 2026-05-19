import 'dart:async';
import 'package:flutter/material.dart';
import 'package:k_chart_wikex/entity/index.dart';
import 'package:k_chart_wikex/indicator/indicator_template.dart';
import 'package:k_chart_wikex/renderer/index.dart';
import 'package:k_chart_wikex/renderer/k_chart_controller.dart';
import 'package:k_chart_wikex/utils/index.dart';
import 'renderer/base_dimension.dart';

class TimeFormat {
  static const List<String> YEAR_MONTH_DAY = [yyyy, '-', mm, '-', dd];
  static const List<String> YEAR_MONTH_DAY_WITH_HOUR = [
    yyyy,
    '-',
    mm,
    '-',
    dd,
    ' ',
    HH,
    ':',
    nn,
  ];
}

typedef WidgetDetailBuilder = Widget Function(KLineEntity entity);

class KChartWidget extends StatefulWidget {
  final List<KLineEntity>? datas;
  final List<MainIndicator> mainIndicators;

  ///warning only using MA, BOLL, SAR
  final bool volHidden;
  final List<SecondaryIndicator> secondaryIndicators;

  ///SecondaryState { MACD, KDJ, RSI, WR, CCI }
  // final Function()? onSecondaryTap;
  final bool isLine;
  final bool
  isTapShowInfoDialog; //Whether to enable click to display detailed data
  final bool hideGrid;
  final bool showNowPrice;
  final bool showInfoDialog;
  final bool materialInfoDialog; // Material Style Information Popup
  final List<String> timeFormat;
  final double mBaseHeight;
  final double? mSecondaryHeight;

  // It will be called when the screen scrolls to the end.
  // If true, it will be scrolled to the end of the right side of the screen.
  // If it is false, it will be scrolled to the end of the left side of the screen.
  final Function(bool)? onLoadMore;

  final int fixedLength;
  final int flingTime;
  final double flingRatio;
  final Curve flingCurve;
  final Function(bool)? isOnDrag;
  final KChartColors chartColors;
  final KChartStyle chartStyle;
  final VerticalTextAlignment verticalTextAlignment;
  final bool isTrendLine;
  final double xFrontPadding;
  final WidgetDetailBuilder detailBuilder;
  final double minScale;
  final double maxScale;
  final double? livePrice;

  final KChartController? controller;
  final bool isLoadingMore;

  const KChartWidget(
    this.datas,
    this.chartStyle,
    this.chartColors, {
    required this.detailBuilder,
    required this.isTrendLine,
    this.livePrice,
    this.xFrontPadding = 100,
    this.mainIndicators = const [],
    this.secondaryIndicators = const [],
    // this.onSecondaryTap,
    this.volHidden = false,
    this.isLine = false,
    this.isTapShowInfoDialog = false,
    this.hideGrid = false,
    this.showNowPrice = true,
    this.showInfoDialog = true,
    this.materialInfoDialog = true,
    this.timeFormat = TimeFormat.YEAR_MONTH_DAY,
    this.onLoadMore,
    this.fixedLength = 2,
    this.flingTime = 600,
    this.flingRatio = 0.5,
    this.flingCurve = Curves.decelerate,
    this.isOnDrag,
    this.verticalTextAlignment = VerticalTextAlignment.right,
    this.mBaseHeight = 360,
    this.mSecondaryHeight,
    this.controller,
    this.minScale = 0.5,
    this.maxScale = 2.2,
    this.isLoadingMore = false,
    super.key,
  });

  @override
  _KChartWidgetState createState() => _KChartWidgetState();
}

class _KChartWidgetState extends State<KChartWidget>
    with TickerProviderStateMixin {
  final StreamController<InfoWindowEntity?> mInfoWindowStream =
      StreamController<InfoWindowEntity?>();
  double mScaleX = 1.0, mScrollX = 0.0, mSelectX = 0.0;
  double mScaleY = 1.0;
  double _scaleYDragStart = 0.0;
  AnimationController? _controller;
  Animation<double>? aniX;

  //For TrendLine
  List<TrendLine> lines = [];
  double? changeinXposition;
  double? changeinYposition;
  double mSelectY = 0.0;
  bool waitingForOtherPairofCords = false;
  bool enableCordRecord = false;

  double getMinScrollX() {
    return mScaleX;
  }

  double _lastScale = 1.0;
  bool isScale = false, isDrag = false, isLongPress = false, isOnTap = false;

  @override
  void dispose() {
    mInfoWindowStream.sink.close();
    mInfoWindowStream.close();
    _controller?.dispose();
    widget.controller?.removeListener(_onController);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onController);
  }

  void _onController() {
    // 1: reset 2: zoom
    if (widget.controller!.action == 1) {
      mScaleX = 1.0;
      mScrollX = 0.0;
      mSelectX = 0.0;
    } else if (widget.controller!.action == 2) {
      // Zoom logic
      mScaleX = (mScaleX + widget.controller!.zoom).clamp(
        widget.minScale,
        widget.maxScale,
      );
    }
    notifyChanged();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.datas != null && widget.datas!.isEmpty) {
      mScrollX = mSelectX = 0.0;
      mScaleX = 1.0;
    }
    final BaseDimension baseDimension = BaseDimension(
      mBaseHeight: widget.mBaseHeight,
      mSecondaryHeight: widget.mSecondaryHeight ?? widget.mBaseHeight * .2,
      volHidden: widget.volHidden,
      secondaryIndicators: widget.secondaryIndicators,
      mainIndicators: widget.mainIndicators,
    );
    final _painter = ChartPainter(
      widget.chartStyle,
      widget.chartColors,
      livePrice: widget.livePrice,
      baseDimension: baseDimension,
      lines: lines, //For TrendLine
      sink: mInfoWindowStream.sink,
      xFrontPadding: widget.xFrontPadding,
      isTrendLine: widget.isTrendLine, //For TrendLine
      selectY: mSelectY, //For TrendLine
      datas: widget.datas,
      scaleX: mScaleX,
      scaleY: mScaleY,
      scrollX: mScrollX,
      selectX: mSelectX,
      isLongPass: isLongPress,
      isOnTap: isOnTap,
      isTapShowInfoDialog: widget.isTapShowInfoDialog,
      mainIndicators: widget.mainIndicators,
      volHidden: widget.volHidden,
      secondaryIndicators: widget.secondaryIndicators,
      isLine: widget.isLine,
      hideGrid: widget.hideGrid,
      showNowPrice: widget.showNowPrice,
      fixedLength: widget.fixedLength,
      verticalTextAlignment: widget.verticalTextAlignment,
    );

    return GestureDetector(
      onTapUp: (details) {
        if (!widget.isTrendLine &&
            _painter.isInMainRect(details.localPosition)) {
          isOnTap = true;
          if (mSelectX != details.localPosition.dx &&
              widget.isTapShowInfoDialog) {
            mSelectX = details.localPosition.dx;
            notifyChanged();
          }
        }
        if (widget.isTrendLine && !isLongPress && enableCordRecord) {
          enableCordRecord = false;
          Offset p1 = Offset(getTrendLineX(), mSelectY);
          if (!waitingForOtherPairofCords) {
            lines.add(
              TrendLine(p1, Offset(-1, -1), trendLineMax!, trendLineScale!),
            );
          }
          if (waitingForOtherPairofCords) {
            var a = lines.last;
            lines.removeLast();
            lines.add(TrendLine(a.p1, p1, trendLineMax!, trendLineScale!));
            waitingForOtherPairofCords = false;
          } else {
            waitingForOtherPairofCords = true;
          }
          notifyChanged();
        }
      },
      onScaleStart: (details) {
        isScale = true;
        isOnTap = false;
        isLongPress = false;
        _stopAnimation();
        _lastScale = mScaleX;
      },
      onScaleUpdate: (details) {
        if (details.scale != 1.0) {
          mScaleX = (_lastScale * details.scale).clamp(0.5, 2.2);
        } else {
          mScrollX = (mScrollX + details.focalPointDelta.dx / mScaleX)
              .clamp(0.0, ChartPainter.maxScrollX)
              .toDouble();
        }
        if (!widget.isLoadingMore &&
            widget.onLoadMore != null &&
            ChartPainter.maxScrollX > 0 &&
            mScrollX >= ChartPainter.maxScrollX * 0.8) {
          widget.onLoadMore!(true);
        }
        notifyChanged();
      },
      onScaleEnd: (details) {
        isScale = false;
        _lastScale = mScaleX;
        final velocity = details.velocity.pixelsPerSecond.dx;
        _onFling(velocity);
      },
      onLongPressStart: (details) {
        isOnTap = false;
        isLongPress = true;
        if ((mSelectX != details.localPosition.dx ||
                mSelectY != details.globalPosition.dy) &&
            !widget.isTrendLine) {
          mSelectX = details.localPosition.dx;
          notifyChanged();
        }
        if (widget.isTrendLine && changeinXposition == null) {
          mSelectX = changeinXposition = details.localPosition.dx;
          mSelectY = changeinYposition = details.globalPosition.dy;
          notifyChanged();
        }
        if (widget.isTrendLine && changeinXposition != null) {
          changeinXposition = details.localPosition.dx;
          changeinYposition = details.globalPosition.dy;
          notifyChanged();
        }
      },
      onLongPressMoveUpdate: (details) {
        if ((mSelectX != details.localPosition.dx ||
                mSelectY != details.globalPosition.dy) &&
            !widget.isTrendLine) {
          mSelectX = details.localPosition.dx;
          mSelectY = details.localPosition.dy;
          notifyChanged();
        }
        if (widget.isTrendLine) {
          mSelectX = mSelectX + (details.localPosition.dx - changeinXposition!);
          changeinXposition = details.localPosition.dx;
          mSelectY =
              mSelectY + (details.globalPosition.dy - changeinYposition!);
          changeinYposition = details.globalPosition.dy;
          notifyChanged();
        }
      },
      onLongPressEnd: (details) {
        isLongPress = false;
        enableCordRecord = true;
        mInfoWindowStream.sink.add(null);
        notifyChanged();
      },
      child: Stack(
        children: [
          CustomPaint(
            size: Size(double.infinity, baseDimension.mDisplayHeight),
            painter: _painter,
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onVerticalDragStart: (details) {
                _scaleYDragStart = details.localPosition.dy;
              },
              onVerticalDragUpdate: (details) {
                final double delta =
                    details.localPosition.dy - _scaleYDragStart;
                mScaleY = (mScaleY - delta * 0.005).clamp(0.3, 5.0);
                _scaleYDragStart = details.localPosition.dy;
                notifyChanged();
              },
              onDoubleTap: () {
                mScaleY = 1.0;
                notifyChanged();
              },
              child: Container(color: Colors.transparent, width: 100),
            ),
          ),
          if (widget.showInfoDialog) _buildInfoDialog(),
        ],
      ),
    );
  }

  void _stopAnimation({bool needNotify = true}) {
    if (_controller != null && _controller!.isAnimating) {
      _controller!.stop();
      _onDragChanged(false);
      if (needNotify) {
        notifyChanged();
      }
    }
  }

  void _onDragChanged(bool isOnDrag) {
    isDrag = isOnDrag;
    if (widget.isOnDrag != null) {
      widget.isOnDrag!(isDrag);
    }
  }

  void _onFling(double x) {
    _controller = AnimationController(
      duration: Duration(milliseconds: widget.flingTime),
      vsync: this,
    );
    aniX = null;
    aniX = Tween<double>(begin: mScrollX, end: x * widget.flingRatio + mScrollX)
        .animate(
          CurvedAnimation(parent: _controller!.view, curve: widget.flingCurve),
        );
    aniX!.addListener(() {
      mScrollX = aniX!.value;
      if (mScrollX <= 0) {
        mScrollX = 0;
        _stopAnimation();
      } else if (mScrollX >= ChartPainter.maxScrollX) {
        mScrollX = ChartPainter.maxScrollX;
        if (widget.onLoadMore != null) {
          widget.onLoadMore!(false);
        }
        _stopAnimation();
      } else if (!widget.isLoadingMore &&
          widget.onLoadMore != null &&
          ChartPainter.maxScrollX > 0 &&
          mScrollX >= ChartPainter.maxScrollX * 0.8) {
        widget.onLoadMore!(true);
      }
      notifyChanged();
    });
    aniX!.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _onDragChanged(false);
        notifyChanged();
      }
    });
    _controller!.forward();
  }

  void notifyChanged() => setState(() {});

  late List<String> infos;

  Widget _buildInfoDialog() {
    return StreamBuilder<InfoWindowEntity?>(
      stream: mInfoWindowStream.stream,
      builder: (context, snapshot) {
        if ((!isLongPress && !isOnTap) ||
            widget.isLine == true ||
            !snapshot.hasData ||
            snapshot.data?.kLineEntity == null) {
          return const SizedBox();
        }
        KLineEntity entity = snapshot.data!.kLineEntity;
        if (snapshot.data!.isLeft) {
          return Positioned(
            left: 10.0,
            child: widget.detailBuilder.call(entity),
          );
        }
        return Positioned(
          right: 10.0,
          child: widget.detailBuilder.call(entity),
        );
      },
    );
  }
}
