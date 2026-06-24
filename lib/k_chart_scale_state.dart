/// Trạng thái zoom chart — lưu/khôi phục khi đổi timeframe.
///
/// Giới hạn [scaleX] dùng chung với [KChartWidget.minScale] / [KChartWidget.maxScale].
class KChartScaleState {
  /// Zoom ngang (pinch). Clamp bởi `KChartWidget.minScale` / `maxScale`.
  final double scaleX;

  /// Zoom dọc vùng giá main.
  final double scaleY;

  /// Offset scroll ngang. `0` = sát nến mới nhất.
  final double scrollX;

  const KChartScaleState({
    this.scaleX = 0.8, // setting tỉ lệ
    this.scaleY = 1.0,
    this.scrollX = 0.0,
  });

  /// Clamp [scaleX] theo [minScale] / [maxScale] của widget (không thêm param giới hạn mới).
  KChartScaleState clampedTo({
    required double minScale,
    required double maxScale,
  }) {
    return copyWith(scaleX: scaleX.clamp(minScale, maxScale));
  }

  KChartScaleState copyWith({double? scaleX, double? scaleY, double? scrollX}) {
    return KChartScaleState(
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      scrollX: scrollX ?? this.scrollX,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is KChartScaleState &&
        other.scaleX == scaleX &&
        other.scaleY == scaleY &&
        other.scrollX == scrollX;
  }

  @override
  int get hashCode => Object.hash(scaleX, scaleY, scrollX);

  @override
  String toString() =>
      'KChartScaleState(scaleX: $scaleX, scaleY: $scaleY, scrollX: $scrollX)';
}
