import 'package:flutter/painting.dart';

/// Resolve style chữ dùng chung cho mọi renderer/indicator: nếu [base] đã tự
/// set `color` thì giữ nguyên (không ghi đè lựa chọn của caller), ngược lại
/// mới `copyWith` bằng [fallback]. [forceColor] = true bỏ qua `base.color`,
/// luôn dùng [fallback] — dùng cho label mà màu mang ý nghĩa riêng (vd
/// K/D/J của KDJ, MACD/DIF/DEA) không được đồng loạt bị `textStyle.color`
/// ghi đè như phần label khác.
TextStyle resolveTextStyle(
  TextStyle base,
  Color? fallback, {
  bool forceColor = false,
}) {
  if (!forceColor && base.color != null) return base;
  return base.copyWith(color: fallback);
}
