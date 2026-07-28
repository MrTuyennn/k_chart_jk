/// ATR (Average True Range) entity — chỉ báo đo độ biến động (Wilder, 1978)
///
/// [atr]   — Average True Range, làm mượt kiểu Wilder từ True Range (TR).
///           TR = max(high-low, |high-prevClose|, |low-prevClose|).
///           Không chỉ hướng xu hướng, chỉ đo mức độ biến động: ATR cao →
///           thị trường biến động mạnh, ATR thấp → thị trường yên tĩnh.
///
/// [atrMa] — MA của ATR (đường tín hiệu, mặc định MA6) — dùng để so sánh
///           biến động hiện tại với trung bình gần đây, giảm nhiễu so với
///           dùng ATR một mình.
mixin ATREntity {
  double? atr;
  double? atrMa;
}
