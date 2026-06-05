# k_chart_wikex

A Flutter candlestick chart package with support for multiple technical indicators, smooth gesture interactions, and customizable themes.

## Features

- Candlestick and line chart rendering
- **Free pan:** drag 1 ngón tay di chuyển chart theo cả X (scroll nến) lẫn Y (dịch vùng giá)
- **Zoom X:** pinch 2 ngón tay, giới hạn bởi `minScale` / `maxScale`
- **Zoom Y:** drag dọc trong vùng 100px bên phải chart
- **Double tap** vùng phải: reset zoom Y và pan Y về mặc định
- **Tap-to-toggle crosshair:** tap hiện crosshair, tap lại ẩn; kéo khi crosshair đang hiện sẽ di chuyển crosshair thay vì scroll
- **Price labels đồng bộ scaleY + offsetY:** labels trục Y luôn hiển thị đúng giá theo vị trí visual của nến
- Fling (quán tính) khi scroll, không fling khi đang kéo crosshair
- **Main indicators:** MA, EMA, BOLL, SAR, ZigZag
- **Secondary indicators:** MACD, KDJ, RSI, WR, CCI
- Volume bar chart with MA5 / MA10 overlay
- Long-press info dialog with custom `detailBuilder`
- Programmatic control via `KChartController` (zoom in/out, reset)
- Dark / light theme support via `KChartColors`
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

// Calculate volume MA and indicators before rendering
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
  timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR,
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

| Class               | Description                | Default params |
| ------------------- | -------------------------- | -------------- |
| `MAIndicator()`     | Moving Average             | 5, 10, 30, 60  |
| `EMAIndicator()`    | Exponential Moving Average | 5, 10, 30      |
| `BOLLIndicator()`   | Bollinger Bands            | 20, 2          |
| `SARIndicator()`    | Parabolic SAR              | —              |
| `ZigZagIndicator()` | ZigZag                     | —              |

### Secondary indicators (panel below chart)

| Class             | Description             | Default params |
| ----------------- | ----------------------- | -------------- |
| `MACDIndicator()` | MACD                    | 12, 26, 9      |
| `KDJIndicator()`  | KDJ                     | 9, 1, 3        |
| `RSIIndicator()`  | Relative Strength Index | 6, 12, 24      |
| `WRIndicator()`   | Williams %R             | 14             |
| `CCIIndicator()`  | Commodity Channel Index | 14             |
| `OBVIndicator()`  | On-Balance Volume       | 5              |

Volume hiển thị trong panel riêng giữa main chart và date axis. Toggle bằng `volHidden`.

Combine multiple indicators by passing a list:

```dart
mainIndicators: [MAIndicator(), BOLLIndicator()],
secondaryIndicators: [MACDIndicator()],
```

Always call `DataUtil.calculateAll` after changing indicators:

```dart
DataUtil.calculateAll(data, mainIndicators, secondaryIndicators);
```

---

## KChartWidget parameters

| Parameter             | Type                       | Default            | Description                    |
| --------------------- | -------------------------- | ------------------ | ------------------------------ |
| `datas`               | `List<KLineEntity>?`       | —                  | Candle data list               |
| `chartStyle`          | `KChartStyle`              | —                  | Style config (spacing, widths) |
| `chartColors`         | `KChartColors`             | —                  | Color config                   |
| `mainIndicators`      | `List<MainIndicator>`      | `[]`               | Main overlay indicators        |
| `secondaryIndicators` | `List<SecondaryIndicator>` | `[]`               | Secondary panel indicators     |
| `isLine`              | `bool`                     | `false`            | Line chart mode                |
| `volHidden`           | `bool`                     | `false`            | Hide volume panel              |
| `isTrendLine`         | `bool`                     | —                  | Enable trend line drawing      |
| `showNowPrice`        | `bool`                     | `true`             | Show current price line        |
| `showInfoDialog`      | `bool`                     | `true`             | Show info on long-press/tap    |
| `mBaseHeight`         | `double`                   | `360`              | Main chart height              |
| `mSecondaryHeight`    | `double?`                  | 20% of mBaseHeight | Secondary panel height         |
| `timeFormat`          | `List<String>`             | `YEAR_MONTH_DAY`   | Time label format              |
| `fixedLength`         | `int`                      | `2`                | Decimal places                 |
| `minScale`            | `double`                   | `0.5`              | Minimum zoom scale             |
| `maxScale`            | `double`                   | `2.2`              | Maximum zoom scale             |
| `onLoadMore`          | `Function(bool)?`          | —                  | Called when scrolled to edge   |
| `detailBuilder`       | `WidgetDetailBuilder`      | —                  | Custom info card widget        |
| `controller`          | `KChartController?`        | —                  | Programmatic control           |
| `livePrice`           | `double?`                  | —                  | Real-time price override       |
| `backgroundLogo`      | `Widget?`                  | `null`             | Watermark widget giữa main chart (dưới candles, trên nền) |
| `backgroundLogoOpacity` | `double`               | `1.0`              | Độ mờ của watermark (0.0–1.0)  |

---

## Background logo (watermark)

Truyền bất kỳ widget nào vào `backgroundLogo` để hiển thị như watermark ở giữa vùng main chart — nằm **trên nền** (`bgColor`) nhưng **dưới candles và indicators**.

```dart
KChartWidget(
  data,
  chartStyle,
  chartColors,
  // SVG (cần flutter_svg)
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

> **Lưu ý:** Khi `backgroundLogo != null`, `ChartPainter` bỏ qua `drawBg` (canvas trong suốt). Background được render bằng `ColoredBox(bgColor)` ở layer riêng trong Stack, đảm bảo thứ tự layer: **nền → logo → chart content**.
>
> Logo dùng `IgnorePointer` nên không ảnh hưởng đến gesture.

---

## Gesture interaction

| Gesture | Hành động |
|---|---|
| 1 ngón kéo ngang | Scroll qua các nến (X) |
| 1 ngón kéo dọc | Pan vùng giá lên/xuống (Y) |
| 1 ngón kéo tự do | Scroll X + pan Y đồng thời |
| Pinch 2 ngón | Zoom scaleX (thu phóng số nến hiển thị) |
| Kéo dọc trong 100px phải | Zoom scaleY (thu phóng vùng giá) |
| Double tap vùng phải | Reset scaleY và offsetY về mặc định |
| Tap vào nến | Hiện crosshair + info dialog |
| Tap lại | Ẩn crosshair |
| Kéo khi crosshair đang hiện | Di chuyển crosshair theo ngón tay |
| Long press + kéo | Di chuyển crosshair |

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

// zoom in one step
controller.zoomIn();

// zoom out one step
controller.zoomOut();

// reset scroll and scale
controller.reset();

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
timeFormat: TimeFormat.YEAR_MONTH_DAY

// 2024-01-15 08:30
timeFormat: TimeFormat.YEAR_MONTH_DAY_WITH_HOUR

// custom
timeFormat: [yyyy, '/', mm, '/', dd]
```

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
