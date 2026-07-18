mixin BIASEntity {
  /// BIAS 值 (乖离率 — % lệch giá so với MA), song song 1:1 với `calcParams`
  /// (mặc định 3 chu kỳ 6/12/24) — cùng pattern `maValueList`/`emaValueList`
  /// của MA/EMA, khác là dùng `double?` (không phải sentinel `0`) vì BIAS
  /// hợp lệ đi qua 0 (giá cắt MA) rất thường xuyên.
  List<double?>? biasValueList;
}
