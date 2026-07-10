import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:k_chart_wikex/k_chart_plus.dart';

import '../market/order_book.dart';

enum MainIndicatorType { ma, boll, ema, superTrend, zigzag, avl }

enum SecondaryIndicatorType {
  macd,
  kdj,
  rsi,
  wr,
  cci,
  obv,
  trix,
  mtm,
  stochRsi,
}

enum ChartTimeframe {
  m15('15m', Duration(minutes: 15), '15', '15min'),
  h1('1H', Duration(hours: 1), '60', '1hour'),
  h4('4H', Duration(hours: 4), '240', '4hour'),
  d1('1D', Duration(days: 1), '1D', '1day');

  const ChartTimeframe(
    this.label,
    this.interval,
    this.restResolution,
    this.wsPeriod,
  );

  final String label;
  final Duration interval;

  /// Query param `resolution` của REST history (phút hoặc "1D").
  final String restResolution;

  /// Field `period` trong payload WS kline — dùng lọc frame theo khung.
  final String wsPeriod;
}

/// Toàn bộ data/business state của demo chart. View chỉ đọc field/getter ở
/// đây và dispatch event — không tự tính toán hay giữ state nghiệp vụ nào.
class ChartState extends Equatable {
  const ChartState({
    required this.data,
    required this.timeframe,
    required this.mainTypes,
    required this.secondaryTypes,
    required this.savedChartScale,
    required this.isLine,
    required this.volHidden,
    required this.isDark,
    required this.showDepth,
    required this.depthBottomLabelCount,
    required this.isFetching,
    required this.hasMoreHistory,
    required this.isLive,
    this.livePrice,
    this.orderBook,
    this.error,
  });

  final List<KLineEntity> data;
  final ChartTimeframe timeframe;
  final Set<MainIndicatorType> mainTypes;
  final Set<SecondaryIndicatorType> secondaryTypes;
  final KChartScaleState savedChartScale;
  final bool isLine;
  final bool volHidden;
  final bool isDark;
  final bool showDepth;
  final int depthBottomLabelCount;
  final bool isFetching;

  /// false khi REST history trả rỗng — hết nến cũ để kéo thêm.
  final bool hasMoreHistory;
  final bool isLive;

  /// Giá tick mới nhất từ WS (thumb/kline — event tới sau thắng), tách khỏi
  /// [data] để vẽ đường now-price mà không phải rebuild list nến.
  final double? livePrice;

  /// Snapshot sổ lệnh 2 phía merge từ WS trade-plate (BUY/SELL đến riêng lẻ).
  /// null khi chưa nhận được message nào.
  final OrderBookSnapshot? orderBook;

  /// Lỗi tải dữ liệu (REST) — null khi bình thường.
  final String? error;

  static const int initialBatchSize = 200;
  static const int loadMoreBatchSize = 50;

  /// Sentinel để phân biệt "không đổi" với "set về null" cho [error].
  static const Object _unset = Object();

  ChartState copyWith({
    List<KLineEntity>? data,
    ChartTimeframe? timeframe,
    Set<MainIndicatorType>? mainTypes,
    Set<SecondaryIndicatorType>? secondaryTypes,
    KChartScaleState? savedChartScale,
    bool? isLine,
    bool? volHidden,
    bool? isDark,
    bool? showDepth,
    int? depthBottomLabelCount,
    bool? isFetching,
    bool? hasMoreHistory,
    bool? isLive,
    double? livePrice,
    OrderBookSnapshot? orderBook,
    Object? error = _unset,
  }) {
    return ChartState(
      data: data ?? this.data,
      timeframe: timeframe ?? this.timeframe,
      mainTypes: mainTypes ?? this.mainTypes,
      secondaryTypes: secondaryTypes ?? this.secondaryTypes,
      savedChartScale: savedChartScale ?? this.savedChartScale,
      isLine: isLine ?? this.isLine,
      volHidden: volHidden ?? this.volHidden,
      isDark: isDark ?? this.isDark,
      showDepth: showDepth ?? this.showDepth,
      depthBottomLabelCount:
          depthBottomLabelCount ?? this.depthBottomLabelCount,
      isFetching: isFetching ?? this.isFetching,
      hasMoreHistory: hasMoreHistory ?? this.hasMoreHistory,
      isLive: isLive ?? this.isLive,
      livePrice: livePrice ?? this.livePrice,
      orderBook: orderBook ?? this.orderBook,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }

  static const List<MainIndicatorType> _mainOrder = [
    MainIndicatorType.ma,
    MainIndicatorType.boll,
    MainIndicatorType.ema,
    MainIndicatorType.superTrend,
    MainIndicatorType.zigzag,
    MainIndicatorType.avl,
  ];

  static const List<SecondaryIndicatorType> _secondaryOrder = [
    SecondaryIndicatorType.macd,
    SecondaryIndicatorType.kdj,
    SecondaryIndicatorType.rsi,
    SecondaryIndicatorType.wr,
    SecondaryIndicatorType.cci,
    SecondaryIndicatorType.obv,
    SecondaryIndicatorType.trix,
    SecondaryIndicatorType.mtm,
    SecondaryIndicatorType.stochRsi,
  ];

  /// Instance indicator MỚI mỗi lần gọi — cố ý KHÔNG đưa vào [props], vì
  /// reference đổi mỗi lần dù [mainTypes] không đổi sẽ phá Equatable. Nguồn
  /// sự thật duy nhất cho equality là [mainTypes]/[secondaryTypes].
  List<MainIndicator> get mainIndicators => _mainOrder
      .where(mainTypes.contains)
      .map<MainIndicator>(
        (t) => switch (t) {
          MainIndicatorType.ma => MAIndicator(),
          MainIndicatorType.boll => BOLLIndicator(),
          MainIndicatorType.ema => EMAIndicator(),
          MainIndicatorType.superTrend => SuperTrendIndicator(),
          MainIndicatorType.zigzag => ZigZagIndicator(),
          MainIndicatorType.avl => AVLIndicator(),
        },
      )
      .toList();

  List<SecondaryIndicator> get secondaryIndicators => _secondaryOrder
      .where(secondaryTypes.contains)
      .map<SecondaryIndicator>(
        (t) => switch (t) {
          SecondaryIndicatorType.macd => MACDIndicator(),
          SecondaryIndicatorType.kdj => KDJIndicator(),
          SecondaryIndicatorType.rsi => RSIIndicator(),
          SecondaryIndicatorType.wr => WRIndicator(),
          SecondaryIndicatorType.cci => CCIIndicator(),
          SecondaryIndicatorType.obv => OBVIndicator(),
          SecondaryIndicatorType.trix => TRIXIndicator(),
          SecondaryIndicatorType.mtm => MTMIndicator(),
          SecondaryIndicatorType.stochRsi => StochRSIIndicator(),
        },
      )
      .toList();

  KChartColors get colors => isDark
      ? const KChartColors(
          bgColor: Color(0xFF1C1C1E),
          defaultTextColor: Color(0xFF8E8E93),
          gridColor: Color.fromARGB(255, 187, 187, 187),
          selectFillColor: Color(0xFF2C2C2E),
          selectBorderColor: Color(0xFF636366),
          crossColor: Color(0xFFEBEBF5),
          crossTextColor: Color(0xFFEBEBF5),
          maxColor: Color(0xFFEBEBF5),
          minColor: Color(0xFFEBEBF5),
        )
      : const KChartColors(gridColor: Color.fromARGB(255, 237, 237, 237));

  @override
  List<Object?> get props => [
    data,
    timeframe,
    mainTypes,
    secondaryTypes,
    savedChartScale,
    isLine,
    volHidden,
    isDark,
    showDepth,
    depthBottomLabelCount,
    isFetching,
    hasMoreHistory,
    isLive,
    livePrice,
    // OrderBookSnapshot không override == — mỗi lần merge tạo instance mới
    // nên identity-inequality đủ để trigger rebuild.
    orderBook,
    error,
  ];
}
