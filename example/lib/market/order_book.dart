import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:meta/meta.dart';

import 'realtime_frame.dart';

enum OrderBookDirection { buy, sell }

/// Một mức giá trong sổ lệnh (bid hoặc ask).
@immutable
class OrderBookLevel {
  const OrderBookLevel({
    required this.price,
    required this.priceText,
    required this.quantity,
  });

  final Decimal price;

  /// Giữ nguyên chuỗi wire (tránh mất số 0 cuối, vd "0.09800").
  final String priceText;
  final Decimal quantity;
}

/// Snapshot 2 phía dùng cho UI — bids giảm dần giá, asks tăng dần giá.
@immutable
class OrderBookSnapshot {
  const OrderBookSnapshot({
    required this.version,
    this.bids = const [],
    this.asks = const [],
    this.maxBidQuantity,
    this.maxAskQuantity,
  });

  final int version;
  final List<OrderBookLevel> bids;
  final List<OrderBookLevel> asks;

  /// Từ WS BUY `maxAmount` — dùng scale độ dài thanh depth bên bid.
  final Decimal? maxBidQuantity;

  /// Từ WS SELL `maxAmount` — dùng scale độ dài thanh depth bên ask.
  final Decimal? maxAskQuantity;

  bool get hasBothSides => bids.isNotEmpty && asks.isNotEmpty;
}

/// Một phía (BUY hoặc SELL) parse từ 1 message trade-plate, trước khi merge.
@immutable
class OrderBookSideUpdate {
  const OrderBookSideUpdate({
    required this.direction,
    required this.symbol,
    required this.levels,
    required this.maxQuantity,
  });

  final OrderBookDirection direction;
  final String symbol;
  final List<OrderBookLevel> levels;
  final Decimal maxQuantity;
}

/// Parse payload WS trade-plate (một phía sổ lệnh) — trả null nếu
/// frame hỏng hoặc `symbol` không khớp cặp đang xem (broker gửi lẫn).
OrderBookSideUpdate? tryParseOrderBookSideFrame(
  RealtimeFrame frame, {
  required String expectedSymbol,
}) {
  try {
    final decoded = jsonDecode(frame.body);
    if (decoded is! Map) return null;
    final map = Map<String, Object?>.from(decoded);

    final symbol = map['symbol']?.toString() ?? '';
    if (symbol != expectedSymbol) return null;

    final directionRaw = (map['direction']?.toString() ?? '').toUpperCase();
    final direction = switch (directionRaw) {
      'BUY' => OrderBookDirection.buy,
      'SELL' => OrderBookDirection.sell,
      _ => throw const FormatException('invalid_direction'),
    };

    final itemsRaw = map['items'];
    if (itemsRaw is! List) throw const FormatException('missing_items');
    final levels = <OrderBookLevel>[
      for (final item in itemsRaw)
        if (item is Map)
          OrderBookLevel(
            price: _decimal(item, 'price'),
            priceText: _string(item, 'price'),
            quantity: _decimal(item, 'amount'),
          )
        else
          throw const FormatException('bad_item'),
    ];

    return OrderBookSideUpdate(
      direction: direction,
      symbol: symbol,
      levels: levels,
      maxQuantity: _decimal(map, 'maxAmount'),
    );
  } on FormatException {
    return null;
  }
}

/// Số mức tối đa giữ lại mỗi phía (đủ cho UI, tránh list quá dài).
const int kOrderBookMaxLevels = 50;

/// Gộp BUY/SELL trade-plate thành [OrderBookSnapshot]
/// (last-write-wins từng phía — phía kia giữ nguyên).
///
/// Giữ state theo pair đang xem — nếu hiển thị nhiều pair cùng lúc, mỗi
/// luồng phải có instance riêng. Gọi [reset] khi đổi pair / subscribe lại.
class OrderBookMergeService {
  OrderBookSnapshot _snapshot = const OrderBookSnapshot(version: 0);

  OrderBookSnapshot get current => _snapshot;

  /// Gọi khi đổi pair / bắt đầu subscribe lại — tránh lẫn dữ liệu cặp cũ.
  void reset() {
    _snapshot = const OrderBookSnapshot(version: 0);
  }

  OrderBookSnapshot apply(OrderBookSideUpdate side) {
    final sorted = switch (side.direction) {
      OrderBookDirection.buy => _sortDesc(side.levels), // bid: giá cao trước
      OrderBookDirection.sell => _sortAsc(side.levels), // ask: giá thấp trước
    };
    final capped = sorted.length > kOrderBookMaxLevels
        ? sorted.sublist(0, kOrderBookMaxLevels)
        : sorted;

    final nextVersion = _snapshot.version + 1;
    return _snapshot = switch (side.direction) {
      OrderBookDirection.buy => OrderBookSnapshot(
        version: nextVersion,
        bids: capped,
        asks: _snapshot.asks,
        maxBidQuantity: side.maxQuantity,
        maxAskQuantity: _snapshot.maxAskQuantity,
      ),
      OrderBookDirection.sell => OrderBookSnapshot(
        version: nextVersion,
        bids: _snapshot.bids,
        asks: capped,
        maxBidQuantity: _snapshot.maxBidQuantity,
        maxAskQuantity: side.maxQuantity,
      ),
    };
  }

  List<OrderBookLevel> _sortDesc(List<OrderBookLevel> levels) =>
      List<OrderBookLevel>.from(levels)
        ..sort((a, b) => b.price.compareTo(a.price));

  List<OrderBookLevel> _sortAsc(List<OrderBookLevel> levels) =>
      List<OrderBookLevel>.from(levels)
        ..sort((a, b) => a.price.compareTo(b.price));
}

String _string(Map<Object?, Object?> map, String key) {
  final v = map[key];
  if (v == null) throw FormatException('missing_$key');
  return v.toString();
}

Decimal _decimal(Map<Object?, Object?> map, String key) {
  final v = map[key];
  if (v == null) throw FormatException('missing_$key');
  if (v is num) return Decimal.parse(v.toString());
  if (v is String) return Decimal.parse(v);
  throw FormatException('bad_number_$key');
}
