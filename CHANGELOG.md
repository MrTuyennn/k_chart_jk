## 1.0.0

* **feat:** `KChartScaleState` — class lưu/khôi phục trạng thái zoom (`scaleX`, `scaleY`, `scrollX`). Truyền qua `KChartWidget.chartScale` để restore khi đổi timeframe; `scaleX` tự clamp theo `minScale`/`maxScale`. Callback `onChartScaleChanged` (`OnChartScaleChanged`) emit sau khi kết thúc pinch, scaleY drag, zoom controller, hoặc double-tap reset scaleY.
* **fix:** `onLoadMore(true)` không được gọi khi scale nhỏ đến mức tất cả data vừa khung hình (`maxScrollX == 0`). Đã bỏ guard `ChartPainter.maxScrollX > 0` và thêm post-frame callback trong `onScaleEnd` để trigger load thêm sau khi pinch zoom out.
* **feat:** Panel volume hiển thị thêm label giá trị nhỏ nhất (min vol trong vùng hiển thị) ở góc dưới-phải, giống cách MACD hiển thị min. `mVolMinValue` không còn hardcode `0` mà được tính từ data thực tế.

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
