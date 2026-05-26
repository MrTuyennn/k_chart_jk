/// OBV (On-Balance Volume) entity
///
/// [obv]       — giá trị OBV tích lũy tại mỗi nến.
///               Tăng khi close > close trước, giảm khi close < close trước.
///               Giá trị tuyệt đối không có ý nghĩa — chỉ xu hướng (slope) mới quan trọng.
///
/// [obvSignal] — MA của OBV (signal line, mặc định MA5).
///               Khi OBV cắt lên signal → tín hiệu bullish.
///               Khi OBV cắt xuống signal → tín hiệu bearish.
mixin OBVEntity {
  double? obv;
  double? obvSignal;
}
