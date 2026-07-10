import 'dart:async';

import 'package:stomp_dart_client/stomp_dart_client.dart';

import 'realtime_frame.dart';

class _Entry {
  _Entry({required this.subscription});
  final RealtimeSubscription subscription;
  StompUnsubscribe? unsubscribe;
  DateTime? lastMessageAt;
}

/// STOMP + SockJS, refcount theo destination, replay khi reconnect,
/// watchdog resubscribe khi 1 topic "im lặng" quá ngưỡng.
class MarketStompTransport {
  MarketStompTransport({required String stompUrl, bool useSockJs = true})
    : _stompUrl = stompUrl,
      _useSockJs = useSockJs;

  final String _stompUrl;
  final bool _useSockJs;

  StompClient? _client;
  bool _shutdown = false;
  Timer? _watchdog;
  RealtimeConnectionPhase? _lastPhase;

  final Map<String, int> _refCount = {};
  final Map<String, _Entry> _entries = {};
  final Map<String, StreamController<RealtimeFrame>> _broadcast = {};

  final _stateController =
      StreamController<RealtimeConnectionState>.broadcast();
  Stream<RealtimeConnectionState> get connectionStates =>
      _stateController.stream;

  Future<void> _serialized = Future<void>.value();

  Future<void> _runSerialized(Future<void> Function() fn) async {
    final previous = _serialized;
    final completer = Completer<void>();
    _serialized = completer.future;
    await previous;
    try {
      await fn();
    } finally {
      completer.complete();
    }
  }

  /// SockJS cần base `http(s)://`; env thường ghi `wss://`.
  static String _sockJsBaseUrl(String url) {
    if (url.startsWith('wss://')) return 'https://${url.substring(6)}';
    if (url.startsWith('ws://')) return 'http://${url.substring(5)}';
    return url;
  }

  StompConfig _buildConfig() {
    final url = _useSockJs ? _sockJsBaseUrl(_stompUrl) : _stompUrl;
    const reconnectDelay = Duration(seconds: 4);
    const heartbeat = Duration(seconds: 10);
    const connectionTimeout = Duration(seconds: 30);

    void onDisconnect(StompFrame _) => _emit(RealtimeConnectionPhase.idle);
    void onWsDone() => _emit(RealtimeConnectionPhase.reconnecting);
    void onWsError(dynamic _) => _emit(RealtimeConnectionPhase.reconnecting);
    void onStompError(StompFrame _) =>
        _emit(RealtimeConnectionPhase.degraded, reason: 'stomp_error');

    if (_useSockJs) {
      return StompConfig.sockJS(
        url: url,
        reconnectDelay: reconnectDelay,
        heartbeatIncoming: heartbeat,
        heartbeatOutgoing: heartbeat,
        connectionTimeout: connectionTimeout,
        onConnect: _onConnected,
        onDisconnect: onDisconnect,
        onWebSocketDone: onWsDone,
        onWebSocketError: onWsError,
        onStompError: onStompError,
      );
    }
    return StompConfig(
      url: url,
      reconnectDelay: reconnectDelay,
      heartbeatIncoming: heartbeat,
      heartbeatOutgoing: heartbeat,
      connectionTimeout: connectionTimeout,
      onConnect: _onConnected,
      onDisconnect: onDisconnect,
      onWebSocketDone: onWsDone,
      onWebSocketError: onWsError,
      onStompError: onStompError,
    );
  }

  void _emit(RealtimeConnectionPhase phase, {String? reason}) {
    if (_lastPhase == phase) return;
    _lastPhase = phase;
    if (!_stateController.isClosed) {
      _stateController.add(
        RealtimeConnectionState(phase: phase, reason: reason),
      );
    }
  }

  void _onConnected(StompFrame frame) {
    unawaited(
      _replayAfterConnect().then(
        (_) => _emit(RealtimeConnectionPhase.connected),
      ),
    );
  }

  Future<void> _replayAfterConnect() async {
    final client = _client;
    if (client == null || !client.connected) return;
    for (final e in _entries.entries.toList()) {
      if ((_refCount[e.key] ?? 0) <= 0) continue;
      e.value.unsubscribe?.call();
      e.value.unsubscribe = null;
      _attach(e.key, e.value);
    }
  }

  void _attach(String destination, _Entry entry) {
    final client = _client;
    if (client == null || !client.connected) return;
    entry.unsubscribe = client.subscribe(
      destination: destination,
      callback: (frame) {
        // Header `destination` gửi về có thể khác topic đã subscribe — chỉ
        // dùng làm fallback hiển thị, key nội bộ vẫn là destination subscribe.
        final headerDest = frame.headers['destination'];
        final resolved = (headerDest != null && headerDest.isNotEmpty)
            ? headerDest
            : destination;
        entry.lastMessageAt = DateTime.now();
        final sink = _broadcast[destination];
        if (sink != null && !sink.isClosed) {
          sink.add(
            RealtimeFrame(
              destination: resolved,
              body: frame.body ?? '',
              receivedAt: DateTime.now(),
            ),
          );
        }
      },
    );
  }

  void _startWatchdog() {
    _watchdog ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickWatchdog(),
    );
  }

  void _tickWatchdog() {
    if (_shutdown) return;
    final now = DateTime.now();
    for (final e in _entries.entries.toList()) {
      if ((_refCount[e.key] ?? 0) <= 0) continue;
      final entry = e.value;
      final threshold = entry.subscription.stalePolicy.watchdogThreshold;
      if (threshold == Duration.zero) continue;
      final last = entry.lastMessageAt;
      if (last == null) continue; // chưa có message → chưa có mốc so sánh
      if (now.difference(last) > threshold) {
        entry.unsubscribe?.call();
        entry.unsubscribe = null;
        _attach(e.key, entry);
        entry.lastMessageAt = null;
      }
    }
  }

  Future<void> ensureConnected() async {
    if (_shutdown) return;
    if (_client?.connected == true) return;
    _client ??= StompClient(config: _buildConfig());
    _emit(RealtimeConnectionPhase.connecting);
    _client!.activate();
    _startWatchdog();
  }

  /// Đăng ký logical stream; refcount dedupe SUBSCRIBE thật lên broker.
  Stream<RealtimeFrame> subscribe(RealtimeSubscription request) async* {
    if (_shutdown) return;
    await ensureConnected();

    late StreamController<RealtimeFrame> controller;
    await _runSerialized(() async {
      final isFirst = (_refCount[request.destination] ?? 0) == 0;
      _refCount[request.destination] =
          (_refCount[request.destination] ?? 0) + 1;
      if (isFirst) {
        _entries[request.destination] = _Entry(subscription: request);
        if (_client?.connected == true) {
          _attach(request.destination, _entries[request.destination]!);
        }
      }
      controller = _broadcast.putIfAbsent(
        request.destination,
        StreamController<RealtimeFrame>.broadcast,
      );
    });

    try {
      await for (final frame in controller.stream) {
        yield frame;
      }
    } finally {
      await _release(request.destination);
    }
  }

  Future<void> _release(String destination) async {
    await _runSerialized(() async {
      final current = _refCount[destination];
      if (current == null) return;
      final next = current - 1;
      if (next <= 0) {
        _refCount.remove(destination);
        final entry = _entries.remove(destination);
        entry?.unsubscribe?.call();
        final bc = _broadcast.remove(destination);
        if (bc != null && !bc.isClosed) unawaited(bc.close());
      } else {
        _refCount[destination] = next;
      }
    });
  }

  Future<void> shutdown() async {
    _shutdown = true;
    _watchdog?.cancel();
    _watchdog = null;
    for (final c in _broadcast.values) {
      if (!c.isClosed) await c.close();
    }
    _broadcast.clear();
    _entries.clear();
    _refCount.clear();
    _client?.deactivate();
    _client = null;
  }
}
