import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:k_chart_jk/k_chart_plus.dart';
import 'package:meta/meta.dart';

import 'realtime_frame.dart';

@immutable
class MarketKline {
  const MarketKline({
    required this.symbol,
    required this.period,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.turnover,
    required this.barCloseTime,
  });

  final String symbol;
  final String period; // "1min","5min",...,"1day"
  final Decimal open;
  final Decimal high;
  final Decimal low;
  final Decimal close;
  final Decimal volume;
  final Decimal turnover;
  final DateTime barCloseTime; // UTC

  KLineEntity toEntity() => KLineEntity.fromCustom(
    time: barCloseTime.millisecondsSinceEpoch,
    open: open.toDouble(),
    high: high.toDouble(),
    low: low.toDouble(),
    close: close.toDouble(),
    vol: volume.toDouble(),
    amount: turnover.toDouble(),
  );
}

/// Parse payload WS kline / kline-live — trả null nếu frame hỏng
/// (caller chỉ bỏ qua đúng frame này, KHÔNG xoá buffer khác).
MarketKline? tryParseKlineFrame(RealtimeFrame frame, {required String symbol}) {
  try {
    final decoded = jsonDecode(frame.body);
    if (decoded is! Map) return null;
    final map = Map<String, Object?>.from(decoded);
    return MarketKline(
      symbol: symbol,
      period: _string(map, 'period'),
      open: _decimal(map, 'openPrice'),
      high: _decimal(map, 'highestPrice'),
      low: _decimal(map, 'lowestPrice'),
      close: _decimal(map, 'closePrice'),
      volume: _decimal(map, 'volume'),
      turnover: _decimal(map, 'turnover'),
      barCloseTime: DateTime.fromMillisecondsSinceEpoch(
        _int(map, 'time'),
        isUtc: true,
      ),
    );
  } on FormatException {
    return null;
  }
}

/// Parse payload WS thumb (ticker) — chỉ lấy phần cần cho live price.
/// Stream global (nhiều cặp) nên trả cả `symbol` để caller tự lọc.
({String symbol, double close})? tryParseThumbFrame(RealtimeFrame frame) {
  try {
    final decoded = jsonDecode(frame.body);
    if (decoded is! Map) return null;
    final map = Map<String, Object?>.from(decoded);
    return (
      symbol: _string(map, 'symbol'),
      close: _decimal(map, 'close').toDouble(),
    );
  } on FormatException {
    return null;
  }
}

/// Map REST history (array-of-arrays) → [MarketKline]
/// (điền `turnover = 0` — REST không có field này).
List<MarketKline> parseHistoryBars(
  Object? raw, {
  required String symbol,
  required String period,
}) {
  if (raw is! List) throw const FormatException('expected_json_array');
  final bars = <MarketKline>[
    for (final row in raw)
      if (row is List && row.length == 6)
        MarketKline(
          symbol: symbol,
          period: period,
          barCloseTime: DateTime.fromMillisecondsSinceEpoch(
            _intAt(row, 0),
            isUtc: true,
          ),
          open: _decimalAt(row, 1),
          high: _decimalAt(row, 2),
          low: _decimalAt(row, 3),
          close: _decimalAt(row, 4),
          volume: _decimalAt(row, 5),
          turnover: Decimal.zero,
        ),
  ];
  bars.sort((a, b) => a.barCloseTime.compareTo(b.barCloseTime));
  return bars;
}

String _string(Map<String, Object?> map, String key) {
  final v = map[key];
  if (v == null) throw FormatException('missing_$key');
  return v.toString();
}

int _int(Map<String, Object?> map, String key) => _intAt([map[key]], 0);

Decimal _decimal(Map<String, Object?> map, String key) =>
    _decimalAt([map[key]], 0);

int _intAt(List<dynamic> row, int index) {
  final v = row[index];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.parse(v);
  throw const FormatException('bad_int');
}

Decimal _decimalAt(List<dynamic> row, int index) {
  final v = row[index];
  if (v is num) return Decimal.parse(v.toString());
  if (v is String) return Decimal.parse(v);
  throw const FormatException('bad_number');
}
