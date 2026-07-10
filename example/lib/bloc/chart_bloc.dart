import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:k_chart_wikex/k_chart_plus.dart';

import '../market/market_env.dart';
import '../market/market_history_api.dart';
import '../market/market_kline.dart';
import '../market/market_stomp_transport.dart';
import '../market/order_book.dart';
import '../market/realtime_frame.dart';
import 'chart_event.dart';
import 'chart_state.dart';

// ── Event nội bộ — chỉ ChartBloc tự dispatch từ listener WS/timer bên trong.
// Private theo file (Dart library-level) nên View không thấy và không gọi được.

/// Buffer coalesce 250ms đã đến hạn — merge các bar chờ vào series.
class _ChartRealtimeFlushed extends ChartEvent {
  const _ChartRealtimeFlushed();
}

/// Giá tick mới nhất từ thumb/kline (event tới sau thắng).
class _ChartLivePriceChanged extends ChartEvent {
  const _ChartLivePriceChanged(this.price);
  final double price;

  @override
  List<Object?> get props => [price];
}

/// Snapshot sổ lệnh mới sau khi merge BUY/SELL trade-plate (đã coalesce).
class _ChartOrderBookUpdated extends ChartEvent {
  const _ChartOrderBookUpdated(this.snapshot);
  final OrderBookSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot.version];
}

class ChartBloc extends Bloc<ChartEvent, ChartState> {
  ChartBloc({MarketStompTransport? transport})
    : _transport =
          transport ?? MarketStompTransport(stompUrl: MarketEnv.stompUrl),
      super(_initialState()) {
    on<ChartStarted>(_onStarted);
    on<ChartTimeframeChanged>(_onTimeframeChanged);
    on<ChartMainIndicatorToggled>(_onMainIndicatorToggled);
    on<ChartSecondaryIndicatorToggled>(_onSecondaryIndicatorToggled);
    on<ChartLineModeChanged>(_onLineModeChanged);
    on<ChartVolumeVisibilityToggled>(_onVolumeVisibilityToggled);
    on<ChartThemeToggled>(_onThemeToggled);
    on<ChartDepthVisibilityChanged>(_onDepthVisibilityChanged);
    on<ChartDepthBottomLabelCountChanged>(_onDepthBottomLabelCountChanged);
    on<ChartScaleSaved>(_onScaleSaved);
    on<ChartMoreDataRequested>(_onMoreDataRequested);
    on<ChartLiveToggled>(_onLiveToggled);
    on<_ChartRealtimeFlushed>(_onRealtimeFlushed);
    on<_ChartLivePriceChanged>(_onLivePriceChanged);
    on<_ChartOrderBookUpdated>(_onOrderBookUpdated);

    add(const ChartStarted());
  }

  final MarketStompTransport _transport;

  StreamSubscription<RealtimeFrame>? _klineSub;
  StreamSubscription<RealtimeFrame>? _klineLiveSub;
  StreamSubscription<RealtimeFrame>? _thumbSub;
  StreamSubscription<RealtimeFrame>? _tradePlateSub;

  // Coalesce WS: buffer bar đến trong cửa sổ ngắn rồi flush 1 lần —
  // không rebuild chart theo từng message.
  static const Duration _coalesceWindow = Duration(milliseconds: 250);
  final List<MarketKline> _pending = [];
  Timer? _throttle;

  // Order book: merge service giữ snapshot 2 phía; coalesce riêng vì
  // trade-plate bắn dày hơn kline.
  final OrderBookMergeService _orderBookMerge = OrderBookMergeService();
  Timer? _orderBookThrottle;
  static const Duration _orderBookCoalesce = Duration(milliseconds: 200);

  static String get _topicPath => MarketEnv.symbol; // đã đúng dạng BASE/QUOTE

  static ChartState _initialState() {
    return const ChartState(
      data: [],
      timeframe: ChartTimeframe.h1,
      mainTypes: {MainIndicatorType.ma},
      secondaryTypes: {SecondaryIndicatorType.macd},
      savedChartScale: KChartScaleState(),
      isLine: false,
      volHidden: false,
      isDark: false,
      showDepth: false,
      depthBottomLabelCount: 3,
      isFetching: true,
      hasMoreHistory: true,
      isLive: true,
    );
  }

  static void _recalculateState(ChartState state) {
    DataUtil.calculateAll(
      state.data,
      state.mainIndicators,
      state.secondaryIndicators,
    );
  }

  // ── Bootstrap + timeframe ─────────────────────────────────────────────────

  Future<void> _onStarted(ChartStarted event, Emitter<ChartState> emit) async {
    await _loadHistory(state.timeframe, emit);
    if (state.isLive && state.error == null) {
      _subscribeRealtime();
    }
  }

  Future<void> _onTimeframeChanged(
    ChartTimeframeChanged event,
    Emitter<ChartState> emit,
  ) async {
    if (state.timeframe == event.timeframe) return;
    // Đổi khung → clear buffer WS của khung cũ rồi refetch REST.
    // Subscription giữ nguyên (cùng symbol) — chỉ filter `period` đổi.
    _pending.clear();
    emit(state.copyWith(timeframe: event.timeframe));
    await _loadHistory(event.timeframe, emit);
  }

  Future<void> _loadHistory(
    ChartTimeframe timeframe,
    Emitter<ChartState> emit,
  ) async {
    if (!MarketEnv.isConfigured) {
      emit(state.copyWith(
        isFetching: false,
        error: 'missing_env: chạy với --dart-define-from-file=env.dev.json',
      ));
      return;
    }
    emit(state.copyWith(isFetching: true, error: null));
    try {
      final toMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final fromMs = toMs -
          ChartState.initialBatchSize * timeframe.interval.inMilliseconds;
      final bars = await fetchMarketHistory(
        apiBaseUrl: MarketEnv.apiBaseUrl,
        historyPath: MarketEnv.historyPath,
        symbol: MarketEnv.symbol,
        resolution: timeframe.restResolution,
        period: timeframe.wsPeriod,
        fromMs: fromMs,
        toMs: toMs,
      );
      if (isClosed || state.timeframe != timeframe) return; // đã đổi khung khác
      final next = state.copyWith(
        data: [for (final b in bars) b.toEntity()],
        isFetching: false,
        hasMoreHistory: bars.isNotEmpty,
        error: null,
      );
      _recalculateState(next);
      emit(next);
    } catch (e) {
      if (isClosed || state.timeframe != timeframe) return;
      emit(state.copyWith(isFetching: false, error: e.toString()));
    }
  }

  // ── Load more (kéo trái) ──────────────────────────────────────────────────

  Future<void> _onMoreDataRequested(
    ChartMoreDataRequested event,
    Emitter<ChartState> emit,
  ) async {
    if (!event.isLeft) return; // chỉ xử lý load data cũ hơn
    if (state.isFetching) return; // đang fetch rồi, bỏ qua
    if (!state.hasMoreHistory) return; // server đã hết nến cũ
    if (state.data.isEmpty) return;

    final timeframe = state.timeframe;
    final oldestMs = state.data.first.time!;
    emit(state.copyWith(isFetching: true));
    try {
      final bars = await fetchMarketHistory(
        apiBaseUrl: MarketEnv.apiBaseUrl,
        historyPath: MarketEnv.historyPath,
        symbol: MarketEnv.symbol,
        resolution: timeframe.restResolution,
        period: timeframe.wsPeriod,
        fromMs: oldestMs -
            ChartState.loadMoreBatchSize * timeframe.interval.inMilliseconds,
        toMs: oldestMs - 1, // tránh trùng bar cũ nhất đang có
      );
      if (isClosed) return;
      if (state.timeframe != timeframe) return; // user đã đổi khung trong lúc chờ
      // state.data đọc lại SAU await — không mất các bar WS merge vào trong
      // lúc chờ. Dedupe theo time phòng server trả lấn biên.
      final older = [
        for (final b in bars)
          if (b.barCloseTime.millisecondsSinceEpoch < state.data.first.time!)
            b.toEntity(),
      ];
      final next = state.copyWith(
        data: [...older, ...state.data],
        isFetching: false,
        hasMoreHistory: bars.isNotEmpty,
      );
      _recalculateState(next);
      emit(next);
    } catch (_) {
      if (isClosed) return;
      // Load-more lỗi không phá chart đang hiển thị — chỉ gỡ cờ fetching
      // để lần kéo sau retry.
      emit(state.copyWith(isFetching: false));
    }
  }

  // ── Realtime WS ───────────────────────────────────────────────────────────

  void _subscribeRealtime() {
    if (_klineSub != null) return; // đã subscribe rồi
    _klineSub = _transport
        .subscribe(
          RealtimeSubscription(
            destination: '${MarketEnv.topicKline}/$_topicPath',
            stalePolicy: RealtimeStalePolicy.klineBar,
          ),
        )
        .listen(_onKlineFrame);
    _klineLiveSub = _transport
        .subscribe(
          RealtimeSubscription(
            destination: '${MarketEnv.topicKlineLive}/$_topicPath',
            stalePolicy: RealtimeStalePolicy.klineBar,
          ),
        )
        .listen(_onKlineFrame);
    _thumbSub = _transport
        .subscribe(
          const RealtimeSubscription(
            destination: MarketEnv.topicThumb,
            stalePolicy: RealtimeStalePolicy.fastStream,
          ),
        )
        .listen(_onThumbFrame);
    // Reset trước khi subscribe lại — tránh lẫn snapshot của phiên trước.
    _orderBookMerge.reset();
    _tradePlateSub = _transport
        .subscribe(
          RealtimeSubscription(
            destination: '${MarketEnv.topicTradePlate}/$_topicPath',
            stalePolicy: RealtimeStalePolicy.fastStream,
          ),
        )
        .listen(_onTradePlateFrame);
  }

  Future<void> _unsubscribeRealtime() async {
    _throttle?.cancel();
    _throttle = null;
    _pending.clear();
    _orderBookThrottle?.cancel();
    _orderBookThrottle = null;
    await _klineSub?.cancel();
    await _klineLiveSub?.cancel();
    await _thumbSub?.cancel();
    await _tradePlateSub?.cancel();
    _klineSub = null;
    _klineLiveSub = null;
    _thumbSub = null;
    _tradePlateSub = null;
  }

  void _onKlineFrame(RealtimeFrame frame) {
    if (isClosed) return;
    final kline = tryParseKlineFrame(frame, symbol: MarketEnv.symbol);
    if (kline == null) {
      return; // chỉ bỏ đúng frame lỗi — KHÔNG đụng vào _pending
    }
    // Live price từ kline mọi period (giá mới nhất của symbol).
    add(_ChartLivePriceChanged(kline.close.toDouble()));
    if (kline.period != state.timeframe.wsPeriod) {
      return; // khác khung timeframe đang chọn
    }
    _pending.add(kline);
    _throttle ??= Timer(
      _coalesceWindow,
      () => add(const _ChartRealtimeFlushed()),
    );
  }

  void _onThumbFrame(RealtimeFrame frame) {
    if (isClosed) return;
    final thumb = tryParseThumbFrame(frame);
    // Stream global — tự lọc đúng cặp đang xem.
    if (thumb == null || thumb.symbol != MarketEnv.symbol) return;
    add(_ChartLivePriceChanged(thumb.close));
  }

  void _onTradePlateFrame(RealtimeFrame frame) {
    if (isClosed) return;
    final side = tryParseOrderBookSideFrame(
      frame,
      expectedSymbol: MarketEnv.symbol,
    );
    if (side == null) return; // chỉ bỏ đúng frame lỗi, snapshot giữ nguyên
    _orderBookMerge.apply(side);
    // Coalesce: emit snapshot mới nhất mỗi cửa sổ, không emit từng message.
    _orderBookThrottle ??= Timer(_orderBookCoalesce, () {
      _orderBookThrottle = null;
      if (!isClosed) add(_ChartOrderBookUpdated(_orderBookMerge.current));
    });
  }

  void _onOrderBookUpdated(
    _ChartOrderBookUpdated event,
    Emitter<ChartState> emit,
  ) {
    emit(state.copyWith(orderBook: event.snapshot));
  }

  void _onRealtimeFlushed(
    _ChartRealtimeFlushed event,
    Emitter<ChartState> emit,
  ) {
    _throttle = null;
    if (_pending.isEmpty) return;
    var data = state.data;
    for (final k in _pending) {
      // Re-check period: timeframe có thể đã đổi khi bar còn nằm buffer.
      if (k.period != state.timeframe.wsPeriod) continue;
      data = _mergeBar(data, k);
    }
    _pending.clear();
    if (identical(data, state.data)) return;
    final next = state.copyWith(data: data);
    _recalculateState(next);
    emit(next);
  }

  /// Merge 1 bar WS vào series theo barCloseTime tăng dần: trùng time →
  /// replace (update nến đang chạy), mới hơn → append, còn lại → insert
  /// đúng vị trí. Luôn trả list MỚI — không sửa in-place để KChartWidget
  /// thấy reference đổi mà repaint.
  static List<KLineEntity> _mergeBar(
    List<KLineEntity> series,
    MarketKline bar,
  ) {
    final entity = bar.toEntity();
    final t = entity.time!;
    if (series.isEmpty) return [entity];
    if (t > series.last.time!) return [...series, entity];
    for (var i = series.length - 1; i >= 0; i--) {
      final ti = series[i].time!;
      if (ti == t) return [...series]..[i] = entity;
      if (ti < t) return [...series]..insert(i + 1, entity);
    }
    return [entity, ...series];
  }

  void _onLivePriceChanged(
    _ChartLivePriceChanged event,
    Emitter<ChartState> emit,
  ) {
    if (state.livePrice == event.price) return;
    emit(state.copyWith(livePrice: event.price));
  }

  Future<void> _onLiveToggled(
    ChartLiveToggled event,
    Emitter<ChartState> emit,
  ) async {
    if (state.isLive) {
      emit(state.copyWith(isLive: false));
      await _unsubscribeRealtime();
    } else {
      emit(state.copyWith(isLive: true));
      _subscribeRealtime();
    }
  }

  // ── UI toggles ────────────────────────────────────────────────────────────

  void _onMainIndicatorToggled(
    ChartMainIndicatorToggled event,
    Emitter<ChartState> emit,
  ) {
    final types = Set<MainIndicatorType>.of(state.mainTypes);
    if (!types.remove(event.type)) types.add(event.type);
    final next = state.copyWith(mainTypes: types);
    _recalculateState(next);
    emit(next);
  }

  void _onSecondaryIndicatorToggled(
    ChartSecondaryIndicatorToggled event,
    Emitter<ChartState> emit,
  ) {
    final types = Set<SecondaryIndicatorType>.of(state.secondaryTypes);
    if (!types.remove(event.type)) types.add(event.type);
    final next = state.copyWith(secondaryTypes: types);
    _recalculateState(next);
    emit(next);
  }

  void _onLineModeChanged(
    ChartLineModeChanged event,
    Emitter<ChartState> emit,
  ) {
    emit(state.copyWith(isLine: event.isLine));
  }

  void _onVolumeVisibilityToggled(
    ChartVolumeVisibilityToggled event,
    Emitter<ChartState> emit,
  ) {
    emit(state.copyWith(volHidden: !state.volHidden));
  }

  void _onThemeToggled(ChartThemeToggled event, Emitter<ChartState> emit) {
    emit(state.copyWith(isDark: !state.isDark));
  }

  void _onDepthVisibilityChanged(
    ChartDepthVisibilityChanged event,
    Emitter<ChartState> emit,
  ) {
    emit(state.copyWith(showDepth: event.show));
  }

  void _onDepthBottomLabelCountChanged(
    ChartDepthBottomLabelCountChanged event,
    Emitter<ChartState> emit,
  ) {
    emit(state.copyWith(depthBottomLabelCount: event.count));
  }

  void _onScaleSaved(ChartScaleSaved event, Emitter<ChartState> emit) {
    emit(state.copyWith(savedChartScale: event.scale));
  }

  @override
  Future<void> close() async {
    await _unsubscribeRealtime();
    await _transport.shutdown();
    return super.close();
  }
}
