## 1.0.3

* **feat:** New secondary indicator `StochRSIIndicator` (StochRSI) — Stochastic RSI oscillator, `calcParams: [n1, n2, m1, m2]` (default `14, 14, 3, 3`: RSI period, Stoch period, %K smoothing, %D smoothing). Computes an internal Wilder-smoothed RSI (independent of `RSIIndicator` so it works even when RSI isn't enabled), then `StochRSI = (RSI - min(RSI, n2)) / (max(RSI, n2) - min(RSI, n2)) × 100`, `%K = SMA(StochRSI, m1)`, `%D = SMA(%K, m2)`. Draws the %K/%D line pair (`StochRSIStyle.kColor`/`dColor`) plus fixed 20/80 dashed reference lines, with the panel's min/max range always widened to include 20 and 80 so the reference lines never clip.
* **feat:** New main indicator `AVLIndicator` (AVL) — average value line, no period parameter. Plots the average execution price of each candle, `AVL = amount / vol` (quote volume ÷ base volume), falling back to typical price `(high + low + close) / 3` when `amount` is missing or zero, so the line always tracks inside the candle body like Binance's AVL. Styled via `AVLStyle.avlColor`.
* **feat:** New secondary indicator `MTMIndicator` (MTM) — momentum oscillator, `calcParams: [n, m]` (default `12, 6`: momentum period, signal MA period). `MTM = close - close[n bars ago]`, `MTMMA = MA(MTM, m)`. Draws the MTM/MTMMA line pair via `MTMStyle.mtmColor`/`mtmMaColor`, following the same `SecondaryIndicator` structure as MACD/TRIX.

## 1.0.2

* **feat:** New main indicator `SuperTrendIndicator` (SUPER) — an ATR-based trend line (Wilder's smoothing), `calcParams: [period, multiplier*10]`, direction (`isUp`) derived from the final upper/lower band, colored via `upColor`/`dnColor`. Also draws a shaded fill (`upFillColor`/`dnFillColor` on `SuperTrendStyle`) between the SuperTrend line and the close price to highlight the trend region, instead of just a single line.
* **feat:** New secondary indicator `TRIXIndicator` (TRIX) — a triple-smoothed EMA rate-of-change oscillator, `calcParams: [12, 20]` (triple-EMA period, signal MA period). Draws the TRIX/MATRIX line pair (`TRIXStyle.trixColor`/`trixMaColor`) in the secondary panel, following the same `SecondaryIndicator` structure as MACD/RSI.

## 1.0.1

* **fix:** `onLoadMore(true)` was never called when the initial data (or data after a previous load) didn't fill the chart's width (`ChartPainter.maxScrollX <= 0`) and the user hadn't performed any gesture yet. Previously `onLoadMore` only triggered from `onScaleUpdate`/`onScaleEnd`/fling, so a chart rendering fewer candles than its viewport width would sit stuck indefinitely. Added `_maybeLoadMoreForNarrowData()`, called from `initState`/`didUpdateWidget` (via `addPostFrameCallback` to wait for `ChartPainter.maxScrollX` to update after paint), guarded by `_narrowLoadRequestedForLength` so `onLoadMore` isn't re-fired on every rebuild unrelated to `datas` (style/theme changes, etc.).
* **docs:** Fixed doc comments that produced `dartdoc` warnings: the generic type `List<SecondaryIndicator<MACDEntity, dynamic>>` was being parsed as an HTML tag, and `[0]`/`[i]`/`[i-1]`/`[scaleX]` were being parsed as unresolved doc-reference links.

## 1.0.0

* **feat:** `KChartScaleState` — a class to save/restore zoom state (`scaleX`, `scaleY`, `scrollX`). Passed through `KChartWidget.chartScale` to restore when switching timeframes; `scaleX` is auto-clamped to `minScale`/`maxScale`. The `onChartScaleChanged` callback (`OnChartScaleChanged`) fires after a pinch ends, a scaleY drag, a zoom-controller action, or a double-tap scaleY reset.
* **fix:** `onLoadMore(true)` wasn't called when scale was small enough that all data fit within the viewport (`maxScrollX == 0`). Removed the `ChartPainter.maxScrollX > 0` guard and added a post-frame callback in `onScaleEnd` to trigger loading more data after a pinch zoom-out.
* **feat:** The volume panel now shows a minimum-value label (min volume in the visible range) in the bottom-right corner, mirroring how MACD shows its min. `mVolMinValue` is no longer hardcoded to `0` and is now computed from the actual data.

## 0.0.1

* Initial release of k_chart_jk — a Flutter candlestick chart package.
* Candlestick and line chart rendering with smooth gesture support (pan, zoom, fling).
* Main indicators: MA, EMA, BOLL, SAR, ZigZag.
* Secondary indicators: MACD, KDJ, RSI, WR, CCI.
* Volume bar chart with MA5/MA10 overlay.
* Long-press info dialog with customizable `detailBuilder`.
* Dark/light theme support via `KChartColors`.
* `KChartController` for programmatic zoom in/out and reset.
* Depth chart widget (`DepthChart`) for order book visualization.
* Multi-language support via `ChartTranslations`.
