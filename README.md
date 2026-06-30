# k_chart_wikex

A Flutter candlestick chart package with support for multiple technical indicators, smooth gesture interactions, and customizable themes.

## Features

- Candlestick and line chart rendering
- **Free pan:** drag 1 ngón tay di chuyển chart theo cả X (scroll nến) lẫn Y (dịch vùng giá)
- **Zoom X:** pinch 2 ngón tay, giới hạn bởi `minScale` / `maxScale`
- **Zoom Y:** drag dọc trong vùng phải chart (width tỷ lệ `xFrontPadding`, co khi chart hẹp)
- **Double tap** vùng phải: reset zoom Y và pan Y về mặc định
- **Tap-to-toggle crosshair:** tap hiện crosshair, tap lại ẩn; kéo khi crosshair đang hiện sẽ di chuyển crosshair thay vì scroll
- **Price labels đồng bộ scaleY + offsetY:** labels trục Y luôn hiển thị đúng giá theo vị trí visual của nến
- Fling (quán tính) khi scroll, không fling khi đang kéo crosshair
- **Main indicators:** MA, EMA, BOLL, SAR, ZigZag
- **Secondary indicators:** MACD, KDJ, RSI, WR, CCI, OBV
- Volume bar chart with MA5 / MA10 overlay
- Long-press info dialog with custom `detailBuilder`
- Programmatic control via `KChartController` (zoom in/out, reset)
- Save & restore zoom state across timeframe changes via `KChartScaleState`
- Real-time price ticker via `livePrice` (no full repaint needed)
- Dark / light theme support via `KChartColors`
- Background watermark support via `backgroundLogo`
- Depth chart widget for order book visualization

---

## Installation

In your `pubspec.yaml`:

```yaml
dependencies:
  k_chart_wikex:
    git:
      url: https://github.com/MrTuyennn/k_chart_wikex.git
```

Then run:

```bash
flutter pub get
```

---

## Quick start

### 1. Import

```dart
import 'package:k_chart_wikex/k_chart_plus.dart';
```

### 2. Prepare data

```dart
List<KLineEntity> data = [
  KLineEntity.fromCustom(
    time: DateTime.now().millisecondsSinceEpoch,
    open: 65000,
    high: 65800,
    low: 64500,
    close: 65400,
    vol: 120.5,
    amount: 65400 * 120.5,
  ),
  // ...more candles
];

// Must call before rendering; call again whenever data changes
DataUtil.calculateAll(data, [MAIndicator()], [MACDIndicator()]);
```

Or from JSON:

```dart
final data = jsonList.map((e) => KLineEntity.fromJson(e)).toList();
DataUtil.calculateAll(data, [MAIndicator()], [MACDIndicator()]);
```

### 3. Render chart

```dart
KChartWidget(
  data,
  const KChartStyle(),
  const KChartColors(),
  isTrendLine: false,
  isLine: false,
  volHidden: false,
  mainIndicators: [MAIndicator()],
  secondaryIndicators: [MACDIndicator()],
  showNowPrice: true,
  showInfoDialog: true,
  mBaseHeight: 300,
  timeFormat: TimeFormat.yearMonthDayWithHour,
  onLoadMore: (isLeft) {
    // load more data when user scrolls to the edge
  },
  detailBuilder: (entity) {
    return YourInfoCard(entity: entity);
  },
)
```

---

## Indicators

### Main indicators (overlay on candles)

| Class               | Description                | Default params  |
| ------------------- | -------------------------- | --------------- |
| `MAIndicator()`     | Moving Average             | 5, 10, 30, 60   |
| `EMAIndicator()`    | Exponential Moving Average | 5, 10, 30, 60   |
| `BOLLIndicator()`   | Bollinger Bands            | 20, 2           |
| `SARIndicator()`    | Parabolic SAR              | 2, 2, 20        |
| `ZigZagIndicator()` | ZigZag                     | 12, 2, 5        |

### Secondary indicators (panel below chart)

| Class             | Description             | Default params |
| ----------------- | ----------------------- | -------------- |
| `MACDIndicator()` | MACD                    | 12, 26, 9      |
| `KDJIndicator()`  | KDJ                     | —              |
| `RSIIndicator()`  | Relative Strength Index | 6, 12, 24      |
| `WRIndicator()`   | Williams %R             | 26, 6          |
| `CCIIndicator()`  | Commodity Channel Index | 20             |
| `OBVIndicator()`  | On-Balance Volume       | 5              |

Volume hiển thị trong panel riêng giữa main chart và date axis. Toggle bằng `volHidden`.

Combine multiple indicators by passing a list:

```dart
mainIndicators: [MAIndicator(), BOLLIndicator()],
secondaryIndicators: [MACDIndicator()],
```

Always call `DataUtil.calculateAll` after changing indicators or data:

```dart
DataUtil.calculateAll(data, mainIndicators, secondaryIndicators);
```

---

## KChartWidget parameters

### Required / core

| Parameter             | Type                       | Default                    | Description                    |
| --------------------- | -------------------------- | -------------------------- | ------------------------------ |
| `datas`               | `List<KLineEntity>?`       | —                          | Candle data list               |
| `chartStyle`          | `KChartStyle`              | —                          | Style config (spacing, widths) |
| `chartColors`         | `KChartColors`             | —                          | Color config                   |
| `isTrendLine`         | `bool`                     | —                          | Enable trend line drawing      |
| `detailBuilder`       | `WidgetDetailBuilder`      | —                          | Custom info card widget        |

### Display

| Parameter             | Type                       | Default                    | Description                         |
| --------------------- | -------------------------- | -------------------------- | ----------------------------------- |
| `mainIndicators`      | `List<MainIndicator>`      | `[]`                       | Main overlay indicators             |
| `secondaryIndicators` | `List<SecondaryIndicator>` | `[]`                       | Secondary panel indicators          |
| `isLine`              | `bool`                     | `false`                    | Line chart mode                     |
| `volHidden`           | `bool`                     | `false`                    | Hide volume panel                   |
| `showNowPrice`        | `bool`                     | `true`                     | Show current price line             |
| `showInfoDialog`      | `bool`                     | `true`                     | Show info on long-press/tap         |
| `isTapShowInfoDialog` | `bool`                     | `false`                    | Single tap shows crosshair + dialog |
| `materialInfoDialog`  | `bool`                     | `true`                     | Material vs Cupertino dialog style  |
| `timeFormat`          | `List<String>`             | `TimeFormat.yearMonthDay`  | Time label format on X axis         |
| `fixedLength`         | `int`                      | `2`                        | Decimal places for price labels     |
| `verticalTextAlignment` | `VerticalTextAlignment`  | `right`                    | Price label side (`left`/`right`)   |
| `hideGrid`            | `bool`                     | `false`                    | Hide grid lines                     |

### Layout & sizing

| Parameter             | Type       | Default              | Description                        |
| --------------------- | ---------- | -------------------- | ---------------------------------- |
| `mBaseHeight`         | `double`   | `360`                | Main chart height (px)             |
| `mSecondaryHeight`    | `double?`  | 20% of `mBaseHeight` | Secondary panel height (px)        |
| `xFrontPadding`       | `double`   | `100`                | Right padding after last candle (px at ≥375px chart; scales down on narrower screens) |

### Zoom / scroll

| Parameter     | Type     | Default             | Description                          |
| ------------- | -------- | ------------------- | ------------------------------------ |
| `minScale`    | `double` | `0.5`               | Minimum zoom scale X                 |
| `maxScale`    | `double` | `2.2`               | Maximum zoom scale X                 |
| `flingTime`   | `int`    | `600`               | Fling animation duration (ms)        |
| `flingRatio`  | `double` | `0.5`               | Fling velocity multiplier            |
| `flingCurve`  | `Curve`  | `Curves.decelerate` | Fling animation curve                |
| `chartScale`  | `KChartScaleState?` | `null`   | Saved scale to restore on mount      |

### Data loading & callbacks

| Parameter              | Type                        | Description                                      |
| ---------------------- | --------------------------- | ------------------------------------------------ |
| `onLoadMore`           | `void Function(bool)?`      | Called when scrolled to edge; `true` = load left |
| `isLoadingMore`        | `bool`                      | Lock flag to prevent duplicate load requests     |
| `isOnDrag`             | `void Function(bool)?`      | Called on drag start/stop                        |
| `controller`           | `KChartController?`         | Programmatic zoom/reset control                  |
| `onChartScaleChanged`  | `OnChartScaleChanged?`      | Emitted after pinch / scaleY / zoom / reset ends |
| `onVerticalOverscroll` | `ValueChanged<double>?`     | Fired when pan Y hits clamp (for outer scroll handoff) |

### Real-time & decorative

| Parameter               | Type      | Default | Description                                    |
| ----------------------- | --------- | ------- | ---------------------------------------------- |
| `livePrice`             | `double?` | `null`  | Real-time price for now-price line             |
| `backgroundLogo`        | `Widget?` | `null`  | Watermark widget centered in main chart area   |
| `backgroundLogoOpacity` | `double`  | `1.0`   | Watermark opacity (0.0–1.0)                    |

---

## Real-time price ticker

Use `livePrice` to update the now-price line on every WebSocket tick **without rebuilding the full candle list**:

```dart
double? _livePrice;
List<KLineEntity> _datas = [];

// WebSocket tick — only update live price
void _onTick(double price) {
  setState(() => _livePrice = price);
}

// New candle closed — append to data list
void _onCandleClose(KLineEntity newCandle) {
  final next = [..._datas, newCandle];
  DataUtil.calculateAll(next, mains, secondaries);
  setState(() {
    _datas = next;
    _livePrice = null; // fallback to last candle's close
  });
}

// Build:
KChartWidget(
  _datas,
  chartStyle, chartColors,
  livePrice: _livePrice,
  ...
)
```

> `livePrice` changing triggers a targeted repaint of `drawNowPrice` only.  
> `datas` reference changing triggers a full repaint (min/max recalculation, entire chart).

**Anti-pattern — do NOT mutate datas in place:**

```dart
// ❌ same list reference → shouldRepaint returns false → no repaint
_datas.last.close = newPrice;
setState(() {});
```

**Throttle for high-frequency ticks (>10/s):**

```dart
_livePrice = newPrice;
if (_lastRender == null || now - _lastRender! > 16) {
  setState(() {});
  _lastRender = now;
}
```

---

## Save & restore zoom state

Use `KChartScaleState` to preserve zoom / scroll position when switching timeframes:

```dart
KChartScaleState? _savedScale;

KChartWidget(
  _data, chartStyle, chartColors,
  chartScale: _savedScale,
  onChartScaleChanged: (s) => setState(() => _savedScale = s),
  ...
)
// Switching timeframe: pass _savedScale into the new widget instance → auto-restored.
```

`onChartScaleChanged` fires after every pinch, scaleY drag, controller zoom, or double-tap reset.

---

## Load more (historical data)

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

> `onLoadMore` is also triggered when scaleX is small enough that all data fits the screen (`maxScrollX == 0`).

---

## Gesture interaction

| Gesture | Hành động |
|---|---|
| 1 ngón kéo ngang | Scroll qua các nến (X) |
| 1 ngón kéo dọc | Pan vùng giá lên/xuống (Y) |
| 1 ngón kéo tự do | Scroll X + pan Y đồng thời |
| Pinch 2 ngón | Zoom scaleX (thu phóng số nến hiển thị) |
| Kéo dọc vùng phải chart | Zoom scaleY (thu phóng vùng giá; width ∝ `xFrontPadding`) |
| Double tap vùng phải | Reset scaleY và offsetY về mặc định |
| Tap vào nến | Hiện crosshair + info dialog |
| Tap lại | Ẩn crosshair |
| Kéo khi crosshair đang hiện | Di chuyển crosshair theo ngón tay |
| Long press + kéo | Di chuyển crosshair |

---

## Vertical overscroll handoff

When the chart is nested inside a `SingleChildScrollView`, use `onVerticalOverscroll` to forward excess pan-Y to the outer scroll:

```dart
void _onChartVerticalOverscroll(double delta) {
  if (!_outerController.hasClients) return;
  final pos = _outerController.position;
  final target = (pos.pixels - delta).clamp(pos.minScrollExtent, pos.maxScrollExtent);
  if (target != pos.pixels) _outerController.jumpTo(target);
}

SingleChildScrollView(
  controller: _outerController,
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

## Theming

### Light theme (default)

```dart
const KChartColors()
```

### Dark theme

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

## KChartController

Use `KChartController` to control the chart programmatically:

```dart
final controller = KChartController();

// pass to widget
KChartWidget(..., controller: controller)

controller.zoomIn();   // scaleX += 0.1
controller.zoomOut();  // scaleX -= 0.1
controller.reset();    // scaleX = 1.0, scrollX = 0.0 (does NOT reset scaleY)

// dispose when done
controller.dispose();
```

---

## Custom info dialog

The `detailBuilder` callback is called on long-press or tap with the selected candle:

```dart
detailBuilder: (KLineEntity entity) {
  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade300),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Open:  ${entity.open.toStringAsFixed(2)}'),
        Text('High:  ${entity.high.toStringAsFixed(2)}'),
        Text('Low:   ${entity.low.toStringAsFixed(2)}'),
        Text('Close: ${entity.close.toStringAsFixed(2)}'),
        Text('Vol:   ${entity.vol.toStringAsFixed(2)}'),
      ],
    ),
  );
},
```

---

## Time format

Use predefined formats or build your own:

```dart
// 2024-01-15
timeFormat: TimeFormat.yearMonthDay

// 2024-01-15 08:30
timeFormat: TimeFormat.yearMonthDayWithHour

// custom
timeFormat: const [yyyy, '/', mm, '/', dd]
```

---

## Background logo (watermark)

Pass any widget as `backgroundLogo` to display it centered in the main chart area — rendered above the background color but below candles and indicators:

```dart
KChartWidget(
  data,
  chartStyle,
  chartColors,
  backgroundLogo: Builder(
    builder: (context) {
      final size = MediaQuery.sizeOf(context).width / 6;
      return SvgPicture.asset('assets/logo.svg', width: size, height: size);
    },
  ),
  backgroundLogoOpacity: 0.15,
  ...
)
```

> The logo uses `IgnorePointer` internally and does not interfere with gestures.

---

## Example

See the full working demo in the [`example/`](example/lib/main.dart) folder.

```bash
cd example
flutter pub get
flutter run
```

---

## License

Copyright (c) 2026 Wikex. All rights reserved. See [LICENSE](LICENSE).
