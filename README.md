# k_chart_jk

A Flutter candlestick chart package with technical indicators, smooth gestures, and light/dark themes.

## Features

- Candlestick and line chart
- Pan, pinch-zoom (X), drag-zoom on the price axis (Y), double-tap to reset
- Tap-to-toggle crosshair with an info dialog
- 8 main indicators: MA, EMA, BOLL, SAR, ZigZag, SuperTrend, AVL, Ichimoku
- 13 secondary indicators: MACD, KDJ, RSI, WR, CCI, OBV, TRIX, MTM, StochRSI, BRAR, BIAS, PSY, ATR
- Volume bars with MA5 / MA10 overlay
- Real-time price line via `livePrice`, bid/ask badges
- Loading and empty states
- Background watermark (`backgroundLogo`)
- Depth chart widget for order books
- Programmatic control via `KChartController`

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  k_chart_jk:
    git:
      url: https://github.com/MrTuyennn/k_chart_jk.git
```

Then run:

```bash
flutter pub get
```

## Quick start

### 1. Import

```dart
import 'package:k_chart_jk/k_chart_plus.dart';
```

### 2. Prepare data

```dart
final List<KLineEntity> data = [
  KLineEntity.fromCustom(
    time: DateTime.now().millisecondsSinceEpoch,
    open: 65000,
    high: 65800,
    low: 64500,
    close: 65400,
    vol: 120.5,
    amount: 65400 * 120.5,
  ),
  // ...more candles, oldest first
];

// Call after loading data and again whenever the data changes.
DataUtil.calculateAll(data, [MAIndicator()], [MACDIndicator()]);
```

### 3. Render the chart

```dart
KChartWidget(
  data,
  const KChartStyle(),
  const KChartColors(),
  isTrendLine: false,
  mainIndicators: [MAIndicator()],
  secondaryIndicators: [MACDIndicator()],
  mBaseHeight: 300,
  onLoadMore: (isLeft) {
    // Load older candles when the user scrolls to the edge.
  },
  detailBuilder: (entity) => YourInfoCard(entity: entity),
)
```

## Common options

| Parameter | Description |
| --- | --- |
| `mainIndicators` / `secondaryIndicators` | Indicators drawn on the candles / in panels below |
| `isLine` | Line chart instead of candles |
| `volHidden` | Hide the volume panel |
| `livePrice` | Real-time price for the now-price line |
| `bidPrice` / `askPrice` | Best bid / ask badges (set both) |
| `loading` / `emptyPlaceholder` | Spinner / placeholder shown when `data` is null or empty |
| `backgroundLogo` | Watermark widget centered in the main chart |
| `controller` | `KChartController` for `zoomIn()`, `zoomOut()`, `reset()` |
| `timeFormat` | Fixed time format; leave `null` for automatic |

## Dark theme

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

## Example app

The [`example/`](example/lib/main.dart) folder has a full demo. It needs an env file with your own endpoints:

```bash
cd example
flutter pub get
cp env.example.json env.dev.json   # fill in your endpoints
flutter run --dart-define-from-file=env.dev.json
```

## License

Copyright (c) 2026 JK. All rights reserved. See [LICENSE](LICENSE).
