mixin MTMEntity {
  /// MTM 值 (momentum: close - close N bars ago)
  double? mtm;

  /// MTM 的移动平均信号线 (MTMMA)
  double? mtmMa;
}
