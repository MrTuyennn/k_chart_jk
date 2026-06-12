import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:k_chart_wikex/k_chart_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'K Chart Wikex Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF217AFF)),
        useMaterial3: true,
      ),
      home: const ChartDemoPage(),
    );
  }
}

// ── Mock data ─────────────────────────────────────────────────────────────────

List<KLineEntity> _generateMockData(int count, Duration candleInterval) {
  final random = Random(42);
  double price = 65000;
  final now = DateTime.now();
  final list = <KLineEntity>[];

  for (int i = count - 1; i >= 0; i--) {
    final time = now.subtract(candleInterval * i);
    final change = (random.nextDouble() - 0.48) * 800;
    final open = price;
    final close = (price + change).clamp(10000.0, 200000.0);
    final high = max(open, close) + random.nextDouble() * 300;
    final low = min(open, close) - random.nextDouble() * 300;
    final vol = 10 + random.nextDouble() * 500;

    list.add(
      KLineEntity.fromCustom(
        time: time.millisecondsSinceEpoch,
        open: open,
        close: close,
        high: high,
        low: low,
        vol: vol,
        amount: close * vol,
      ),
    );
    price = close;
  }
  return list;
}

// ── Mock orderbook ────────────────────────────────────────────────────────────

({List<DepthEntity> bids, List<DepthEntity> asks}) _generateMockDepth(
  double midPrice, {
  int levels = 40,
  double stepRatio = 0.0005,
}) {
  final random = Random(7);
  final bids = <DepthEntity>[];
  final asks = <DepthEntity>[];
  double bidCum = 0;
  double askCum = 0;

  for (int i = 1; i <= levels; i++) {
    final bidPrice = midPrice * (1 - stepRatio * i);
    final askPrice = midPrice * (1 + stepRatio * i);
    final bidVol = 0.5 + random.nextDouble() * 4;
    final askVol = 0.5 + random.nextDouble() * 4;
    bidCum += bidVol;
    askCum += askVol;
    bids.add(DepthEntity(bidPrice, bidCum));
    asks.add(DepthEntity(askPrice, askCum));
  }
  return (bids: bids, asks: asks);
}

// ── Demo page ─────────────────────────────────────────────────────────────────

enum _MainType { ma, boll, ema, none }

enum _SecondaryType { macd, kdj, rsi, wr, cci, obv, none }

enum _ChartTimeframe {
  m15('15m', Duration(minutes: 15)),
  h1('1H', Duration(hours: 1)),
  h4('4H', Duration(hours: 4)),
  d1('1D', Duration(days: 1));

  const _ChartTimeframe(this.label, this.interval);
  final String label;
  final Duration interval;
}

class _OrderBookItem {
  final DepthEntity? entity;
  final Color? sideColor;
  final bool isSpread;

  _OrderBookItem.row(this.entity, this.sideColor) : isSpread = false;
  _OrderBookItem.spread() : entity = null, sideColor = null, isSpread = true;
}

class ChartDemoPage extends StatefulWidget {
  const ChartDemoPage({super.key});

  @override
  State<ChartDemoPage> createState() => _ChartDemoPageState();
}

class _ChartDemoPageState extends State<ChartDemoPage> {
  late List<KLineEntity> _data;
  final KChartController _controller = KChartController();
  final ScrollController _outerScrollController = ScrollController();

  _MainType _mainType = _MainType.ma;
  _ChartTimeframe _timeframe = _ChartTimeframe.h1;
  KChartScaleState _savedChartScale = const KChartScaleState();
  Set<_SecondaryType> _secondaryTypes = {_SecondaryType.macd};
  bool _isLine = false;
  bool _volHidden = false;
  bool _isDark = false;
  bool _showDepth = false;
  int _depthBottomLabelCount = 3;

  bool _isFetching = false;
  int _totalLoaded = 200;
  static const int _maxTotal = 500;
  static const int _batchSize = 50;

  // Gesture priority cho chart vs outer scroll
  // true sau khi user drag dọc vùng phải chart (scaleY) — kích hoạt chart focused mode
  // → outer scroll bị khoá khi finger chạm chart, chart độc quyền xử lý gesture
  // false khi user double-tap vùng phải để reset scaleY
  bool _scaleYActive = false;
  // true khi finger đang chạm vùng chart
  bool _pointerOnChart = false;
  Offset? _chartPointerDownPos;
  int _chartPointerCount = 0;
  double _chartWidth = 0;
  DateTime? _lastTapTime;
  Offset? _lastTapPos;
  static const double _scaleYZoneWidth = 100.0;
  static const double _scaleYDragThreshold = 8.0;
  static const Duration _doubleTapMaxGap = Duration(milliseconds: 300);
  static const double _doubleTapMaxDistance = 20.0;

  // Real-time simulation
  Timer? _liveTimer;
  bool _isLive = false;
  int _tickCount = 0;
  // Mỗi tick: cập nhật nến cuối. Mỗi _ticksPerCandle tick: đóng nến + mở nến mới.
  static const int _ticksPerCandle = 10;
  static const Duration _tickInterval = Duration(milliseconds: 500);
  final Random _liveRandom = Random();

  @override
  void initState() {
    super.initState();
    _data = _generateMockData(200, _timeframe.interval);
    _recalculate();
  }

  void _setTimeframe(_ChartTimeframe tf) {
    if (_timeframe == tf) return;
    setState(() {
      _timeframe = tf;
      _data = _generateMockData(200, tf.interval);
      _totalLoaded = 200;
      _recalculate();
    });
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _controller.dispose();
    _outerScrollController.dispose();
    super.dispose();
  }

  // ── Real-time simulation ───────────────────────────────────────────────────

  void _toggleLive() {
    if (_isLive) {
      _liveTimer?.cancel();
      setState(() => _isLive = false);
    } else {
      _tickCount = 0;
      _liveTimer = Timer.periodic(_tickInterval, (_) => _onLiveTick());
      setState(() => _isLive = true);
    }
  }

  void _onLiveTick() {
    if (!mounted) return;
    _tickCount++;

    final last = _data.last;
    // Biến động giá nhỏ mỗi tick (~0.3% của giá hiện tại)
    final change = (last.close * 0.003) * (_liveRandom.nextDouble() - 0.48);
    final newClose = (last.close + change).clamp(1.0, double.infinity);

    if (_tickCount % _ticksPerCandle == 0) {
      // Đóng nến hiện tại, mở nến mới
      _addNewCandle(newClose);
    } else {
      // Cập nhật nến cuối (tick trong cùng 1 nến)
      _updateLastCandle(newClose);
    }
  }

  void _updateLastCandle(double newClose) {
    final last = _data.last;
    // Tạo entity mới thay thế nến cuối với giá close mới
    final updated = KLineEntity.fromCustom(
      time: last.time!,
      open: last.open,
      close: newClose,
      high: max(last.high, newClose),
      low: min(last.low, newClose),
      vol: last.vol + _liveRandom.nextDouble() * 5,
      amount: last.amount ?? 0,
    );
    final newData = [..._data.sublist(0, _data.length - 1), updated];
    DataUtil.calculateAll(newData, _mainIndicators, _secondaryIndicators);
    setState(() => _data = newData);
  }

  void _addNewCandle(double prevClose) {
    // Mở nến mới với open = close của nến trước
    final last = _data.last;
    final newCandle = KLineEntity.fromCustom(
      time: last.time! + _timeframe.interval.inMilliseconds,
      open: prevClose,
      close: prevClose,
      high: prevClose,
      low: prevClose,
      vol: _liveRandom.nextDouble() * 50 + 10,
      amount: 0,
    );
    final newData = [..._data, newCandle];
    DataUtil.calculateAll(newData, _mainIndicators, _secondaryIndicators);
    setState(() {
      _data = newData;
      _totalLoaded++;
    });
    // KHÔNG gọi _controller.reset() — sẽ phá mScrollX/mScaleX/mSelectX
    // của user đang xem lịch sử. Khi mScrollX = 0 (đang ở rightmost),
    // chart tự động vẫn fit nến mới vào view; khi đang scroll history
    // thì giữ nguyên vị trí, user không bị giật.
  }

  void _recalculate() {
    DataUtil.calculateAll(_data, _mainIndicators, _secondaryIndicators);
  }

  // ── Chart pointer tracking ─────────────────────────────────────────────────

  bool _inScaleYZone(Offset pos) =>
      _chartWidth > 0 && pos.dx > _chartWidth - _scaleYZoneWidth;

  void _onChartPointerDown(PointerDownEvent e) {
    _chartPointerCount++;
    _chartPointerDownPos = e.localPosition;
    if (!_pointerOnChart) {
      setState(() => _pointerOnChart = true);
    }
    // Double-tap trong scaleY zone → khớp với hành vi reset scaleY của chart
    // → tắt scaleY active mode để outer scroll hoạt động lại
    if (_scaleYActive &&
        _inScaleYZone(e.localPosition) &&
        _lastTapTime != null &&
        _lastTapPos != null &&
        DateTime.now().difference(_lastTapTime!) < _doubleTapMaxGap &&
        (e.localPosition - _lastTapPos!).distance < _doubleTapMaxDistance) {
      setState(() => _scaleYActive = false);
      _lastTapTime = null;
      _lastTapPos = null;
    }
  }

  void _onChartPointerMove(PointerMoveEvent e) {
    if (_scaleYActive || _chartPointerDownPos == null) return;
    // Chỉ active khi: drag bắt đầu trong scaleY zone + vertical-dominant + > threshold
    if (!_inScaleYZone(_chartPointerDownPos!)) return;
    final delta = e.localPosition - _chartPointerDownPos!;
    if (delta.dy.abs() > _scaleYDragThreshold &&
        delta.dy.abs() > delta.dx.abs()) {
      setState(() => _scaleYActive = true);
    }
  }

  void _onChartPointerUp(PointerUpEvent e) {
    // Ghi nhận tap để detect double-tap ở lần down kế tiếp
    if (_chartPointerDownPos != null) {
      final dist = (e.localPosition - _chartPointerDownPos!).distance;
      if (dist < _doubleTapMaxDistance) {
        _lastTapTime = DateTime.now();
        _lastTapPos = e.localPosition;
      } else {
        _lastTapTime = null;
        _lastTapPos = null;
      }
    }
    _releaseChartPointer();
  }

  void _onChartPointerCancel(PointerCancelEvent e) {
    _lastTapTime = null;
    _lastTapPos = null;
    _releaseChartPointer();
  }

  void _releaseChartPointer() {
    _chartPointerCount = (_chartPointerCount - 1).clamp(0, 10);
    if (_chartPointerCount == 0) {
      _chartPointerDownPos = null;
      if (_pointerOnChart) {
        setState(() => _pointerOnChart = false);
      }
    }
  }

  void _onLoadMore(bool isLeft) async {
    if (!isLeft) return; // chỉ xử lý load data cũ hơn
    if (_isFetching) return; // đang fetch rồi, bỏ qua
    if (_totalLoaded >= _maxTotal) return; // đã hết data

    setState(() => _isFetching = true);

    // Giả lập network delay
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    final oldest = _data.first;
    final olderData = _generateOlderData(_batchSize, oldest);
    final merged = [...olderData, ..._data];
    DataUtil.calculateAll(merged, _mainIndicators, _secondaryIndicators);

    setState(() {
      _data = merged;
      _totalLoaded += _batchSize;
      _isFetching = false;
    });
  }

  List<KLineEntity> _generateOlderData(int count, KLineEntity oldest) {
    final random = Random(oldest.time ?? 0);
    double price = oldest.open;
    final list = <KLineEntity>[];
    for (int i = count; i >= 1; i--) {
      final time = (oldest.time ?? 0) - i * _timeframe.interval.inMilliseconds;
      final change = (random.nextDouble() - 0.48) * 800;
      final open = price;
      final close = (price - change).clamp(10000.0, 200000.0);
      final high = max(open, close) + random.nextDouble() * 300;
      final low = min(open, close) - random.nextDouble() * 300;
      final vol = 10 + random.nextDouble() * 500;
      list.add(
        KLineEntity.fromCustom(
          time: time,
          open: open,
          close: close,
          high: high,
          low: low,
          vol: vol,
          amount: close * vol,
        ),
      );
      price = close;
    }
    return list;
  }

  void _setMain(_MainType type) {
    setState(() {
      _mainType = type;
      _recalculate();
    });
  }

  void _toggleSecondary(_SecondaryType type) {
    setState(() {
      if (_secondaryTypes.contains(type)) {
        _secondaryTypes.remove(type);
      } else {
        _secondaryTypes.add(type);
      }
      _recalculate();
    });
  }

  List<MainIndicator> get _mainIndicators => switch (_mainType) {
    _MainType.ma => [MAIndicator()],
    _MainType.boll => [BOLLIndicator()],
    _MainType.ema => [EMAIndicator()],
    _MainType.none => [],
  };

  List<SecondaryIndicator> get _secondaryIndicators {
    const order = [
      _SecondaryType.macd,
      _SecondaryType.kdj,
      _SecondaryType.rsi,
      _SecondaryType.wr,
      _SecondaryType.cci,
      _SecondaryType.obv,
    ];
    return order
        .where((t) => _secondaryTypes.contains(t))
        .map<SecondaryIndicator>(
          (t) => switch (t) {
            _SecondaryType.macd => MACDIndicator(),
            _SecondaryType.kdj => KDJIndicator(),
            _SecondaryType.rsi => RSIIndicator(),
            _SecondaryType.wr => WRIndicator(),
            _SecondaryType.cci => CCIIndicator(),
            _SecondaryType.obv => OBVIndicator(),
            _ => throw StateError('unreachable'),
          },
        )
        .toList();
  }

  KChartColors get _colors => _isDark
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDark ? const Color(0xFF1C1C1E) : Colors.white,
      appBar: AppBar(
        backgroundColor: _isDark ? const Color(0xFF1C1C1E) : Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BTC/USDT',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isDark ? Colors.white : Colors.black,
              ),
            ),
            Text(
              '${_data.last.close.toStringAsFixed(2)} USDT',
              style: TextStyle(
                fontSize: 13,
                color: _data.last.close >= _data.last.open
                    ? const Color(0xFF14AD8F)
                    : const Color(0xFFD5405D),
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Text(
                'Depth',
                style: TextStyle(
                  fontSize: 12,
                  color: _isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Switch(
                value: _showDepth,
                onChanged: (v) => setState(() => _showDepth = v),
              ),
            ],
          ),
          IconButton(
            icon: Icon(
              _isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: _isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => setState(() => _isDark = !_isDark),
          ),
        ],
      ),
      body: SingleChildScrollView(
        controller: _outerScrollController,
        physics: (_scaleYActive && _pointerOnChart)
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _showDepth ? _buildDepthChartSection() : _buildChart(),
            const SizedBox(height: 8),
            _sectionHeader('Order Book'),
            _buildOrderBook(),
            const SizedBox(height: 8),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildOrderBook() {
    final midPrice = _data.last.close;
    final depth = _generateMockDepth(midPrice, levels: 30);
    // Asks hiển thị từ giá cao → giá thấp (gần spread nhất ở dưới)
    final asks = depth.asks.reversed.toList();
    final bids = depth.bids;

    final maxVol = [
      ...asks.map((e) => e.vol),
      ...bids.map((e) => e.vol),
    ].fold<double>(0, max);

    final upColor = const Color(0xFF14AD8F);
    final dnColor = const Color(0xFFD5405D);
    final textColor = _isDark ? Colors.white70 : Colors.black87;
    final mutedColor = _isDark ? Colors.white38 : Colors.black38;
    final isUp = _data.last.close >= _data.last.open;

    // Gộp asks + spread + bids thành 1 list duy nhất
    final items = <_OrderBookItem>[
      ...asks.map((e) => _OrderBookItem.row(e, dnColor)),
      _OrderBookItem.spread(),
      ...bids.map((e) => _OrderBookItem.row(e, upColor)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  'Price (USDT)',
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Amount',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Total',
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 11, color: mutedColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Inline list (không tự cuộn — cuộn theo scroll cha)
          ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              if (item.isSpread) {
                return _spreadRow(midPrice, isUp, upColor, dnColor, mutedColor);
              }
              return _orderBookRow(
                item.entity!,
                maxVol,
                item.sideColor!,
                textColor,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _spreadRow(
    double midPrice,
    bool isUp,
    Color upColor,
    Color dnColor,
    Color mutedColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: mutedColor.withValues(alpha: 0.2), width: 0.5),
          bottom: BorderSide(
            color: mutedColor.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isUp ? Icons.arrow_upward : Icons.arrow_downward,
            size: 14,
            color: isUp ? upColor : dnColor,
          ),
          const SizedBox(width: 4),
          Text(
            midPrice.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isUp ? upColor : dnColor,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '≈ \$${midPrice.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 11, color: mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _orderBookRow(
    DepthEntity entity,
    double maxVol,
    Color sideColor,
    Color textColor,
  ) {
    final ratio = maxVol == 0 ? 0.0 : (entity.vol / maxVol).clamp(0.0, 1.0);
    final amount = entity.vol;
    return Stack(
      children: [
        // Bar nền theo volume (vẽ từ phải sang trái)
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: ratio,
              child: Container(color: sideColor.withValues(alpha: 0.12)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  entity.price.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 12,
                    color: sideColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  amount.toStringAsFixed(4),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  (entity.price * amount).toStringAsFixed(2),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner trạng thái load
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: _isFetching ? 28 : 0,
          color: const Color(0xFF217AFF),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Đang tải thêm $_batchSize nến...',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        // Timeframe + scale đã lưu
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(
            children: [
              for (final tf in _ChartTimeframe.values) ...[
                _chip(tf.label, _timeframe == tf, () => _setTimeframe(tf)),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            'Pinch zoom rồi đổi timeframe — scaleX giữ nguyên '
            '(${_savedChartScale.scaleX.toStringAsFixed(2)}×)',
            style: TextStyle(
              fontSize: 10,
              color: _isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
        // Số nến + trạng thái
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                '${_data.length} nến · ${_timeframe.label}'
                '${_totalLoaded >= _maxTotal ? ' · Đã tải hết' : ' · Kéo trái để tải thêm'}',
                style: TextStyle(
                  fontSize: 11,
                  color: _isDark ? Colors.white38 : Colors.black38,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _scaleYActive
                      ? const Color(0xFF217AFF).withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _scaleYActive ? 'Chart focused' : 'Scroll mode',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _scaleYActive
                        ? const Color(0xFF217AFF)
                        : (_isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (ctx, constraints) {
            _chartWidth = constraints.maxWidth;
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _onChartPointerDown,
              onPointerMove: _onChartPointerMove,
              onPointerUp: _onChartPointerUp,
              onPointerCancel: _onChartPointerCancel,
              child: _buildKChart(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildKChart() {
    return KChartWidget(
      _data,
      const KChartStyle(),
      _colors,
      key: ValueKey(_timeframe),
      isTrendLine: false,
      isLine: _isLine,
      volHidden: _volHidden,
      mainIndicators: _mainIndicators,
      secondaryIndicators: _secondaryIndicators,
      controller: _controller,
      minScale: 0.2,
      maxScale: 2.2,
      chartScale: _savedChartScale,
      onChartScaleChanged: (scale) {
        debugPrint('[scale_state] $scale');
        setState(() => _savedChartScale = scale);
      },
      showNowPrice: true,
      showInfoDialog: true,
      mBaseHeight: 280,
      timeFormat: TimeFormat.yearMonthDayWithHour,
      onLoadMore: _onLoadMore,
      isLoadingMore: _isFetching,
      detailBuilder: _buildInfoCard,
      onVerticalOverscroll: _onChartVerticalOverscroll,
      backgroundLogo: Builder(
        builder: (context) {
          final size = MediaQuery.sizeOf(context).width / 12;
          return SvgPicture.asset(
            'assets/logo_wikex.svg',
            width: size,
            height: size,
          );
        },
      ),
      backgroundLogoOpacity: 1,
    );
  }

  Widget _buildDepthChartSection() {
    final midPrice = _data.last.close;
    final depth = _generateMockDepth(midPrice, levels: 40);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bộ chọn số mốc giá ở trục dưới
          Row(
            children: [
              Text(
                'Bottom labels:',
                style: TextStyle(
                  fontSize: 11,
                  color: _isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              const SizedBox(width: 8),
              for (final n in const [3, 5, 7, 9]) ...[
                _chip(
                  '$n',
                  _depthBottomLabelCount == n,
                  () => setState(() => _depthBottomLabelCount = n),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: DepthChart(
              depth.bids,
              depth.asks,
              DepthChartColors(
                defaultTextColor: _isDark
                    ? const Color(0xFF8E8E93)
                    : const Color(0xFF909196),
              ),
              bottomLabelCount: _depthBottomLabelCount,
              backgroundLogo: Builder(
                builder: (context) {
                  final size = MediaQuery.sizeOf(context).width / 12;
                  return SvgPicture.asset(
                    'assets/logo_wikex.svg',
                    width: size,
                    height: size,
                  );
                },
              ),
              backgroundLogoOpacity: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _onChartVerticalOverscroll(double delta) {
    if (!_outerScrollController.hasClients) return;
    final pos = _outerScrollController.position;
    // Convention: chart pan Y dùng mOffsetY += dy (content theo finger).
    // Scroll Flutter ngược lại: pos.pixels TĂNG = reveal content bên dưới
    // (finger drag UP). Vì vậy phải NEGATE delta khi forward sang outer:
    //   finger drag DOWN → overscroll > 0 → outer pos giảm (reveal content trên)
    //   finger drag UP   → overscroll < 0 → outer pos tăng (reveal content dưới)
    final target = (pos.pixels - delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target != pos.pixels) {
      // jumpTo bypass physics → vẫn cuộn được khi outer đang NeverScrollableScrollPhysics
      _outerScrollController.jumpTo(target);
    }
  }

  Widget _buildInfoCard(KLineEntity entity) {
    final isUp = entity.close >= entity.open;
    final color = isUp ? const Color(0xFF14AD8F) : const Color(0xFFD5405D);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 11,
          color: _isDark ? Colors.white70 : Colors.black87,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow('Open', entity.open.toStringAsFixed(2)),
            _infoRow('High', entity.high.toStringAsFixed(2)),
            _infoRow('Low', entity.low.toStringAsFixed(2)),
            _infoRow(
              'Close',
              entity.close.toStringAsFixed(2),
              valueColor: color,
            ),
            _infoRow('Vol', entity.vol.toStringAsFixed(2)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 38,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: chart type + zoom controls
          Row(
            children: [
              _chip('Candle', !_isLine, () => setState(() => _isLine = false)),
              const SizedBox(width: 6),
              _chip('Line', _isLine, () => setState(() => _isLine = true)),
              const SizedBox(width: 6),
              _chip(
                'Volume',
                !_volHidden,
                () => setState(() => _volHidden = !_volHidden),
              ),
              const SizedBox(width: 6),
              _liveChip(),
              const Spacer(),
              _iconBtn(Icons.zoom_in, () => _controller.zoomIn(), 'Zoom In'),
              _iconBtn(Icons.zoom_out, () => _controller.zoomOut(), 'Zoom Out'),
              _iconBtn(Icons.refresh, () => _controller.reset(), 'Reset'),
            ],
          ),
          const SizedBox(height: 12),
          _sectionLabel('Main Indicator'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                'MA',
                _mainType == _MainType.ma,
                () => _setMain(_MainType.ma),
              ),
              _chip(
                'BOLL',
                _mainType == _MainType.boll,
                () => _setMain(_MainType.boll),
              ),
              _chip(
                'EMA',
                _mainType == _MainType.ema,
                () => _setMain(_MainType.ema),
              ),
              _chip(
                'None',
                _mainType == _MainType.none,
                () => _setMain(_MainType.none),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _sectionLabel('Secondary Indicator'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                'MACD',
                _secondaryTypes.contains(_SecondaryType.macd),
                () => _toggleSecondary(_SecondaryType.macd),
              ),
              _chip(
                'KDJ',
                _secondaryTypes.contains(_SecondaryType.kdj),
                () => _toggleSecondary(_SecondaryType.kdj),
              ),
              _chip(
                'RSI',
                _secondaryTypes.contains(_SecondaryType.rsi),
                () => _toggleSecondary(_SecondaryType.rsi),
              ),
              _chip(
                'WR',
                _secondaryTypes.contains(_SecondaryType.wr),
                () => _toggleSecondary(_SecondaryType.wr),
              ),
              _chip(
                'CCI',
                _secondaryTypes.contains(_SecondaryType.cci),
                () => _toggleSecondary(_SecondaryType.cci),
              ),
              _chip(
                'OBV',
                _secondaryTypes.contains(_SecondaryType.obv),
                () => _toggleSecondary(_SecondaryType.obv),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: _isDark ? Colors.white38 : Colors.black38,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF217AFF)
              : (_isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F3F5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected
                ? Colors.white
                : (_isDark ? Colors.white60 : Colors.black54),
          ),
        ),
      ),
    );
  }

  Widget _liveChip() {
    return GestureDetector(
      onTap: _toggleLive,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isLive
              ? const Color(0xFFD5405D)
              : (_isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F3F5)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isLive) ...[
              // Dot nhấp nháy khi đang live
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.3, end: 1.0),
                duration: const Duration(milliseconds: 600),
                builder: (_, v, __) => Opacity(
                  opacity: v,
                  child: const Icon(Icons.circle, size: 6, color: Colors.white),
                ),
                onEnd: () => setState(() {}),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              _isLive ? 'Live' : 'Live',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isLive
                    ? Colors.white
                    : (_isDark ? Colors.white60 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: _isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      ),
    );
  }
}
