mixin AVLEntity {
  /// AVL 值 — giá khớp lệnh trung bình của TỪNG nến (không tích luỹ qua các nến):
  /// AVL = amount / vol; fallback (H+L+C)/3 khi thiếu amount. Xem AVLIndicator.calc().
  double? avl;
}
