import 'dart:convert';

import 'package:http/http.dart' as http;

import 'market_kline.dart';

/// REST bootstrap `GET {apiBaseUrl}{historyPath}` — trả bars đã sort tăng
/// dần theo close-time.
Future<List<MarketKline>> fetchMarketHistory({
  required String apiBaseUrl,
  required String historyPath,
  required String symbol,
  required String resolution, // phút ("1","15","60","240") hoặc "1D"/"1W"/"1M"
  required String period, // "1min",...,"1day" — gắn vào model để merge với WS
  required int fromMs,
  required int toMs,
  http.Client? client,
}) async {
  final uri = Uri.parse('$apiBaseUrl$historyPath').replace(
    queryParameters: {
      'symbol': symbol,
      'resolution': resolution,
      'from': '$fromMs',
      'to': '$toMs',
    },
  );
  final res = await (client?.get(uri) ?? http.get(uri));
  if (res.statusCode != 200) {
    throw http.ClientException('history_http_${res.statusCode}', uri);
  }
  return parseHistoryBars(
    jsonDecode(res.body),
    symbol: symbol,
    period: period,
  );
}
