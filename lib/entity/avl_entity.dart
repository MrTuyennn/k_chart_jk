mixin AVLEntity {
  /// AVL 值 — đường giá trị trung bình (cumulative VWAP):
  /// Σ(typicalPrice × vol) / Σ(vol) cộng dồn từ nến đầu tiên.
  double? avl;
}
