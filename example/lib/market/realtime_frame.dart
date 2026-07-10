import 'package:meta/meta.dart';

/// Frame đã chuẩn hoá — độc lập STOMP ở tầng gọi.
@immutable
class RealtimeFrame {
  const RealtimeFrame({
    required this.destination,
    required this.body,
    required this.receivedAt,
  });

  final String destination;
  final String body;
  final DateTime receivedAt;
}

/// Ngưỡng "im lặng" trước khi coi 1 subscription là stale.
enum RealtimeStalePolicy { none, klineBar, fastStream }

extension RealtimeStalePolicyThreshold on RealtimeStalePolicy {
  Duration get watchdogThreshold => switch (this) {
    RealtimeStalePolicy.none => Duration.zero,
    RealtimeStalePolicy.klineBar => const Duration(seconds: 120),
    RealtimeStalePolicy.fastStream => const Duration(seconds: 15),
  };
}

@immutable
class RealtimeSubscription {
  const RealtimeSubscription({
    required this.destination,
    this.stalePolicy = RealtimeStalePolicy.none,
  });

  final String destination;
  final RealtimeStalePolicy stalePolicy;
}

enum RealtimeConnectionPhase {
  idle,
  connecting,
  connected,
  reconnecting,
  degraded,
  disposed,
}

@immutable
class RealtimeConnectionState {
  const RealtimeConnectionState({required this.phase, this.reason});
  final RealtimeConnectionPhase phase;
  final String? reason;
}
