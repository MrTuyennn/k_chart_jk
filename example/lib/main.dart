import 'dart:math';
import 'package:flutter/material.dart';
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

List<KLineEntity> _generateMockData(int count) {
  final random = Random(42);
  double price = 65000;
  final now = DateTime.now();
  final list = <KLineEntity>[];

  for (int i = count - 1; i >= 0; i--) {
    final time = now.subtract(Duration(hours: i));
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

// ── Demo page ─────────────────────────────────────────────────────────────────

enum _MainType { ma, boll, ema, none }

enum _SecondaryType { macd, kdj, rsi, wr, cci, none }

class ChartDemoPage extends StatefulWidget {
  const ChartDemoPage({super.key});

  @override
  State<ChartDemoPage> createState() => _ChartDemoPageState();
}

class _ChartDemoPageState extends State<ChartDemoPage> {
  late List<KLineEntity> _data;
  final KChartController _controller = KChartController();

  _MainType _mainType = _MainType.ma;
  _SecondaryType _secondaryType = _SecondaryType.macd;
  bool _isLine = false;
  bool _volHidden = false;
  bool _isDark = false;

  bool _isFetching = false;        // đang fetch → hiện banner
  int _totalLoaded = 200;
  static const int _maxTotal = 500;
  static const int _batchSize = 50;

  @override
  void initState() {
    super.initState();
    _data = _generateMockData(200);
    _recalculate();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _recalculate() {
    DataUtil.calculateAll(_data, _mainIndicators, _secondaryIndicators);
  }

  void _onLoadMore(bool isLeft) async {
    if (!isLeft) return;                  // chỉ xử lý load data cũ hơn
    if (_isFetching) return;              // đang fetch rồi, bỏ qua
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
      final time = (oldest.time ?? 0) - i * 3600 * 1000;
      final change = (random.nextDouble() - 0.48) * 800;
      final open = price;
      final close = (price - change).clamp(10000.0, 200000.0);
      final high = max(open, close) + random.nextDouble() * 300;
      final low = min(open, close) - random.nextDouble() * 300;
      final vol = 10 + random.nextDouble() * 500;
      list.add(KLineEntity.fromCustom(
        time: time, open: open, close: close,
        high: high, low: low, vol: vol, amount: close * vol,
      ));
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

  void _setSecondary(_SecondaryType type) {
    setState(() {
      _secondaryType = type;
      _recalculate();
    });
  }

  List<MainIndicator> get _mainIndicators => switch (_mainType) {
    _MainType.ma => [MAIndicator()],
    _MainType.boll => [BOLLIndicator()],
    _MainType.ema => [EMAIndicator()],
    _MainType.none => [],
  };

  List<SecondaryIndicator> get _secondaryIndicators => switch (_secondaryType) {
    _SecondaryType.macd => [MACDIndicator()],
    _SecondaryType.kdj => [KDJIndicator()],
    _SecondaryType.rsi => [RSIIndicator()],
    _SecondaryType.wr => [WRIndicator()],
    _SecondaryType.cci => [CCIIndicator()],
    _SecondaryType.none => [],
  };

  KChartColors get _colors => _isDark
      ? const KChartColors(
          bgColor: Color(0xFF1C1C1E),
          defaultTextColor: Color(0xFF8E8E93),
          gridColor: Color(0xFF2C2C2E),
          selectFillColor: Color(0xFF2C2C2E),
          selectBorderColor: Color(0xFF636366),
          crossColor: Color(0xFFEBEBF5),
          crossTextColor: Color(0xFFEBEBF5),
          maxColor: Color(0xFFEBEBF5),
          minColor: Color(0xFFEBEBF5),
        )
      : const KChartColors();

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
          IconButton(
            icon: Icon(
              _isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: _isDark ? Colors.white70 : Colors.black54,
            ),
            onPressed: () => setState(() => _isDark = !_isDark),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildChart(),
          const SizedBox(height: 4),
          Expanded(child: _buildControls()),
        ],
      ),
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
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'Đang tải thêm $_batchSize nến...',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ),
        // Số nến + trạng thái
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Text(
            '${_data.length} nến'
            '${_totalLoaded >= _maxTotal ? ' · Đã tải hết' : ' · Kéo trái để tải thêm'}',
            style: TextStyle(
              fontSize: 11,
              color: _isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),
        KChartWidget(
          _data,
          const KChartStyle(),
          _colors,
          isTrendLine: false,
          isLine: _isLine,
          volHidden: _volHidden,
          mainIndicators: _mainIndicators,
          secondaryIndicators: _secondaryIndicators,
          controller: _controller,
          showNowPrice: true,
          showInfoDialog: true,
          mBaseHeight: 280,
          timeFormat: TimeFormat.yearMonthDayWithHour,
          onLoadMore: _onLoadMore,
          isLoadingMore: _isFetching,
          detailBuilder: _buildInfoCard,
        ),
      ],
    );
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
    return SingleChildScrollView(
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
                _secondaryType == _SecondaryType.macd,
                () => _setSecondary(_SecondaryType.macd),
              ),
              _chip(
                'KDJ',
                _secondaryType == _SecondaryType.kdj,
                () => _setSecondary(_SecondaryType.kdj),
              ),
              _chip(
                'RSI',
                _secondaryType == _SecondaryType.rsi,
                () => _setSecondary(_SecondaryType.rsi),
              ),
              _chip(
                'WR',
                _secondaryType == _SecondaryType.wr,
                () => _setSecondary(_SecondaryType.wr),
              ),
              _chip(
                'CCI',
                _secondaryType == _SecondaryType.cci,
                () => _setSecondary(_SecondaryType.cci),
              ),
              _chip(
                'None',
                _secondaryType == _SecondaryType.none,
                () => _setSecondary(_SecondaryType.none),
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
