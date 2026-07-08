# k_chart_wikex — Tài liệu tổng hợp

> Tổng hợp từ: `HANDBOOK.md`, `chart_wikex.md`, `chart_plush.md`, `CHANGELOG.md`, `chart_wikex_arch.md`.

---

## Mục lục

1. [Changelog](#1-changelog)
2. [Tổng quan kiến trúc](#2-tổng-quan-kiến-trúc)
3. [Cài đặt & Quick Start](#3-cài-đặt--quick-start)
4. [Entry point & exports](#4-entry-point--exports)
5. [Entity — data models](#5-entity--data-models)
6. [KChartWidget — API đầy đủ](#6-kchartwidget--api-đầy-đủ)
7. [KChartController](#7-kchartcontroller)
8. [KChartStyle & KChartColors](#8-kchartstyle--kchartcolors)
9. [Indicators — main & secondary](#9-indicators--main--secondary)
10. [DataUtil & helpers](#10-datautil--helpers)
11. [DepthChart — orderbook depth](#11-depthchart--orderbook-depth)
12. [Renderer internals](#12-renderer-internals)
13. [Gesture model](#13-gesture-model)
14. [Recipes — công thức thường dùng](#14-recipes--công-thức-thường-dùng)
    - [14.10 Real-time WebSocket price ticker](#1410-real-time-websocket-price-ticker)
15. [Troubleshooting & pitfalls](#15-troubleshooting--pitfalls)
16. [Phân tích cơ chế Y Grid & Anchor Zoom (MEXC / TradingView)](#16-phân-tích-cơ-chế-y-grid--anchor-zoom-mexc--tradingview)

---

## 1. Changelog

### Unreleased

- **feat:** `StochRSIIndicator` — secondary indicator Stochastic RSI. Xem chi tiết [9.2](#92-built-in-indicators).
  - `calcParams: [14, 14, 3, 3]` — (N1: RSI length, N2: Stoch length, M1: smooth %K, M2: smooth %D), chuẩn Binance/TradingView.
  - Công thức: RSI Wilder tính **nội bộ** trong `calc()` (không dùng lại `entity.rsi` — RSIIndicator có thể không được bật, period có thể khác), `StochRSI = (RSI − MIN(RSI,N2)) / (MAX(RSI,N2) − MIN(RSI,N2)) × 100`, `%K = SMA(StochRSI, M1)`, `%D = SMA(%K, M2)`. Pipeline 4 tầng chạy 1 vòng lặp O(n).
  - Output: `entity.stochRsiK` / `entity.stochRsiD` — mixin mới `StochRSIEntity` (`lib/entity/stoch_rsi_entity.dart`), nối vào `on` clause của `MACDEntity`, đứng **trước** `MACDEntity` trong `KEntity`.
  - Style: `StochRSIStyle({ kColor, dColor })` — K vàng `0xFFFFC634`, D xanh `0xff35cdac`.
  - Kèm **2 đường tham chiếu nét đứt 20/80** (quá bán/quá mua) kiểu Binance qua `referenceValues => [20, 80]`; `getMaxMinValue` ép range panel bao luôn `[20, 80]` để vạch không chạy ra ngoài.
  - Edge case: `MAX == MIN` (RSI đi ngang tuyệt đối) → StochRSI = 0 theo convention TradingView. Null-chain: %K có từ nến ~30, %D từ nến ~32 với params mặc định.
- **feat:** Cơ chế **đường tham chiếu ngang** dùng chung cho mọi secondary indicator (không riêng StochRSI):
  - `SecondaryIndicator.referenceValues` — getter mới, mặc định `[]`; indicator phụ nào muốn có vạch mốc chỉ cần override, không đụng renderer.
  - `SecondaryRenderer.drawReferenceLines(canvas)` — vẽ nét đứt 4px-4px, màu `defaultTextColor` alpha 90, strokeWidth 0.5, một lần mỗi frame.
  - Gọi từ `ChartPainter.drawChart()` ở **screen space trước translate/scale** → vạch không giãn theo scaleX, nằm phía sau đường indicator, và **vẫn hiển thị khi `hideGrid = true`** (khác grid thường).
  - Kéo theo: `ChartPainter.mSecondaryRendererList` thu hẹp kiểu từ `Set<BaseChartRenderer>` → `Set<SecondaryRenderer>`.
- **feat:** `AVLIndicator` — main indicator Average Value Line kiểu Binance, đường đi xuyên qua thân nến. Xem chi tiết [9.2](#92-built-in-indicators).
  - Công thức: `AVL = amount / vol` — giá khớp lệnh trung bình thực của từng nến (quote volume ÷ base volume); fallback khi `amount` null/0 hoặc `vol = 0`: typical price `(H+L+C)/3` (vẫn luôn nằm trong range high–low của nến).
  - `calcParams: []` — không có param chu kỳ.
  - Output: `entity.avl` — mixin mới `AVLEntity` (`lib/entity/avl_entity.dart`); theo pattern ZigZag: đứng **sau** `MACDEntity` trong `KEntity`, indicator cast `entity as AVLEntity` (main indicator dùng `CandleEntity` làm T — không cần vào `on` clause).
  - Style: `AVLStyle({ avlColor, lineWidth })` — mặc định vàng `0xFFFFC634`, lineWidth 1.0.
  - Cần API trả `amount` (quote volume) để có giá trị thực; thiếu thì fallback vẫn bám nến nhưng không phản ánh volume-weighting. Biến thể đã thử và bỏ: cumulative VWAP (đường trôi xa khỏi cụm nến, kéo giãn trục Y), rolling VWAP N nến (mượt nhưng vẫn lệch nến, không giống Binance).
- **feat:** `MTMIndicator` — secondary indicator Momentum. Xem chi tiết [9.2](#92-built-in-indicators).
  - `calcParams: [12, 6]` — (N: chu kỳ momentum, M: chu kỳ MA signal).
  - Công thức: `MTM = CLOSE − REF(CLOSE, N)` (biến thể tuyệt đối classic), `MTMMA = MA(MTM, M)` — sliding-window sum O(n).
  - Output: `entity.mtm` / `entity.mtmMa` — mixin mới `MTMEntity` (`lib/entity/mtm_entity.dart`), nối vào `on` clause của `MACDEntity`, đứng **trước** `MACDEntity` trong `KEntity`.
  - Style: `MTMStyle({ mtmColor, mtmMaColor })` — MTM vàng `0xFFFFC634`, MTMMA xanh `0xff35cdac`.
  - Null: `mtm` null khi `i < N`; `mtmMa` null tới khi đủ M giá trị MTM. Scale phụ thuộc giá tuyệt đối của symbol (BTC ra hàng trăm/nghìn) — cần scale % thì đổi 1 dòng trong `calc()` sang ROC-style `(CLOSE − REF)/REF × 100`.
- **feat:** `entity/index.dart` export đầy đủ các entity mixin: bổ sung `avl_entity.dart`, `mtm_entity.dart`, `stoch_rsi_entity.dart`, và `trix_entity.dart` (trước đây bị sót export dù TRIX đã release ở 1.0.2).
- **feat:** Example app (`example/lib/main.dart`) bổ sung chip toggle cho các indicator mới:
  - Main: **ZigZag** (indicator có từ 0.0.1 nhưng chưa có chip demo), **AVL**.
  - Secondary: **MTM**, **StochRSI**.

### 1.0.2

- **feat:** `SuperTrendIndicator` (SUPER) — main indicator SuperTrend. Xem chi tiết [9.2](#92-built-in-indicators).
  - `calcParams: [10, 30]` — (N: ATR period, multiplier×10 → factor 3.0).
  - Công thức: `ATR = RMA(TR, N)` (seed = SMA(TR,N), sau đó Wilder smoothing `atr = (atr×(N−1)+tr)/N`), band = `(H+L)/2 ± factor×ATR`, trend flip khi close cắt qua band hiện tại.
  - Output: `entity.superTrend = SuperTrend { value, isUp }` — class định nghĩa trong `super_trend_indicator.dart`, field nằm ở `CandleEntity` (main indicator, không cần entity mixin riêng).
  - Style: `SuperTrendStyle({ upColor, dnColor, upFillColor, dnFillColor, lineWidth })` — đường đổi màu theo `isUp` (xanh uptrend/band dưới giá, đỏ downtrend/band trên giá) + fill mờ giữa band và giá; label `SUPER: x` cũng đổi màu theo trend.
- **feat:** `TRIXIndicator` (TRIX) — secondary indicator TRIX/MATRIX. Xem chi tiết [9.2](#92-built-in-indicators).
  - `calcParams: [12, 20]` — (N: chu kỳ triple EMA, M: chu kỳ MA signal).
  - Công thức: `EMA1 = EMA(CLOSE,N)`, `EMA2 = EMA(EMA1,N)`, `EMA3 = EMA(EMA2,N)`, `TRIX = (EMA3 − REF(EMA3,1)) / REF(EMA3,1) × 100`, `MATRIX = MA(TRIX, M)` — EMA seed bằng close nến đầu, MA signal sliding-window sum O(n).
  - Output: `entity.trix` / `entity.trixMa` — mixin `TRIXEntity` (`lib/entity/trix_entity.dart`), nối vào `on` clause của `MACDEntity`, đứng **trước** `MACDEntity` trong `KEntity`.
  - Style: `TRIXStyle({ trixColor, trixMaColor })` — TRIX vàng `0xFFFFC634`, MATRIX xanh `0xff35cdac`.
  - Null: `trix` null ở nến đầu (chưa có `prevEma3`); `trixMa` null tới khi đủ M giá trị TRIX.

### 1.0.1

- **fix:** `onLoadMore(true)` không được tự động gọi khi data ban đầu (hoặc sau khi load thêm) chưa lấp đầy chiều rộng chart (`ChartPainter.maxScrollX <= 0`) và user chưa thực hiện gesture nào. Trước đây `onLoadMore` chỉ trigger từ `onScaleUpdate`/`onScaleEnd`/fling nên chart hiển thị ít data hơn màn hình sẽ đứng im vô thời hạn. Đã thêm `_maybeLoadMoreForNarrowData()` gọi trong `initState`/`didUpdateWidget` (qua `addPostFrameCallback`), guard bằng `_narrowLoadRequestedForLength` để không gọi trùng `onLoadMore` mỗi khi widget rebuild vì lý do không liên quan tới `datas`. Chi tiết: [13.9](#139-auto-load-khi-data-chưa-lấp-đầy-chart-không-cần-gesture).
- **docs:** Sửa doc comment gây warning khi generate `dartdoc`: generic type `List<SecondaryIndicator<MACDEntity, dynamic>>` bị hiểu nhầm là thẻ HTML, và `[0]`/`[i]`/`[i-1]`/`[scaleX]` bị hiểu nhầm là doc-reference link không tồn tại.

### 1.0.0

- **feat:** `KChartScaleState` — class lưu/khôi phục trạng thái zoom (`scaleX`, `scaleY`, `scrollX`). Truyền qua `KChartWidget.chartScale` để restore khi đổi timeframe; `scaleX` tự clamp theo `minScale`/`maxScale`. Callback `onChartScaleChanged` (`OnChartScaleChanged`) emit sau khi kết thúc pinch, scaleY drag, zoom controller, hoặc double-tap reset scaleY.
- **feat:** Panel volume hiển thị thêm label giá trị nhỏ nhất (min vol trong vùng hiển thị) ở góc dưới-phải, giống cách MACD hiển thị min. `mVolMinValue` không còn hardcode `0` mà được tính từ data thực tế.

### 0.0.1

- Initial release of k_chart_wikex — a Flutter candlestick chart package.
- Candlestick and line chart rendering with smooth gesture support (pan, zoom, fling).
- Main indicators: MA, EMA, BOLL, SAR, ZigZag.
- Secondary indicators: MACD, KDJ, RSI, WR, CCI.
- Volume bar chart with MA5/MA10 overlay.
- Long-press info dialog with customizable `detailBuilder`.
- Dark/light theme support via `KChartColors`.
- `KChartController` for programmatic zoom in/out and reset.
- Depth chart widget (`DepthChart`) for order book visualization.
- Multi-language support via `ChartTranslations`.

---

## 2. Tổng quan kiến trúc

Mã nguồn chart được thiết kế theo mô hình:

- `KChartWidget`: widget chứa, xử lý tương tác (gesture, scroll, scale, long-press, pointer tracking cho parent), và tạo `ChartPainter`.
- `ChartPainter`: lớp vẽ chính, kế thừa `BaseChartPainter`.
- `BaseChartPainter`: xử lý layout (chia rect), phạm vi dữ liệu (visible window), và điều phối paint.
- `MainRenderer`: vẽ đồ thị chính (nến hoặc line), chạy từng `MainIndicator` (MA/BOLL/EMA/SAR/ZigZag/SuperTrend/AVL) trong cùng vùng `mMainRect`.
- `VolRenderer`: vẽ panel volume (bars + MA5/MA10) trong `mVolRect`. Toggle bằng `volHidden` ở `KChartWidget`.
- `SecondaryRenderer`: vẽ một panel indicator phụ (MACD/KDJ/RSI/WR/CCI/OBV/TRIX/MTM/StochRSI). Mỗi entry trong `secondaryIndicators` có 1 instance riêng.
- `DepthChartPainter`: vẽ orderbook depth (Buy/Sell pressure) — standalone, không gắn với `KChartWidget`.

> **Ghi chú quan trọng:** toàn bộ chart chính của `KChartWidget` được vẽ trong một `CustomPaint` duy nhất. `KChartWidget` tạo ra `ChartPainter`, và `ChartPainter` quản lý canvas chung, dùng các renderer nội bộ để vẽ từng phần trong cùng một hộp vẽ.

### Sơ đồ đơn giản

```
KChartWidget  (state + gesture)
└─ Stack
   ├─ ColoredBox(bgColor)                     ← chỉ khi có backgroundLogo
   ├─ backgroundLogo (IgnorePointer, Center)  ← watermark giữa main rect
   ├─ CustomPaint(painter: ChartPainter)
   │   └─ ChartPainter.paint()
   │       ├─ initRect()              → mMainRect, mVolRect?, mDateRect, mSecondaryRectList[]
   │       ├─ calculateValue()        → mStartIndex/mStopIndex + max/min
   │       ├─ initChartRenderer()     → mMainRenderer + mVolRenderer? + mSecondaryRendererList[]
   │       ├─ drawBg()                (skip nếu skipBg)
   │       ├─ drawGrid()
   │       ├─ drawChart()
   │       │   ├─ canvas: translate(mTranslateX*scaleX) + scale(scaleX, 1)
   │       │   ├─ scaleY scope:
   │       │   │   ├─ clipRect(mMainRect band)
   │       │   │   ├─ translate(0, centerY*(1-scaleY) + offsetY)
   │       │   │   ├─ scale(1, scaleY)
   │       │   │   └─ loop indices → mMainRenderer.drawChart()
   │       │   ├─ loop indices (ngoài scaleY)
   │       │   │   ├─ mVolRenderer?.drawChart()
   │       │   │   └─ for each SecondaryRenderer.drawChart()
   │       │   └─ drawCrossLine / drawTrendLines
   │       ├─ drawVerticalText()       (main + vol + secondaries)
   │       ├─ drawDate()
   │       ├─ drawText(getItem(mStopIndex))    (main + vol + secondaries)
   │       ├─ drawMaxAndMin() / drawNowPrice()     (qua _applyScaleY)
   │       └─ drawCrossLineText() (nếu long-press/tap)
   └─ Positioned (right:0) + LayoutBuilder → w = effectiveRightPaddingPx
       ─ vùng gesture scaleY + double-tap reset scaleY/offsetY
```

### Flow dữ liệu

1. Chuẩn bị `List<KLineEntity>` (mỗi entity = 1 nến OHLCV + time).
2. Gọi `DataUtil.calculateAll(data, mainIndicators, secondaryIndicators)` để tính chỉ báo.
3. Truyền list vào `KChartWidget` cùng style/colors/indicators.
4. `ChartPainter` đọc data đã tính, dùng renderer để vẽ từng nến + indicator.
5. `KChartController` ở ngoài có thể gọi `zoomIn` / `zoomOut` / `reset`.

### Quy tắc quan trọng để port sang source khác

- **Widget quản lý trạng thái + gesture, painter vẽ toàn bộ.**
- **Một `CustomPaint`** cho main chart; secondary indicators KHÔNG phải widget riêng.
- **Tính min/max chỉ trên vùng dữ liệu visible** (`mStartIndex..mStopIndex`).
- **`scrollX` và `scaleX` thành phép biến đổi canvas**, không vẽ tay từng phần.
- **`scaleY` áp riêng cho main**, secondary nằm ngoài transform để không bị giãn.
- **Mọi label vẽ ngoài canvas transform** phải đi qua `_applyScaleY(rawY)`.

---

## 3. Cài đặt & Quick Start

### Dependency

```yaml
dependencies:
  k_chart_wikex:
    git:
      url: <repo-url>
```

### Quick start tối thiểu

```dart
import 'package:k_chart_wikex/k_chart_plus.dart';

final data = [
  KLineEntity.fromCustom(
    time: 1700000000000,
    open: 65000, close: 65500, high: 65800, low: 64900,
    vol: 12.3,
  ),
  // ...
];

DataUtil.calculateAll(
  data,
  [MAIndicator()],
  [MACDIndicator()],
);

KChartWidget(
  data,
  const KChartStyle(),
  const KChartColors(),
  isTrendLine: false,
  detailBuilder: (entity) => Text(entity.close.toString()),
  mainIndicators: [MAIndicator()],
  secondaryIndicators: [MACDIndicator()],
)
```

---

## 4. Entry point & exports

File chính import: `package:k_chart_wikex/k_chart_plus.dart`. Re-export:

| Export                              | Chứa gì                                                                              |
| ----------------------------------- | ------------------------------------------------------------------------------------ |
| `k_chart_widget.dart`               | `KChartWidget`, `TimeFormat`, `WidgetDetailBuilder`                                  |
| `styles/k_chart_style.dart`         | `KChartStyle`, `KChartColors`                                                        |
| `styles/depth_chart_style.dart`     | `DepthChartStyle`, `DepthChartColors`                                                |
| `depth_chart.dart`                  | `DepthChart` widget                                                                  |
| `chart_translations.dart`           | `DepthChartTranslations`                                                             |
| `utils/index.dart`                  | `DataUtil`, `dateFormat`, `NumberUtil`, format tokens                                |
| `entity/index.dart`                 | Toàn bộ entity & mixin                                                               |
| `renderer/index.dart`               | `ChartPainter`, `BaseChartPainter`, renderer base                                    |
| `renderer/k_chart_controller.dart`  | `KChartController`                                                                   |
| `extension/num_ext.dart`            | `num.toStringAsFixedNoZero(...)`                                                     |
| `indicator/indicator_template.dart` | `IndicatorTemplate`, `MainIndicator`, `SecondaryIndicator`, tất cả indicator + style |

---

## 5. Entity — data models

### 5.1 `KLineEntity`

Nến chính. Kế thừa `KEntity` (multi-mixin) → mang sẵn slot cho mọi chỉ báo.

| Field    | Kiểu      | Ý nghĩa                           |
| -------- | --------- | --------------------------------- |
| `open`   | `double`  | Giá mở cửa                        |
| `high`   | `double`  | Giá cao nhất                      |
| `low`    | `double`  | Giá thấp nhất                     |
| `close`  | `double`  | Giá đóng cửa                      |
| `vol`    | `double`  | Volume                            |
| `time`   | `int?`    | Timestamp **ms** (Unix epoch)     |
| `amount` | `double?` | Quote volume. Optional            |
| `change` | `double?` | Biến động giá tuyệt đối. Optional |
| `ratio`  | `double?` | % thay đổi. Optional              |

**Constructor:**

- `KLineEntity.fromCustom(...)` — truyền field thẳng.
- `KLineEntity.fromJson(json)` — parse từ Map. Fallback: nếu thiếu `time` lấy `id * 1000`.
- `.toJson()` — serialize ngược.

### 5.2 `KEntity` & các mixin

```dart
class KEntity with
    CandleEntity,    // open, high, low, close, superTrend
    VolumeEntity,    // vol, MA5Volume, MA10Volume        ★ trước MACDEntity
    KDJEntity,       // k, d, j
    RSIEntity,       // rsi
    WREntity,        // r (Williams %R)
    CCIEntity,       // cci
    OBVEntity,       // obv, obvSignal                    ★ trước MACDEntity
    TRIXEntity,      // trix, trixMa                      ★ trước MACDEntity
    MTMEntity,       // mtm, mtmMa                        ★ trước MACDEntity
    StochRSIEntity,  // stochRsiK, stochRsiD              ★ trước MACDEntity
    MACDEntity,      // dif, dea, macd  (on Vol+OBV+TRIX+MTM+StochRSI+...)
    ZigZagEntity,    // zigzag points
    AVLEntity {}     // avl (cumulative VWAP)
```

| Mixin            | Field                                                                             | Indicator dùng                 |
| ---------------- | --------------------------------------------------------------------------------- | ------------------------------ |
| `CandleEntity`   | `open/high/low/close`, `maValueList`, `emaValueList`, `sar`, `boll`, `superTrend` | MA, EMA, SAR, BOLL, SuperTrend |
| `VolumeEntity`   | `open/close/vol`, `MA5Volume`, `MA10Volume`                                       | Volume MA                      |
| `MACDEntity`     | `dea`, `dif`, `macd`                                                              | MACD                           |
| `KDJEntity`      | `k`, `d`, `j`                                                                     | KDJ                            |
| `RSIEntity`      | `rsi`                                                                             | RSI                            |
| `WREntity`       | `r` (%R)                                                                          | WR                             |
| `CCIEntity`      | `cci`                                                                             | CCI                            |
| `OBVEntity`      | `obv`, `obvSignal`                                                                | OBV                            |
| `TRIXEntity`     | `trix`, `trixMa`                                                                  | TRIX                           |
| `MTMEntity`      | `mtm`, `mtmMa`                                                                    | MTM                            |
| `StochRSIEntity` | `stochRsiK`, `stochRsiD`                                                          | StochRSI                       |
| `ZigZagEntity`   | `zigzag`                                                                          | ZigZag                         |
| `AVLEntity`      | `avl`                                                                             | AVL                            |

**Thứ tự mixin quan trọng** — `OBVEntity`/`TRIXEntity`/`MTMEntity` phải đứng trước `MACDEntity` (do `MACDEntity on ... OBVEntity, TRIXEntity, MTMEntity`).

### 5.3 `InfoWindowEntity`

```dart
class InfoWindowEntity {
  KLineEntity kLineEntity;  // nến đang được chọn
  bool isLeft;              // true: vẽ dialog bên trái
}
```

### 5.4 `DepthEntity`

```dart
class DepthEntity {
  double price;
  double vol;  // phải là cumulative volume
}
```

### 5.5 Mixin type system — generic indicator

Khi dùng `List<SecondaryIndicator<MACDEntity, dynamic>>`, indicator mới cần entity riêng → thêm entity vào `on` clause của `MACDEntity` và đặt trước `MACDEntity` trong `KEntity`:

```dart
// Quy tắc khi thêm entity mới
// 1. Tạo <Name>Entity mixin đơn giản (không có `on`)
// 2. Thêm <Name>Entity vào `on` clause của MACDEntity
// 3. Đặt <Name>Entity TRƯỚC MACDEntity trong KEntity
// 4. Dùng MACDEntity làm T trong <Name>Indicator
```

---

## 6. `KChartWidget` — API đầy đủ

File: `lib/k_chart_widget.dart`.

### 6.1 Required

| Param           | Kiểu                           | Ý nghĩa                               |
| --------------- | ------------------------------ | ------------------------------------- |
| `datas`         | `List<KLineEntity>?`           | Data nguồn. Empty/null = chart trống. |
| `chartStyle`    | `KChartStyle`                  | Kích thước, padding, line width.      |
| `chartColors`   | `KChartColors`                 | Toàn bộ màu.                          |
| `detailBuilder` | `Widget Function(KLineEntity)` | Builder cho info dialog (long-press). |
| `isTrendLine`   | `bool`                         | Bật mode vẽ trend line.               |

### 6.2 Indicators & display

| Param                   | Default                   | Ý nghĩa                                               |
| ----------------------- | ------------------------- | ----------------------------------------------------- |
| `mainIndicators`        | `[]`                      | List `MainIndicator` overlay trên main chart.         |
| `secondaryIndicators`   | `[]`                      | List `SecondaryIndicator` thành panel riêng bên dưới. |
| `volHidden`             | `false`                   | Ẩn panel volume.                                      |
| `isLine`                | `false`                   | `true` = line chart, `false` = candlestick.           |
| `hideGrid`              | `false`                   | Ẩn lưới ngang/dọc.                                    |
| `showNowPrice`          | `true`                    | Vẽ đường giá hiện tại.                                |
| `showInfoDialog`        | `true`                    | Cho phép hiện dialog detail.                          |
| `isTapShowInfoDialog`   | `false`                   | `true` = single tap hiện crosshair + dialog.          |
| `materialInfoDialog`    | `true`                    | Style dialog Material vs Cupertino.                   |
| `timeFormat`            | `TimeFormat.yearMonthDay` | Format thời gian dưới X axis.                         |
| `livePrice`             | `null`                    | Giá realtime override cho now price.                  |
| `xFrontPadding`         | `100`                     | Padding phải sau nến cuối (px tại chart ≥375px).      |
| `verticalTextAlignment` | `right`                   | `left` / `right` — vị trí label giá dọc.              |
| `fixedLength`           | `2`                       | Số chữ số thập phân format giá.                       |

### 6.3 Pan / zoom / scroll

| Param              | Default             | Ý nghĩa                              |
| ------------------ | ------------------- | ------------------------------------ |
| `minScale`         | `0.5`               | Min cho `mScaleX`.                   |
| `maxScale`         | `2.2`               | Max cho `mScaleX`.                   |
| `flingTime`        | `600`               | ms — duration fling animation.       |
| `flingRatio`       | `0.5`               | Hệ số nhân vận tốc fling.            |
| `flingCurve`       | `Curves.decelerate` | Curve animation fling.               |
| `mBaseHeight`      | `360`               | Height (px) của main chart panel.    |
| `mSecondaryHeight` | `mBaseHeight * 0.2` | Height (px) của mỗi secondary panel. |

### 6.4 Load more / callback

| Param                  | Kiểu                          | Ý nghĩa                                                                                                                                                                 |
| ---------------------- | ----------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `onLoadMore`           | `void Function(bool isLeft)?` | Trigger khi scroll gần biên **hoặc** khi data chưa lấp đầy chart (xem [13.9](#139-auto-load-khi-data-chưa-lấp-đầy-chart-không-cần-gesture)). `true` = load data cũ hơn. |
| `isLoadingMore`        | `bool`                        | Cờ khoá tránh duplicate request.                                                                                                                                        |
| `isOnDrag`             | `void Function(bool)?`        | Callback start/stop drag.                                                                                                                                               |
| `controller`           | `KChartController?`           | Điều khiển từ ngoài.                                                                                                                                                    |
| `onChartScaleChanged`  | `OnChartScaleChanged?`        | Emit sau mỗi lần kết thúc pinch/scaleY/zoom/reset.                                                                                                                      |
| `onVerticalOverscroll` | `ValueChanged<double>?`       | Fire khi pan Y vượt clamp 50%.                                                                                                                                          |

**Lưu ý:** `onLoadMore` không chỉ trigger từ gesture (pan/pinch/fling) mà còn tự bắn từ `initState`/`didUpdateWidget` nếu data hiện tại chưa đủ lấp đầy chiều rộng chart — không cần user tương tác gì (fix 1.0.1).

### 6.5 Zoom state

| Param        | Kiểu                | Ý nghĩa                                                 |
| ------------ | ------------------- | ------------------------------------------------------- |
| `chartScale` | `KChartScaleState?` | Scale đã lưu — truyền lại khi đổi timeframe để restore. |

### 6.6 Background watermark

| Param                   | Default | Ý nghĩa                                                      |
| ----------------------- | ------- | ------------------------------------------------------------ |
| `backgroundLogo`        | `null`  | Widget overlay ở giữa main chart. Có `IgnorePointer` nội bộ. |
| `backgroundLogoOpacity` | `1.0`   | 0.0 ẩn — 1.0 hiện đầy đủ.                                    |

### 6.7 `TimeFormat` constants

```dart
TimeFormat.yearMonthDay         // yyyy-MM-dd
TimeFormat.yearMonthDayWithHour // yyyy-MM-dd HH:mm
```

---

## 7. `KChartController`

File: `lib/renderer/k_chart_controller.dart`. Là `ChangeNotifier`.

| Method                 | Effect                                                                                       |
| ---------------------- | -------------------------------------------------------------------------------------------- |
| `controller.zoomIn()`  | `mScaleX += 0.1`, clamp `[minScale, maxScale]`.                                              |
| `controller.zoomOut()` | `mScaleX -= 0.1`.                                                                            |
| `controller.reset()`   | `mScaleX = 1.0`, `mScrollX = 0.0`, `mSelectX = 0.0`. **Không reset `mScaleY` / `mOffsetY`**. |

**Lifecycle:**

```dart
final ctrl = KChartController();
@override
void dispose() { ctrl.dispose(); super.dispose(); }
```

---

## 8. `KChartStyle` & `KChartColors`

### 8.1 `KChartStyle`

| Field               | Default | Ý nghĩa                                         |
| ------------------- | ------- | ----------------------------------------------- |
| `topPadding`        | `20.0`  | Padding trên main chart.                        |
| `bottomPadding`     | `16.0`  | Chiều cao vùng date axis.                       |
| `childPadding`      | `12.0`  | Padding giữa các panel.                         |
| `space`             | `4.0`   | Khoảng cách trong label.                        |
| `pointWidth`        | `11.0`  | Khoảng cách tâm-tâm giữa 2 nến.                 |
| `candleWidth`       | `8.5`   | Bề rộng thân nến.                               |
| `candleLineWidth`   | `1.0`   | Bề rộng wick.                                   |
| `volWidth`          | `8.5`   | Bề rộng cột volume.                             |
| `crossWidth`        | `0.8`   | Bề rộng đường crosshair.                        |
| `nowPriceLineWidth` | `0.8`   | Bề rộng đường giá hiện tại.                     |
| `borderWidth`       | `0.5`   | Border cho crosshair label & now-price label.   |
| `gridRows`          | `4`     | Số dòng grid ngang.                             |
| `gridColumns`       | `6`     | Số cột grid dọc.                                |
| `dateTimeFormat`    | `null`  | Custom format thời gian (override auto-detect). |
| `volBarOpacity`     | `1.0`   | Độ trong suốt cột volume (0.0–1.0).             |

Constructor: `const KChartStyle([List<String>? dateTimeFormat, double volBarOpacity = 1.0])`.

### 8.2 `KChartColors`

| Field                                 | Default       | Vùng dùng                               |
| ------------------------------------- | ------------- | --------------------------------------- |
| `bgColor`                             | `0xFFFFFFFF`  | Background toàn chart.                  |
| `kLineColor`                          | `0xFF217AFF`  | Line chart.                             |
| `kLineFillColors`                     | gradient blue | Fill bên dưới line.                     |
| `ma5Color`, `ma10Color`               | vàng / xanh   | MA (override qua `MAStyle.maColors`).   |
| `upColor`                             | `0xFF14AD8F`  | Nến tăng.                               |
| `dnColor`                             | `0xFFD5405D`  | Nến giảm.                               |
| `volColor`                            | `0xFF2F8FD5`  | Cột volume.                             |
| `volUpColor` / `volDnColor`           | xanh / đỏ     | Cột volume theo trend.                  |
| `defaultTextColor`                    | xám           | Text mặc định (axis, label indicator).  |
| `nowPriceUpColor` / `nowPriceDnColor` | xanh / đỏ     | Đường + label giá hiện tại.             |
| `trendLineColor`                      | cam           | Trend line.                             |
| `selectBorderColor`                   | đen           | Border của crosshair label box.         |
| `selectFillColor`                     | trắng         | Fill của crosshair label box.           |
| `gridColor`                           | xám nhạt      | Đường grid.                             |
| `crossColor`                          | đen           | Crosshair lines.                        |
| `crossTextColor`                      | đen           | Text trong crosshair label.             |
| `maxColor` / `minColor`               | đen           | Label giá max/min trong khung hiển thị. |

**Dark mode example:**

```dart
const KChartColors(
  bgColor: Color(0xFF1C1C1E),
  defaultTextColor: Color(0xFF8E8E93),
  gridColor: Color(0xFF2C2C2E),
  selectFillColor: Color(0xFF2C2C2E),
  selectBorderColor: Color(0xFF636366),
  crossColor: Color(0xFFEBEBF5),
  crossTextColor: Color(0xFFEBEBF5),
  maxColor: Color(0xFFEBEBF5),
  minColor: Color(0xFFEBEBF5),
)
```

---

## 9. Indicators — main & secondary

### 9.1 Hierarchy

```
IndicatorTemplate<T, K>   ← abstract
├── MainIndicator<T, K>     ← overlay trên main chart
│   ├── MAIndicator
│   ├── BOLLIndicator
│   ├── EMAIndicator
│   ├── SARIndicator
│   ├── ZigZagIndicator
│   ├── SuperTrendIndicator
│   └── AVLIndicator
└── SecondaryIndicator<T, K> ← panel riêng bên dưới
    ├── MACDIndicator
    ├── KDJIndicator
    ├── RSIIndicator
    ├── WRIndicator
    ├── CCIIndicator
    ├── OBVIndicator
    ├── TRIXIndicator
    ├── MTMIndicator
    └── StochRSIIndicator
```

### 9.2 Built-in indicators

#### MA — main

- **Style:** `MAStyle({ List<Color> maColors })`
- **calcParams:** `[5,10,30,60]`
- **Output:** `entity.maValueList[i]`

#### BOLL — main

- **Style:** `BOLLStyle({ bollColor, ubColor, lbColor, fillColor })`
- **calcParams:** `[20, 2]` — (period, std multiplier)
- **Output:** `entity.boll = Boll { up, mid, dn, bollMa }`

#### EMA — main

- **Style:** `MAStyle`
- **calcParams:** `[5, 10, 20]`
- **Output:** `entity.emaValueList[i]`

#### SAR — main

- **Style:** `SARStyle({ sarColor, radius, strokeWidth })`
- **Output:** `entity.sar = double?`

#### ZigZag — main

- **Style:** `ZigZagStyle({ zigzagColor, lineWidth })`
- **calcParams:** `[5]` (deviation %)
- **Output:** `entity.zigzag = double?` chỉ ở pivot

#### SuperTrend — main

- **Style:** `SuperTrendStyle({ upColor, dnColor, upFillColor, dnFillColor, lineWidth })`
- **calcParams:** `[10, 30]` — (ATR period, ATR multiplier ÷10 → factor 3.0)
- **Output:** `entity.superTrend = SuperTrend { value, isUp }` (class định nghĩa trong `super_trend_indicator.dart`, field nằm ở `CandleEntity` — KHÔNG cần entity mixin riêng vì là main indicator)
- **Vẽ:** đường band đổi màu theo `isUp` (xanh khi uptrend — band dưới giá, đỏ khi downtrend — band trên giá) + fill mờ giữa band và giá. Label `SUPER: x` cũng đổi màu theo trend.
- **Công thức:**
  ```
  ATR = RMA(TR, N)                   // TR = max(h-l, |h-prevC|, |l-prevC|)
                                     // seed = SMA(TR,N), sau đó Wilder: atr = (atr×(N-1)+tr)/N
  upperBand = (h+l)/2 + factor×ATR
  lowerBand = (h+l)/2 - factor×ATR
  trend flip khi close cắt qua band hiện tại
  ```

#### AVL — main

- **Style:** `AVLStyle({ avlColor, lineWidth })`
- **calcParams:** `[]` — không có param chu kỳ
- **Output:** `entity.avl` (mixin `AVLEntity` — theo pattern ZigZag: mixin đứng sau `MACDEntity` trong `KEntity`, indicator cast `entity as AVLEntity` vì main indicator dùng `CandleEntity` làm T)
- **Vẽ:** đường line màu tím đi **xuyên qua thân từng nến** (kiểu AVL trên app Binance) — mỗi điểm là giá khớp lệnh trung bình của chính nến đó, nên luôn nằm trong range high–low.
- **Công thức:**
  ```
  AVL = AMOUNT / VOL                   // quote volume ÷ base volume của nến
  fallback (amount null/0 hoặc vol=0):
  AVL = (HIGH + LOW + CLOSE) / 3       // typical price
  ```
- **Lưu ý:** cần API trả `amount` (quote volume) trong `KLineEntity` để có giá trị thực; thiếu thì fallback typical price — đường vẫn bám nến nhưng không phản ánh volume-weighting thực. Các biến thể từng thử và bỏ: cumulative VWAP (đường trôi xa khỏi cụm nến khi giá chạy dài, kéo giãn trục Y vì `getMaxMinValue` phải bao giá trị AVL) và rolling VWAP N nến (mượt hơn nhưng vẫn lệch khỏi nến, không giống Binance).

#### MACD — secondary

- **Style:** `MACDStyle({ upColor, dnColor, macdColor, difColor, deaColor, macdWidth })`
- **calcParams:** `[12, 26, 9]`
- **Output:** `entity.dif`, `entity.dea`, `entity.macd = (dif-dea)*2`

#### KDJ — secondary

- **Style:** `KDJStyle({ kColor, dColor, jColor })`
- **calcParams:** `[9, 3, 3]`
- **Output:** `k`, `d`, `j` ∈ [0, 100]

#### RSI — secondary

- **Style:** `RSIStyle({ rsiColor })`
- **calcParams:** `[14]`
- **Output:** `rsi` ∈ [0, 100]

#### WR — secondary

- **Style:** `WRStyle({ wrColor })`
- **calcParams:** `[14]`
- **Output:** `r` ∈ [-100, 0]

#### CCI — secondary

- **Style:** `CCIStyle({ cciColor })`
- **calcParams:** `[14]`
- **Output:** `cci`

#### OBV — secondary

- **Style:** `OBVStyle({ obvColor, signalColor })`
- **calcParams:** `[5]` — period cho signal MA
- **Output:** `obv` (cumulative), `obvSignal` (MA của OBV)
- **Công thức:**
  ```
  obv[0] = vol[0]
  obv[i] = obv[i-1] + vol[i]   // nến tăng
  obv[i] = obv[i-1] - vol[i]   // nến giảm
  signal = SMA(obv, 5)
  ```

#### TRIX — secondary

- **Style:** `TRIXStyle({ trixColor, trixMaColor })`
- **calcParams:** `[12, 20]` — (N: chu kỳ triple EMA, M: chu kỳ MA signal)
- **Output:** `entity.trix`, `entity.trixMa` (mixin `TRIXEntity`)
- **Công thức:**
  ```
  EMA1 = EMA(CLOSE, N)
  EMA2 = EMA(EMA1, N)
  EMA3 = EMA(EMA2, N)
  TRIX   = (EMA3 - REF(EMA3,1)) / REF(EMA3,1) × 100
  MATRIX = MA(TRIX, M)
  ```
- **Lưu ý:** `trix` null ở nến đầu tiên (chưa có `prevEma3`); `trixMa` null cho tới khi đủ M giá trị TRIX. EMA seed bằng `close` của nến đầu. MA signal dùng sliding-window sum O(n).

#### MTM — secondary

- **Style:** `MTMStyle({ mtmColor, mtmMaColor })`
- **calcParams:** `[12, 6]` — (N: chu kỳ momentum, M: chu kỳ MA signal)
- **Output:** `entity.mtm`, `entity.mtmMa` (mixin `MTMEntity`)
- **Công thức:**
  ```
  MTM   = CLOSE - REF(CLOSE, N)    // biến thể tuyệt đối (classic)
  MTMMA = MA(MTM, M)
  ```
- **Lưu ý:** `mtm` null khi `i < N` (chưa đủ N nến trước); `mtmMa` null cho tới khi đủ M giá trị MTM. Giá trị MTM có scale phụ thuộc giá tuyệt đối của symbol (BTC sẽ ra hàng trăm/nghìn) — nếu cần scale % thì đổi công thức sang `(CLOSE - REF)/REF × 100` (ROC-style), chỉ 1 dòng trong `calc()`.

#### StochRSI — secondary

- **Style:** `StochRSIStyle({ kColor, dColor })`
- **calcParams:** `[14, 14, 3, 3]` — (N1: RSI length, N2: Stoch length, M1: smooth %K, M2: smooth %D) — chuẩn Binance/TradingView
- **Output:** `entity.stochRsiK`, `entity.stochRsiD` (mixin `StochRSIEntity`), dao động 0–100 (quá mua >80, quá bán <20)
- **Công thức:**
  ```
  RSI      = RSI(CLOSE, N1)          // Wilder smoothing, tính NỘI BỘ
  StochRSI = (RSI - MIN(RSI,N2)) / (MAX(RSI,N2) - MIN(RSI,N2)) × 100
  %K       = SMA(StochRSI, M1)
  %D       = SMA(%K, M2)
  ```
- **Lưu ý:**
  - RSI được tính **nội bộ trong `calc()`**, KHÔNG dùng lại `entity.rsi` — vì `RSIIndicator` có thể không được bật (calc chỉ chạy cho indicator trong list) và period có thể khác nhau.
  - Null-chain: RSI cần N1+1 nến → stoch cần đủ N2 giá trị RSI → %K cần M1 → %D cần M2. Với params mặc định, %K có từ nến ~30, %D từ nến ~32.
  - Edge case `MAX == MIN` (RSI đi ngang tuyệt đối trong N2 nến): StochRSI = 0 theo convention TradingView.
  - StochRSI nhạy hơn RSI nhiều — thường xuyên chạm 0/100 là hành vi đúng, không phải bug.
  - **Đường tham chiếu 20/80** (quá bán/quá mua, kiểu Binance): khai báo qua `referenceValues => [20, 80]`; `getMaxMinValue` ép range bao luôn `[20, 80]` để 2 vạch không bao giờ nằm ngoài panel. Cơ chế vẽ: `SecondaryRenderer.drawReferenceLines()` — nét đứt 4px-4px, màu `defaultTextColor` alpha 90, vẽ ở screen space TRƯỚC translate/scale trong `ChartPainter.drawChart()` (nên không giãn theo scaleX, nằm sau đường K/D, và vẫn hiện khi `hideGrid = true`). Indicator phụ khác muốn có vạch tham chiếu chỉ cần override `referenceValues`.

### 9.3 Custom indicator

```dart
class MyIndicator extends MainIndicator<CandleEntity, MyStyle> {
  MyIndicator() : super(
    name: 'myThing', shortName: 'MY',
    calcParams: [10], indicatorStyle: const MyStyle(),
  );

  @override
  void calc(List<KLineEntity> data) { /* populate field */ }

  @override
  (double, double) getMaxMinValue(KLineEntity e, double minV, double maxV) { ... }

  @override
  void drawChart(lastPoint, curPoint, lastX, curX, getY, canvas, colors) { ... }

  @override
  TextSpan? drawFigure(CandleEntity e, int precision, KChartColors c) { ... }
}
```

### 9.4 Pattern thêm secondary indicator mới

```
1. Tạo lib/entity/<name>_entity.dart
2. Thêm vào lib/entity/macd_entity.dart (on clause)
3. Thêm vào lib/entity/k_entity.dart (TRƯỚC MACDEntity)
4. Export trong lib/entity/index.dart
5. Thêm <Name>Style vào lib/indicator/indicator_style.dart
6. Tạo lib/indicator/secondary/<name>_indicator.dart
7. Thêm part vào indicator_template.dart
8. Thêm button + case vào example/main.dart
```

---

## 10. `DataUtil` & helpers

### 10.1 `DataUtil`

| Method                                          | Effect                                                                      |
| ----------------------------------------------- | --------------------------------------------------------------------------- |
| `calculateAll(data, mains, secondaries)`        | Gọi `calcVolumeMA` + tính tất cả indicator. Phải gọi mỗi khi data thay đổi. |
| `calculateIndicators(data, mains, secondaries)` | Chỉ tính indicator, bỏ qua volume MA.                                       |
| `calculateIndicator(data, indicator)`           | Tính 1 indicator riêng.                                                     |
| `calcVolumeMA(data)`                            | Tính `MA5Volume` & `MA10Volume`.                                            |

**Quan trọng:** Khi load thêm data cũ (left), phải merge list rồi gọi `calculateAll` LẠI trên list mới — indicator phụ thuộc vào toàn bộ historical data.

### 10.2 `NumberUtil`

| Method                                     | Ví dụ                                |
| ------------------------------------------ | ------------------------------------ |
| `NumberUtil.format(value, precision)`      | Format tự động (loại trailing zero). |
| `NumberUtil.formatFixed(value, precision)` | Fix precision (giữ trailing zero).   |

### 10.3 Date format

`dateFormat(DateTime, List<String> tokens)` — tokens trong `date_format_util.dart`:

| Token              | Output                |
| ------------------ | --------------------- |
| `yyyy` `yy`        | Năm 4/2 chữ số        |
| `mm`               | Tháng (padded)        |
| `dd` `d`           | Ngày (padded/compact) |
| `hour24Padded` `H` | Giờ 24h               |
| `nn` `n`           | Phút                  |
| `ss` `s`           | Giây                  |

**Cache label ngày (`ChartPainter.getDate`):** kết quả `dateFormat()` được cache trong `static Map<int, String> _dateStringCache` (key = timestamp) để tránh format lại mỗi frame. Cache bị clear khi `mFormats` đổi — so sánh **theo nội dung** (`_formatsEqual`, so từng phần tử), KHÔNG theo reference, vì `initFormats()` gán 1 list literal mới mỗi lần `ChartPainter` được dựng lại (mỗi build) dù nội dung format không đổi; so theo reference sẽ khiến cache bị xoá gần như mỗi frame và mất tác dụng.

### 10.4 Auto-detect time format & grid alignment

`initFormats()` trong `BaseChartPainter` tự chọn format **và** override `mGridColumns` dựa vào khoảng cách giữa 2 candle đầu:

| Khoảng cách          | Format        | `mGridColumns`           | Số mốc |
| -------------------- | ------------- | ------------------------ | ------ |
| ≥ 28 ngày (monthly)  | `yy-MM`       | 4                        | 5      |
| ≥ 1 ngày (daily)     | `yy-MM-dd`    | 4                        | 5      |
| Intraday (phút/giờ)  | `MM-dd HH:mm` | 3                        | 4      |
| < 2 items (fallback) | `MM-dd HH:mm` | — (giữ từ `KChartStyle`) | —      |

**Grid-time alignment:** `drawDate()` vẽ label tại đúng vị trí `columnSpace * i` (`i = 0..mGridColumns`) — trùng khớp với vị trí `drawGrid()` vẽ đường dọc. Mỗi đường grid dọc ứng đúng 1 time label bên dưới.

> `mGridColumns` được `initFormats()` override, thắng giá trị `gridColumns = 6` mặc định trong `KChartStyle`. `KChartStyle.gridColumns` chỉ có tác dụng khi `datas < 2` hoặc khi truyền `dateTimeFormat` custom (không qua auto-detect).

---

## 11. `DepthChart` — orderbook depth

File: `lib/depth_chart.dart`. Widget độc lập với `KChartWidget`.

### Constructor

```dart
DepthChart(
  bids,                              // List<DepthEntity>
  asks,                              // List<DepthEntity>
  chartColors, {                     // DepthChartColors
  baseUnit = 2,
  quoteUnit = 6,
  offset = const Offset(8, 0),
  chartTranslations = const DepthChartTranslations(),
  chartStyle = const DepthChartStyle(),
  backgroundLogo,
  backgroundLogoOpacity = 1,
  bottomLabelCount = 5,              // số mốc giá ở trục dưới (>=2)
})
```

**`bottomLabelCount`:** Nội suy tuyến tính từng đoạn:

- `[bids.first.price..centerPrice]` nửa trái
- `[centerPrice..asks.last.price]` nửa phải
- `centerPrice = (bids.last.price + asks.first.price) / 2`

### `DepthChartStyle`

| Field         | Default |
| ------------- | ------- |
| `lineWidth`   | `1.0`   |
| `radius`      | `4.0`   |
| `strokeWidth` | `0.6`   |
| `space`       | `2.0`   |
| `padding`     | `6.0`   |
| `dotRadius`   | `5.0`   |
| `crossWidth`  | `0.5`   |

### `DepthChartColors`

- `upColor` / `upFillPathColor` — bid (xanh + fill mờ).
- `dnColor` / `dnFillPathColor` — ask (đỏ + fill mờ).
- `defaultTextColor`, `annotationColor`, `crossColor`, `barrierColor`, `selectBorderColor`, `selectFillColor`.

---

## 12. Renderer internals

### Layout dọc

```
┌───────────────────────────────────────────┐
│  mTopPadding (chartStyle.topPadding + N×12) │ ← N main indicators
├───────────────────────────────────────────┤
│              mMainRect                    │ candles + main indicators
├───────────────────────────────────────────┤
│  mVolRect   (mVolumeHeight)               │ vol panel (null nếu volHidden)
├───────────────────────────────────────────┤
│  mSecondaryRectList[0]                    │ MACD
├───────────────────────────────────────────┤
│  mSecondaryRectList[1]                    │ RSI
├───────────────────────────────────────────┤
│  mDateRect  (chartStyle.bottomPadding)    │ trục thời gian (đáy cùng)
└───────────────────────────────────────────┘
```

### Tọa độ X

```dart
getX(index)         = index * mPointWidth + mPointWidth / 2
xToTranslateX(x)    = -mTranslateX + x / scaleX
indexOfTranslateX() = binary search trên getX(i)
translateXtoX(tx)   = (tx + mTranslateX) * scaleX
```

### Tọa độ Y

```dart
// BaseChartRenderer
scaleY = chartRect.height / (maxValue - minValue)
getY(v) = (maxValue - v) * scaleY + chartRect.top

// Screen Y thực sự (sau canvas transform scaleY + offsetY):
double _applyScaleY(double rawY) {
  final centerY = (mMainRect.top + mMainRect.bottom) / 2;
  return (centerY + (rawY - centerY) * scaleY + offsetY)
      .clamp(mMainRect.top, mMainRect.bottom);
}
```

### Padding phải tỷ lệ

```dart
static const double referenceChartWidth = 375.0;

static double effectiveRightPaddingPx(double xFrontPadding, double chartWidth) {
  if (chartWidth <= 0) return xFrontPadding;
  final ratio = chartWidth / referenceChartWidth;
  return xFrontPadding * (ratio < 1.0 ? ratio : 1.0);
}

double getMinTranslateX() {
  final paddingData = effectiveRightPaddingPx(xFrontPadding, mWidth) / scaleX;
  var x = -mDataLen + mWidth / scaleX - mPointWidth / 2 - paddingData;
  return x >= 0 ? 0.0 : x;
}
```

| `mWidth` (xFrontPadding=100) | Padding màn hình |
| ---------------------------- | ---------------- |
| ≥ 375px                      | 100px            |
| 250px                        | ~67px            |
| 187px                        | ~50px            |

### `KChartScaleState`

```dart
class KChartScaleState {
  final double scaleX;   // zoom ngang
  final double scaleY;   // zoom dọc main
  final double scrollX;  // offset scroll (0 = nến mới nhất)

  const KChartScaleState({
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.scrollX = 0.0,
  });

  KChartScaleState clampedTo({required double minScale, required double maxScale});
  KChartScaleState copyWith({double? scaleX, double? scaleY, double? scrollX});
}
```

### Luồng vẽ mỗi frame

```
paint()
├── initRect()
├── calculateValue()
├── initChartRenderer()
├── drawBg()
├── drawGrid()
├── drawChart()
│   ├── canvas transform (scaleX, translateX)
│   ├── canvas transform (scaleY, offsetY) → clip mMainRect
│   │   ├── MainRenderer.drawChart()
│   │   └── VolRenderer.drawChart()    ← ngoài scaleY scope
│   └── SecondaryRenderer.drawChart()  ← ngoài scaleY scope
├── drawVerticalText()
├── drawDate()
├── drawText()          ← dùng getItem(mStopIndex) không phải datas!.last
├── drawMaxAndMin()
└── drawNowPrice()      ← dùng livePrice nếu có, fallback datas!.last.close
```

### shouldRepaint — logic kiểm soát khi nào vẽ lại

`ChartPainter` được tạo mới mỗi lần `build()` nhưng `paint()` chỉ chạy khi `shouldRepaint` trả `true`.

**`BaseChartPainter.shouldRepaint`** so sánh:

```
datas, scaleX, scaleY, scrollX, isLongPress, selectX, isOnTap, offsetY, volHidden, isLine, mainIndicators, secondaryIndicators
```

**`ChartPainter.shouldRepaint`** (override) bổ sung:

```
livePrice     ← bắt buộc vì livePrice nằm trong ChartPainter, không phải BaseChartPainter
isTrendLine
selectY
lines         ← so sánh THEO GIÁ TRỊ (_trendLinesEqual), KHÔNG theo reference
```

**Quy tắc:** nếu thêm field mới vào `ChartPainter`/`BaseChartPainter` mà ảnh hưởng visual → phải thêm vào `shouldRepaint`, nếu không chart sẽ không cập nhật (đã xảy ra thật với `isLine`, `isTrendLine`/`selectY`/`lines` — xem changelog).

**Bẫy `!=` trên field bị mutate in-place:** `lines` (`List<TrendLine>`) bị `KChartWidget` sửa in-place (`lines.add(...)`, `lines.removeLast()`) rồi truyền cùng reference vào `ChartPainter` mỗi build → `oldDelegate.lines` và `lines` LUÔN là cùng 1 object, so sánh `!=` không bao giờ đúng dù nội dung đã đổi. Cách sửa đúng — áp dụng cùng nguyên tắc với `datas`/`livePrice`:

1. Widget truyền **snapshot mới** mỗi build: `lines: List<TrendLine>.of(lines)`.
2. `shouldRepaint` so sánh **theo giá trị** từng phần tử (`p1`, `p2`, `maxHeight`, `scale`), vì `TrendLine` không override `==`.

### livePrice — cập nhật giá real-time

`livePrice: double?` là prop riêng biệt với `datas`. Dùng để cập nhật đường giá hiện tại (`drawNowPrice`) theo WebSocket tick mà **không cần tạo hoặc thay thế list `datas`**.

```dart
// chart_painter.dart — drawNowPrice()
final double value = livePrice ?? datas!.last.close;
// → màu đường so theo value vs datas!.last.open
```

**Pattern đúng:**

```dart
// ✓ datas chỉ thay đổi khi nến đóng; livePrice thay đổi mỗi tick
KChartWidget(
  datas: _closedCandles,
  livePrice: _currentPrice,
  ...
)
```

**Anti-pattern — sửa candle in-place:**

```dart
// ❌ datas cùng reference → shouldRepaint trả false → chart không update
_datas.last.close = newPrice;
setState(() {});

// ✓ nếu muốn update datas: tạo list mới
setState(() => _datas = [..._datas.sublist(0, _datas.length - 1), updatedCandle]);
```

**Throttle khi tick tần suất cao (>10/giây):**

```dart
// Chỉ setState tối đa 60fps; cập nhật _currentPrice mọi lúc
_currentPrice = newPrice;
if (_lastRender == null || now - _lastRender! > 16) {
  setState(() {});
  _lastRender = now;
}
```

---

## 13. Gesture model

### 13.1 Single tap

- Trong main rect: toggle crosshair.
- `isTrendLine: true`: tap = record điểm cho trend line.

### 13.2 Long press

- Hiện crosshair + drag để di chuyển.
- Phát `InfoWindowEntity` qua stream → `detailBuilder` render dialog.

### 13.3 Scale

`onScaleStart` chốt 2 cờ:

- `_isScaleYGesture`: 1 ngón + drag dọc trong vùng phải (`effectiveRightPaddingPx`) → scaleY.
- `_gestureInMain`: `painter.isInMainRect(localFocalPoint)`. Nếu **false** (vol/secondary/date), chỉ scroll X, forward dy cho outer scroll.

`onScaleUpdate` — 4 nhánh khi `_gestureInMain == true`:

| Điều kiện                         | Hành vi                                                            |
| --------------------------------- | ------------------------------------------------------------------ |
| `_dragStartedInTapMode` && 1 ngón | Di chuyển crosshair.                                               |
| `_isScaleYGesture` && 1 ngón      | `mScaleY -= delta * 0.005`, clamp `[0.3, 5.0]`.                    |
| `details.scale != 1.0` (≥2 ngón)  | `mScaleX = lastScale * scale`, clamp.                              |
| 1 ngón drag tự do                 | `mScrollX += dx / mScaleX`. Pan Y chỉ active khi `mScaleY != 1.0`. |

**Gesture gate vol/secondary:**

```
Finger chạm vol/secondary + 1 ngón:
  dx → scrollX nến (như main)
  dy → forward onVerticalOverscroll (KHÔNG pan chart Y)
Pinch ≥2 ngón: scaleX bình thường
```

### 13.4 Clamp `mOffsetY`

```dart
double _clampOffsetY(double v) {
  final maxOffset = mBaseHeight * mScaleY / 2;
  return v.clamp(-maxOffset, maxOffset);
}
```

### 13.5 Overscroll handoff

```dart
// Trong KChartWidget — detect overscroll
if (mScaleY != 1.0) {
  final newOffsetY = mOffsetY + dy;
  final clampedOffsetY = _clampOffsetY(newOffsetY);
  mOffsetY = clampedOffsetY;
  final overscroll = newOffsetY - clampedOffsetY;
  if (overscroll != 0) widget.onVerticalOverscroll?.call(overscroll);
}
```

**Quy ước dấu:** `delta > 0` = finger drag DOWN (chart ở biên +max); `delta < 0` = finger drag UP.

### 13.6 Double-tap (vùng phải scaleY)

Double-tap → reset `mScaleY = 1.0`, `mOffsetY = 0.0`.

### 13.7 Fling

Sau drag end, animation Tween chạy với `flingTime` ms, `flingCurve`, `flingRatio` × velocity.

### 13.8 Auto-compensate scroll khi append nến mới

```dart
void _compensateScrollOnDataChange(KChartWidget oldWidget) {
  final diff = newData.length - oldData.length;
  if (diff <= 0) return;
  final appended = oldData.first.time == newData.first.time
      && oldData.last.time != newData.last.time;
  if (!appended) return;
  if (mScrollX <= 0.0) return;  // rightmost → auto-follow
  mScrollX += diff * widget.chartStyle.pointWidth;
}
```

### 13.9 Auto-load khi data chưa lấp đầy chart (không cần gesture)

Các trigger `onLoadMore` khác (13.7 fling, `onScaleUpdate`/`onScaleEnd`) chỉ chạy khi user thực hiện gesture. Nếu data ban đầu (hoặc sau khi load thêm vẫn) chưa đủ lấp đầy chiều rộng chart — `ChartPainter.maxScrollX <= 0` — và user chưa tương tác gì, `onLoadMore` sẽ **không bao giờ** được gọi, chart đứng im thiếu data (fix trong 1.0.1).

```dart
int? _narrowLoadRequestedForLength;

@override
void initState() {
  super.initState();
  ...
  _maybeLoadMoreForNarrowData();
}

@override
void didUpdateWidget(KChartWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  ...
  _maybeLoadMoreForNarrowData();
}

void _maybeLoadMoreForNarrowData() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (widget.isLoadingMore || widget.onLoadMore == null) return;
    final data = widget.datas;
    if (data == null || data.isEmpty) return;
    if (ChartPainter.maxScrollX > 0) return;
    if (_narrowLoadRequestedForLength == data.length) return;
    _narrowLoadRequestedForLength = data.length;
    widget.onLoadMore!(true);
  });
}
```

Điểm quan trọng:

- **`addPostFrameCallback`**: `ChartPainter.maxScrollX` chỉ đúng **sau** khi `paint()` chạy xong với data hiện tại (`base_chart_painter.dart:247`), nên phải đợi hết frame mới đọc được giá trị mới nhất.
- **`_narrowLoadRequestedForLength` (dedupe guard)**: `didUpdateWidget` fire trên **mọi** rebuild của parent, kể cả những rebuild không liên quan tới `datas` (đổi theme, đổi style...). Nếu không có guard này, mỗi rebuild trong lúc `isLoadingMore` chưa kịp được parent set `true` (thường bất đồng bộ, sau khi await API) sẽ gọi lại `onLoadMore(true)` → spam nhiều request trùng. Guard chỉ cho phép request lại khi `data.length` thực sự thay đổi so với lần request gần nhất.
- **Giới hạn đã biết**: `ChartPainter.maxScrollX` là field `static`, dùng chung cho **mọi instance** `KChartWidget` trong app. Nếu có nhiều chart cùng render trong 1 frame (multi-chart view), giá trị đọc được trong `addPostFrameCallback` có thể là của chart khác paint sau cùng trong frame đó, không phải của chính widget này. Không ảnh hưởng nếu app chỉ hiển thị 1 chart tại 1 thời điểm.

---

## 14. Recipes — công thức thường dùng

### 14.1 Live tick

```dart
void onTick(double newClose) {
  final last = data.last;
  final updated = KLineEntity.fromCustom(
    time: last.time!,
    open: last.open,
    close: newClose,
    high: max(last.high, newClose),
    low: min(last.low, newClose),
    vol: last.vol + 0.1,
    amount: 0,
  );
  final next = [...data.sublist(0, data.length - 1), updated];
  DataUtil.calculateAll(next, mains, secondaries);
  setState(() => data = next);
}
```

### 14.2 Load more khi scroll trái

```dart
KChartWidget(
  data, style, colors,
  detailBuilder: ...,
  isTrendLine: false,
  isLoadingMore: _isFetching,
  onLoadMore: (isLeft) async {
    if (!isLeft || _isFetching) return;
    setState(() => _isFetching = true);
    final older = await fetchOlderCandles(from: data.first.time!);
    final merged = [...older, ...data];
    DataUtil.calculateAll(merged, mains, secondaries);
    setState(() {
      data = merged;
      _isFetching = false;
    });
  },
)
```

### 14.3 Dark theme

```dart
KChartColors(
  bgColor: Color(0xFF1C1C1E),
  defaultTextColor: Color(0xFF8E8E93),
  gridColor: Color.fromARGB(255, 187, 187, 187),
  selectFillColor: Color(0xFF2C2C2E),
  selectBorderColor: Color(0xFF636366),
  crossColor: Color(0xFFEBEBF5),
  crossTextColor: Color(0xFFEBEBF5),
  maxColor: Color(0xFFEBEBF5),
  minColor: Color(0xFFEBEBF5),
)
```

### 14.4 Toggle nhiều secondary

```dart
List<SecondaryIndicator> get _secondary => [
  if (showMACD) MACDIndicator(),
  if (showKDJ) KDJIndicator(),
  if (showRSI) RSIIndicator(),
];
```

### 14.5 Custom date format

```dart
KChartWidget(
  data, style, colors,
  detailBuilder: ...,
  isTrendLine: false,
  timeFormat: const [dd, '/', mm, ' ', hour24Padded, ':', nn],
)
```

### 14.6 Watermark logo

```dart
KChartWidget(
  ...,
  backgroundLogo: SvgPicture.asset('assets/logo.svg', width: 80, height: 80),
  backgroundLogoOpacity: 0.15,
)
```

### 14.7 External zoom buttons

```dart
final ctrl = KChartController();
KChartWidget(..., controller: ctrl)
IconButton(onPressed: ctrl.zoomIn, icon: Icon(Icons.zoom_in))
IconButton(onPressed: ctrl.zoomOut, icon: Icon(Icons.zoom_out))
IconButton(onPressed: ctrl.reset, icon: Icon(Icons.refresh))
```

### 14.8 Lưu/khôi phục zoom state khi đổi timeframe

```dart
KChartScaleState? _savedScale;

KChartWidget(
  _data, chartStyle, chartColors,
  chartScale: _savedScale,
  onChartScaleChanged: (s) => setState(() => _savedScale = s),
  ...
)
// Khi đổi timeframe: truyền _savedScale vào instance mới → widget tự restore.
```

### 14.10 Real-time WebSocket price ticker

```dart
// State:
double? _livePrice;
List<KLineEntity> _datas = [];

// WebSocket onMessage:
void _onTick(double price) {
  _livePrice = price;
  setState(() {});  // chỉ update livePrice, không đụng _datas
}

// Khi nến đóng (push nến mới từ server):
void _onCandleClose(KLineEntity newCandle) {
  final next = [..._datas, newCandle];
  DataUtil.calculateAll(next, mains, secondaries);
  setState(() {
    _datas = next;
    _livePrice = null;  // reset để drawNowPrice tự fallback về close của nến cuối
  });
}

// Build:
KChartWidget(
  _datas,
  chartStyle, chartColors,
  livePrice: _livePrice,
  datas: _datas,
  ...
)
```

> `livePrice` thay đổi → `shouldRepaint` trả `true` → chỉ `drawNowPrice()` là thực sự cần vẽ lại.  
> `datas` reference thay đổi → full repaint (tính lại min/max, grid, toàn bộ nến).

### 14.9 Overscroll handoff sang outer scrollview

```dart
void _onChartVerticalOverscroll(double delta) {
  if (!_outerScrollController.hasClients) return;
  final pos = _outerScrollController.position;
  // Đảo dấu: chart pan dùng mOffsetY += dy (content theo finger).
  // Scroll Flutter ngược lại: pixels TĂNG = reveal content dưới.
  final target = (pos.pixels - delta).clamp(
    pos.minScrollExtent,
    pos.maxScrollExtent,
  );
  if (target != pos.pixels) {
    _outerScrollController.jumpTo(target);
  }
}

// Build:
SingleChildScrollView(
  controller: _outerScrollController,
  physics: (_scaleYActive && _pointerOnChart)
      ? const NeverScrollableScrollPhysics()
      : const ClampingScrollPhysics(),
  child: Column(children: [
    KChartWidget(..., onVerticalOverscroll: _onChartVerticalOverscroll),
    const OrderBookSection(),
  ]),
)
```

---

## 15. Troubleshooting & pitfalls

### "Indicator không hiện"

- Đã gọi `DataUtil.calculateAll(data, mains, secondaries)` chưa? Phải gọi lại MỖI khi list data thay đổi.
- Đủ data cho period chưa? VD MA30 cần ≥30 nến.

### "Sai data sau load more"

- Phải merge `[...older, ...current]` ROI `calculateAll` lại trên list merged.

### "Time hiển thị sai"

- `time` phải là **milliseconds** Unix epoch. Nếu API trả seconds, nhân 1000.

### "Crosshair label dính vào cạnh"

- Tăng `xFrontPadding` (mặc định 100px tại chart ≥375px).

### "Chart hẹp vẫn chừa khoảng trống lớn bên phải"

- Giảm `xFrontPadding` hoặc chỉnh `referenceChartWidth` trong `base_chart_painter.dart`.

### "Stream has already been listened to"

- `mInfoWindowStream` phải là `StreamController.broadcast()`.

### "Pan dọc không hoạt động"

- Pan dọc CHỈ active sau khi user đã scaleY (`mScaleY != 1.0`). Drag dọc vùng phải (`effectiveRightPaddingPx`) để zoom dọc trước.

### "Outer scroll ăn gesture chart"

- Khi nhúng trong `SingleChildScrollView`, track pointer events và toggle physics → `NeverScrollableScrollPhysics` khi finger trên chart.

### "Live price không cập nhật"

- Không sửa `datas` in-place (`_datas.last.close = x`) — cùng reference, `shouldRepaint` trả `false`.
- Dùng `livePrice` prop thay thế, hoặc tạo list mới: `_datas = [..._datas.dropLast(), updated]`.
- Nếu thêm field visual mới vào `ChartPainter`: bắt buộc thêm vào `shouldRepaint`, nếu không chart không vẽ lại khi field đó thay đổi.

### "Live tick lag"

- `DataUtil.calculateAll` chạy O(n × số indicator). Với n > 1000 nến cân nhắc tính incremental.
- Tick tần suất cao (>10/giây): throttle `setState` về 60fps thay vì gọi mỗi message.

### "Mixin order error"

- Giữ đúng thứ tự mixin trong `k_entity.dart`. `OBVEntity` PHẢI trước `MACDEntity`.

### "onLoadMore không được gọi khi zoom out nhỏ"

- Điều kiện đã mở rộng: `maxScrollX <= 0 || mScrollX >= maxScrollX * 0.8`. Post-frame callback trong `onScaleEnd` xử lý trường hợp pinch zoom out.

### "Volume panel không tách ra dưới chart"

- `BaseDimension._mVolumeHeight = 0` theo design hiện tại; volume overlay vào main rect.

### "ZigZagIndicator chỉ vẽ vài điểm"

- Bình thường — chỉ pivot mới có value. Tăng/giảm `calcParams[0]` (deviation %) để có nhiều/ít pivot.

---

---

## 16. Phân tích cơ chế Y Grid & Anchor Zoom (MEXC / TradingView)

> Tổng hợp từ phân tích kỹ thuật `anchor_zoom.md` và `scroll_vertical_y.md`. Đây là tham khảo thiết kế — k_chart_wikex hiện dùng mô hình `mScaleY + mOffsetY` (canvas transform), không phải `visibleMinPrice / visibleMaxPrice`.

### 16.1 Vertical Scroll — di chuyển khoảng giá

TradingView **không** dùng `translateY`. Thay vào đó nó quản lý hai biến:

```dart
double visibleMinPrice;
double visibleMaxPrice;
```

Khi người dùng kéo dọc:

```dart
void onVerticalDrag(double dy) {
  final deltaPrice = dy / scaleY;   // pixel → price unit
  visibleMinPrice += deltaPrice;
  visibleMaxPrice += deltaPrice;
  repaint();
}
```

`scaleY` luôn được tính lại từ price range:

```dart
double scaleY = chartHeight / (visibleMaxPrice - visibleMinPrice);
```

**Công thức render:**

```dart
// price → screen Y
screenY = chartHeight - (price - visibleMinPrice) * scaleY;

// screen Y → price (inverse)
price = visibleMinPrice + (chartHeight - y) / scaleY;
```

**So sánh với translateY đơn giản:**

|              | `translateY += dy` | TradingView approach |
| ------------ | ------------------ | -------------------- |
| Cài đặt      | Đơn giản           | Phức tạp hơn         |
| Price range  | Không rõ           | Tường minh           |
| Anchor zoom  | Khó                | Chính xác            |
| Grid đồng bộ | Dễ lệch            | Luôn đúng            |
| Auto scale   | Khó                | Dễ triển khai        |

---

### 16.2 Dynamic Y Grid

MEXC / TradingView **không** dùng grid cố định. Mục tiêu: giữ khoảng cách giữa 2 đường grid vào khoảng **50–100 px**.

**Thuật toán chọn gridStep:**

```dart
// 1. rawStep từ số line mong muốn
final targetLines = chartHeight / 80;         // ≈ số đường grid
final rawStep     = priceRange / targetLines;

// 2. Normalize về giá đẹp (1, 2, 5, 10, 20, 50, 100, ...)
double normalizeStep(double raw) {
  final exponent = pow(10, log10(raw).floor()).toDouble();
  final fraction = raw / exponent;
  if (fraction <= 1) return exponent;
  if (fraction <= 2) return 2 * exponent;
  if (fraction <= 5) return 5 * exponent;
  return 10 * exponent;
}
```

**Tính gridLine đầu tiên và render:**

```dart
final gridStep  = normalizeStep(rawStep);
final firstGrid = (visibleMin / gridStep).floor() * gridStep;

double p = firstGrid;
while (p <= visibleMax) {
  drawLine(yOfPrice(p));
  drawLabel(p);
  p += gridStep;
}
```

**Tại sao grid không nhảy:** `firstGrid` dịch chuyển liên tục theo `visibleMin`. Line đầu chỉ biến mất khi vượt hẳn qua `visibleMin`, line mới xuất hiện từ dưới — tạo cảm giác trượt mượt.

---

### 16.3 Anchor Zoom

Mục tiêu: giá tại vị trí ngón tay / con trỏ **không thay đổi** sau khi zoom.

**Thuật toán hoàn chỉnh:**

```dart
void zoomAtPoint(double mouseY, double factor) {
  // 1. Lưu giá tại điểm chạm
  final anchorPrice = visibleMinPrice + (chartHeight - mouseY) / scaleY;

  // 2. Thay đổi scale
  scaleY *= factor;

  // 3. Tính lại visible range sao cho anchorPrice vẫn tại mouseY
  visibleMinPrice = anchorPrice - (chartHeight - mouseY) / scaleY;
  visibleMaxPrice = visibleMinPrice + chartHeight / scaleY;
}
```

**Pinch zoom 2 ngón:** lấy trung điểm làm `mouseY`:

```dart
final anchorY = (finger1Y + finger2Y) / 2;
zoomAtPoint(anchorY, newScale / oldScale);
```

**Ví dụ số:**

|                      | Trước  | Sau (scaleY: 8→12) |
| -------------------- | ------ | ------------------ |
| `visibleMin`         | 100    | 122.91             |
| `visibleMax`         | 200    | 189.58             |
| Giá tại `mouseY=250` | 168.75 | 168.75 ✓           |

---

_Cập nhật: 2026-07-02 — fix 3 bug shouldRepaint/getDate-cache phát hiện qua code review (isLine, isTrendLine/selectY/lines, date-string cache identity), cập nhật section 12 & 10.3._
_Cập nhật: 2026-06-30 — thêm shouldRepaint logic, livePrice real-time pattern, recipe 14.10, pitfalls, section 16 (Y Grid & Anchor Zoom)_
