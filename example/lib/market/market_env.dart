/// Toàn bộ endpoint (host, path REST, STOMP topic prefix) đọc từ
/// `--dart-define` — không hardcode trong source để tránh lộ khi đẩy lên git.
///
/// Chạy app / test với file env (git-ignored, xem `env.example.json`):
/// ```sh
/// flutter run --dart-define-from-file=env.dev.json
/// ```
abstract final class MarketEnv {
  static const String apiBaseUrl = String.fromEnvironment('MARKET_API_BASE');
  static const String stompUrl = String.fromEnvironment('MARKET_STOMP_URL');
  static const String symbol = String.fromEnvironment(
    'MARKET_SYMBOL',
    defaultValue: 'BTC/USDT',
  );

  /// Path REST lịch sử nến, nối sau [apiBaseUrl].
  static const String historyPath = String.fromEnvironment(
    'MARKET_HISTORY_PATH',
  );

  /// Topic prefix STOMP — code tự nối `/{BASE}/{QUOTE}` cho topic theo cặp.
  static const String topicKline = String.fromEnvironment(
    'MARKET_TOPIC_KLINE',
  );
  static const String topicKlineLive = String.fromEnvironment(
    'MARKET_TOPIC_KLINE_LIVE',
  );
  static const String topicThumb = String.fromEnvironment(
    'MARKET_TOPIC_THUMB',
  );
  static const String topicTradePlate = String.fromEnvironment(
    'MARKET_TOPIC_TRADE_PLATE',
  );

  /// false khi chạy thiếu dart-define — UI hiển thị hướng dẫn thay vì
  /// gọi API với URL/topic rỗng.
  static bool get isConfigured =>
      apiBaseUrl.isNotEmpty &&
      stompUrl.isNotEmpty &&
      historyPath.isNotEmpty &&
      topicKline.isNotEmpty &&
      topicKlineLive.isNotEmpty &&
      topicThumb.isNotEmpty &&
      topicTradePlate.isNotEmpty;
}
