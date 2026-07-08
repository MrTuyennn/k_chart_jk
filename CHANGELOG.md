## 1.0.1

* **fix:** `onLoadMore(true)` was never called when the initial data (or data after a previous load) didn't fill the chart's width (`ChartPainter.maxScrollX <= 0`) and the user hadn't performed any gesture yet. Previously `onLoadMore` only triggered from `onScaleUpdate`/`onScaleEnd`/fling, so a chart rendering fewer candles than its viewport width would sit stuck indefinitely. Added `_maybeLoadMoreForNarrowData()`, called from `initState`/`didUpdateWidget` (via `addPostFrameCallback` to wait for `ChartPainter.maxScrollX` to update after paint), guarded by `_narrowLoadRequestedForLength` so `onLoadMore` isn't re-fired on every rebuild unrelated to `datas` (style/theme changes, etc.).
* **docs:** Fixed doc comments that produced `dartdoc` warnings: the generic type `List<SecondaryIndicator<MACDEntity, dynamic>>` was being parsed as an HTML tag, and `[0]`/`[i]`/`[i-1]`/`[scaleX]` were being parsed as unresolved doc-reference links.

## 1.0.0

* **feat:** `KChartScaleState` — a class to save/restore zoom state (`scaleX`, `scaleY`, `scrollX`). Passed through `KChartWidget.chartScale` to restore when switching timeframes; `scaleX` is auto-clamped to `minScale`/`maxScale`. The `onChartScaleChanged` callback (`OnChartScaleChanged`) fires after a pinch ends, a scaleY drag, a zoom-controller action, or a double-tap scaleY reset.
* **fix:** `onLoadMore(true)` wasn't called when scale was small enough that all data fit within the viewport (`maxScrollX == 0`). Removed the `ChartPainter.maxScrollX > 0` guard and added a post-frame callback in `onScaleEnd` to trigger loading more data after a pinch zoom-out.
* **feat:** The volume panel now shows a minimum-value label (min volume in the visible range) in the bottom-right corner, mirroring how MACD shows its min. `mVolMinValue` is no longer hardcoded to `0` and is now computed from the actual data.

## 0.0.1

* Initial release of k_chart_wikex — a Flutter candlestick chart package.
* Candlestick and line chart rendering with smooth gesture support (pan, zoom, fling).
* Main indicators: MA, EMA, BOLL, SAR, ZigZag.
* Secondary indicators: MACD, KDJ, RSI, WR, CCI.
* Volume bar chart with MA5/MA10 overlay.
* Long-press info dialog with customizable `detailBuilder`.
* Dark/light theme support via `KChartColors`.
* `KChartController` for programmatic zoom in/out and reset.
* Depth chart widget (`DepthChart`) for order book visualization.
* Multi-language support via `ChartTranslations`.
