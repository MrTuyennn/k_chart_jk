# Handbook — `k_chart_wikex`

Tài liệu A → Z cho package candlestick chart `k_chart_wikex`. Mô tả từng widget, entity, indicator, controller, style, util, và cơ chế gesture nội bộ.

---

## Mục lục

1. [Tổng quan kiến trúc](#1-tổng-quan-kiến-trúc)
2. [Cài đặt & quick start](#2-cài-đặt--quick-start)
3. [Entry point & exports](#3-entry-point--exports)
4. [Entity — data models](#4-entity--data-models)
5. [`KChartWidget` — API đầy đủ](#5-kchartwidget--api-đầy-đủ)
6. [`KChartController`](#6-kchartcontroller)
7. [`KChartStyle` & `KChartColors`](#7-kchartstyle--kchartcolors)
8. [Indicators — main & secondary](#8-indicators--main--secondary)
9. [`DataUtil` & helpers](#9-datautil--helpers)
10. [`DepthChart` — orderbook depth](#10-depthchart--orderbook-depth)
11. [Renderer internals](#11-renderer-internals)
12. [Gesture model](#12-gesture-model)
13. [Recipes — công thức thường dùng](#13-recipes--công-thức-thường-dùng)
14. [Troubleshooting & pitfalls](#14-troubleshooting--pitfalls)

---

## 1. Tổng quan kiến trúc

```
┌──────────────────────────────────────────────────────────┐
│                    KChartWidget                          │
│  (Stateful, public API)                                  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │  GestureDetector (tap / scale / longPress)         │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │  Stack                                       │  │  │
│  │  │  ├── ColoredBox (bg)                         │  │  │
│  │  │  ├── backgroundLogo (watermark)              │  │  │
│  │  │  ├── CustomPaint(painter: ChartPainter)      │  │  │
│  │  │  │     └── BaseChartPainter                  │  │  │
│  │  │  │           └── MainRenderer / VolRenderer  │  │  │
│  │  │  │               / SecondaryRenderer         │  │  │
│  │  │  ├── Positioned (vùng phải scaleY, width ∝ chart) │  │  │
│  │  │  └── InfoDialog (long-press detail)          │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
        ▲                          ▲
        │                          │
   KChartController          List<KLineEntity>
   (zoom / reset / scroll)   ← DataUtil.calculateAll()
```

**Flow dữ liệu:**

1. Bạn chuẩn bị `List<KLineEntity>` (mỗi entity = 1 nến OHLCV + time).
2. Gọi `DataUtil.calculateAll(data, mainIndicators, secondaryIndicators)` để tính toán giá trị các chỉ báo (MA, MACD, RSI…) → các trường mixin được populate vào entity.
3. Truyền list này vào `KChartWidget` cùng style/colors/indicators.
4. `ChartPainter` đọc data đã tính, dùng renderer để vẽ từng nến + indicator.
5. `KChartController` ở ngoài có thể gọi `zoomIn` / `zoomOut` / `reset`; widget listen `ChangeNotifier` và update internal state.

---

## 2. Cài đặt & quick start

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
  [MAIndicator()],            // main indicators
  [MACDIndicator()],           // secondary indicators
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

## 3. Entry point & exports

File chính import: `package:k_chart_wikex/k_chart_plus.dart`. Re-export:

| Export | Chứa gì |
|---|---|
| `k_chart_widget.dart` | `KChartWidget`, `TimeFormat`, `WidgetDetailBuilder` |
| `styles/k_chart_style.dart` | `KChartStyle`, `KChartColors` |
| `styles/depth_chart_style.dart` | `DepthChartStyle`, `DepthChartColors` |
| `depth_chart.dart` | `DepthChart` widget |
| `chart_translations.dart` | `DepthChartTranslations` |
| `utils/index.dart` | `DataUtil`, `dateFormat`, `NumberUtil`, format tokens |
| `entity/index.dart` | Toàn bộ entity & mixin |
| `renderer/index.dart` | `ChartPainter`, `BaseChartPainter`, renderer base |
| `renderer/k_chart_controller.dart` | `KChartController` |
| `extension/num_ext.dart` | `num.toStringAsFixedNoZero(...)` |
| `indicator/indicator_template.dart` | `IndicatorTemplate`, `MainIndicator`, `SecondaryIndicator`, tất cả indicator + style |

**Note:** `wikex.dart` là file mở rộng export bổ sung (xem trong file để biết list); dùng khi cần import gọn nhiều helper.

---

## 4. Entity — data models

### 4.1 `KLineEntity` (lib/entity/k_line_entity.dart)

Nến chính. Kế thừa `KEntity` (multi-mixin) → mang sẵn slot cho mọi chỉ báo.

| Field | Kiểu | Ý nghĩa |
|---|---|---|
| `open` | `double` | Giá mở cửa |
| `high` | `double` | Giá cao nhất |
| `low` | `double` | Giá thấp nhất |
| `close` | `double` | Giá đóng cửa |
| `vol` | `double` | Volume |
| `time` | `int?` | Timestamp **ms** (Unix epoch) |
| `amount` | `double?` | Quote volume (close × vol). Optional |
| `change` | `double?` | Biến động giá tuyệt đối. Optional |
| `ratio` | `double?` | % thay đổi. Optional |

**Constructor:**
- `KLineEntity.fromCustom(...)` — truyền field thẳng.
- `KLineEntity.fromJson(json)` — parse từ Map. Có fallback: nếu thiếu `time` thì lấy `id * 1000` (tương thích định dạng Huobi).
- `.toJson()` — serialize ngược.

### 4.2 `KEntity` & các mixin

`KEntity` chỉ là composite mixin, không khai báo field riêng. Mỗi mixin add field tương ứng:

| Mixin | Field thêm vào entity | Indicator dùng |
|---|---|---|
| `CandleEntity` | `open/high/low/close`, `maValueList`, `emaValueList`, `sar`, `boll: Boll?` | MA, EMA, SAR, BOLL |
| `VolumeEntity` | `open/close/vol`, `MA5Volume`, `MA10Volume` | Volume MA |
| `MACDEntity` | `dea`, `dif`, `macd` | MACD |
| `KDJEntity` | `k`, `d`, `j` | KDJ |
| `RSIEntity` | `rsi` | RSI |
| `WREntity` | `r` (%R) | WR |
| `CCIEntity` | `cci` | CCI |
| `OBVEntity` | `obv`, `obvSignal` | OBV |
| `ZigZagEntity` | `zigzag` | ZigZag |

**Lý do `Boll` class riêng:** Boll Bands có 3 đường (up/mid/dn), gói trong sub-object `Boll { up, mid, dn, bollMa }`.

**Thứ tự mixin trong `KEntity` quan trọng** — `OBVEntity` phải đứng trước `MACDEntity` (do `MACDEntity on ... OBVEntity`).

### 4.3 `InfoWindowEntity`

Dùng cho dialog hiển thị chi tiết khi long-press / tap:

```dart
class InfoWindowEntity {
  KLineEntity kLineEntity;  // nến đang được chọn
  bool isLeft;              // true: vẽ dialog bên trái, false: bên phải
}
```

Widget phát qua `mInfoWindowStream` (internal) — bạn chỉ cần cung cấp `detailBuilder` để render UI.

### 4.4 `DepthEntity`

```dart
class DepthEntity {
  double price;
  double vol;
}
```

Dùng cho `DepthChart` (orderbook depth). `vol` thường là **cumulative volume** (tích lũy từ best bid/ask ra xa).

### 4.5 `ZigZagEntity`

Trường `zigzag: double?` — lưu giá tại pivot point. Các nến không phải pivot thì `null`.

---

## 5. `KChartWidget` — API đầy đủ

File: `lib/k_chart_widget.dart`.

### 5.1 Required positional & named

| Param | Kiểu | Bắt buộc | Ý nghĩa |
|---|---|---|---|
| `datas` | `List<KLineEntity>?` | ✓ (positional 1) | Data nguồn. Empty/null = chart trống. |
| `chartStyle` | `KChartStyle` | ✓ (positional 2) | Kích thước, padding, line width. |
| `chartColors` | `KChartColors` | ✓ (positional 3) | Toàn bộ màu. |
| `detailBuilder` | `Widget Function(KLineEntity)` | ✓ named | Builder cho info dialog (long-press). |
| `isTrendLine` | `bool` | ✓ named | Bật mode vẽ trend line (tap 2 lần để xác định 2 điểm). |

### 5.2 Indicators & display options

| Param | Default | Ý nghĩa |
|---|---|---|
| `mainIndicators` | `[]` | List `MainIndicator` overlay trên main chart (MA, BOLL, EMA, SAR, ZigZag). |
| `secondaryIndicators` | `[]` | List `SecondaryIndicator` thành panel riêng bên dưới (MACD, KDJ, RSI, WR, CCI, OBV). |
| `volHidden` | `false` | Ẩn panel volume (volume nằm trong rect riêng giữa main và date — không phải secondary indicator). |
| `isLine` | `false` | `true` = line chart (chỉ đường close), `false` = candlestick. |
| `hideGrid` | `false` | Ẩn lưới ngang/dọc. |
| `showNowPrice` | `true` | Vẽ đường giá hiện tại (nến cuối) ngang qua chart, kèm label bên phải. |
| `showInfoDialog` | `true` | Cho phép hiện dialog detail. |
| `isTapShowInfoDialog` | `false` | `true` = single tap cũng hiện crosshair + dialog (mặc định chỉ long-press). |
| `materialInfoDialog` | `true` | Style dialog Material vs Cupertino. |
| `timeFormat` | `TimeFormat.yearMonthDay` | Format thời gian dưới X axis. Xem `TimeFormat` constants. |
| `livePrice` | `null` | Giá realtime override cho line "now price". Nếu null dùng `data.last.close`. |
| `xFrontPadding` | `100` | Padding phải sau nến cuối (px tại chart ≥375px). Chart hẹp hơn tự co qua `effectiveRightPaddingPx`; đồng bộ width vùng scaleY. |
| `verticalTextAlignment` | `right` | `left` / `right` — vị trí label giá dọc. |
| `fixedLength` | `2` | Số chữ số thập phân format giá. |

### 5.3 Pan / zoom / scroll

| Param | Default | Ý nghĩa |
|---|---|---|
| `minScale` | `0.5` | Min cho `mScaleX` (zoom out limit). |
| `maxScale` | `2.2` | Max cho `mScaleX` (zoom in limit). |
| `flingTime` | `600` | ms — duration fling animation sau khi thả tay. |
| `flingRatio` | `0.5` | Hệ số nhân vận tốc fling. |
| `flingCurve` | `Curves.decelerate` | Curve animation fling. |
| `mBaseHeight` | `360` | Height (px) của main chart panel. |
| `mSecondaryHeight` | `mBaseHeight * 0.2` | Height (px) của mỗi secondary panel. |

### 5.4 Load more / state callback

| Param | Kiểu | Ý nghĩa |
|---|---|---|
| `onLoadMore` | `void Function(bool isLeft)?` | Trigger khi scroll gần biên. `isLeft = true` → user kéo sang trái (load data cũ hơn). `false` → cuối phải (mới hơn). |
| `isLoadingMore` | `bool` | Cờ khoá: nếu `true`, widget không trigger thêm `onLoadMore` (tránh duplicate request). |
| `isOnDrag` | `void Function(bool)?` | Callback start/stop drag (true khi bắt đầu, false khi end/cancel). |
| `controller` | `KChartController?` | Object điều khiển từ ngoài. |

### 5.5 Background watermark

| Param | Default | Ý nghĩa |
|---|---|---|
| `backgroundLogo` | `null` | Widget overlay ở giữa main chart (logo SVG, image…). Có `IgnorePointer` nội bộ — không nhận touch. |
| `backgroundLogoOpacity` | `1.0` | 0.0 ẩn — 1.0 hiện đầy đủ. |

### 5.5b Overscroll handoff

| Param | Kiểu | Ý nghĩa |
|---|---|---|
| `onVerticalOverscroll` | `ValueChanged<double>?` | Fire khi pan Y vượt clamp 50%. `delta > 0` = drag xuống quá biên dưới, `delta < 0` = drag lên quá biên trên. Dùng để forward sang outer `ScrollController` (handoff sang scroll view bao quanh). Chỉ fire khi `mScaleY != 1` (pan Y active). Xem [recipe 13.8](#138-overscroll-handoff-sang-outer-scrollview). |

### 5.6 Internal state (non-public, để hiểu hành vi)

Trong `_KChartWidgetState`:

| Field | Ý nghĩa |
|---|---|
| `mScaleX` | Zoom ngang (timeline). Clamp `[minScale, maxScale]`. |
| `mScrollX` | Offset cuộn ngang (đơn vị data, đã chia mScaleX). Clamp `[0, maxScrollX]`. |
| `mScaleY` | Zoom dọc (price scale). Clamp `[0.3, 5.0]`. Drag dọc vùng phải (`effectiveRightPaddingPx`) để chỉnh. |
| `mOffsetY` | Pan dọc. Chỉ active khi `mScaleY != 1.0`. Clamp `±mBaseHeight * mScaleY / 2` (giữ ≥50% chart trong view). |
| `mSelectX/Y` | Vị trí crosshair khi long-press / tap. |
| `isOnTap / isLongPress / isScale` | Trạng thái gesture hiện tại. |
| `_isScaleYGesture` | `true` khi drag bắt đầu trong vùng phải width = `effectiveRightPaddingPx` (1 ngón) → drag dọc = scaleY. |
| `_dragStartedInTapMode` | `true` khi drag bắt đầu lúc crosshair đang hiện → drag = di chuyển crosshair, không scroll. |

### 5.7 `TimeFormat` constants

```dart
TimeFormat.yearMonthDay         // 2026-05-29
TimeFormat.yearMonthDayWithHour // 2026-05-29 14:30
```

Bạn cũng có thể tự tạo format dùng các token trong `date_format_util.dart` (`yyyy`, `mm`, `dd`, `hour24Padded`, `nn`, …).

---

## 6. `KChartController`

File: `lib/renderer/k_chart_controller.dart`. Là `ChangeNotifier` đơn giản.

| Method | Effect |
|---|---|
| `controller.zoomIn()` | `mScaleX += 0.1`, clamp `[minScale, maxScale]`. |
| `controller.zoomOut()` | `mScaleX -= 0.1`. |
| `controller.reset()` | `mScaleX = 1.0`, `mScrollX = 0.0`, `mSelectX = 0.0`. **Không reset `mScaleY` / `mOffsetY`** — muốn reset Y, double-tap vùng phải chart. |

| Getter | Ý nghĩa |
|---|---|
| `action` | `0` default, `1` reset, `2` zoom, `3` scroll. Internal dispatcher. |
| `zoom` | Step zoom (±0.1 sau khi zoomIn/Out). |

**Lifecycle:** tạo trong `initState`, gọi `dispose()` trong `dispose()` của widget cha.

```dart
final ctrl = KChartController();
// ...
@override
void dispose() { ctrl.dispose(); super.dispose(); }
```

---

## 7. `KChartStyle` & `KChartColors`

File: `lib/styles/k_chart_style.dart`.

### 7.1 `KChartStyle`

Tất cả là `final` constants — không setter:

| Field | Default | Ý nghĩa |
|---|---|---|
| `topPadding` | `20.0` | Padding trên main chart. |
| `bottomPadding` | `16.0` | Padding dưới (date axis). |
| `childPadding` | `12.0` | Padding giữa các panel (main / secondary). |
| `space` | `4.0` | Khoảng cách trong label. |
| `pointWidth` | `11.0` | Khoảng cách giữa 2 nến (px). |
| `candleWidth` | `8.5` | Bề rộng thân nến. |
| `candleLineWidth` | `1.0` | Bề rộng wick (râu nến). |
| `volWidth` | `8.5` | Bề rộng cột volume. |
| `crossWidth` | `0.8` | Bề rộng đường crosshair. |
| `nowPriceLineWidth` | `0.8` | Bề rộng đường giá hiện tại. |
| `borderWidth` | `0.5` | Border cho crosshair label & now-price label. |
| `gridRows` | `4` | Số dòng grid ngang. |
| `gridColumns` | `4` | Số cột grid dọc. |
| `dateTimeFormat` | `null` | Custom format thời gian (override). |

Constructor: `const KChartStyle([List<String>? dateTimeFormat])`.

### 7.2 `KChartColors`

Danh sách màu **toàn bộ** chart. Tất cả `const` defaults — chỉ override khi cần:

| Field | Default | Vùng dùng |
|---|---|---|
| `bgColor` | `0xFFFFFFFF` | Background toàn chart. |
| `kLineColor` | `0xFF217AFF` | Line chart (khi `isLine: true`). |
| `kLineFillColors` | gradient blue | Fill bên dưới line. |
| `ma5Color`, `ma10Color` | vàng / xanh | Mặc định cho MA (override qua `MAStyle.maColors`). |
| `upColor` | `0xFF14AD8F` | Nến tăng + label tăng. |
| `dnColor` | `0xFFD5405D` | Nến giảm + label giảm. |
| `volColor` | `0xFF2F8FD5` | Cột volume (khi không phân up/dn). |
| `volUpColor` / `volDnColor` | xanh / đỏ | Cột volume theo trend. |
| `defaultTextColor` | xám | Text mặc định (axis, label indicator). |
| `nowPriceUpColor` / `nowPriceDnColor` | xanh / đỏ | Đường + label giá hiện tại. |
| `trendLineColor` | cam | Trend line (khi `isTrendLine: true`). |
| `selectBorderColor` | đen | Border của crosshair label box. |
| `selectFillColor` | trắng | Fill của crosshair label box. |
| `gridColor` | xám nhạt | Đường grid. |
| `crossColor` | đen | Crosshair lines. |
| `crossTextColor` | đen | Text trong crosshair label. |
| `maxColor` / `minColor` | đen | Label giá max/min trong khung hiển thị. |

---

## 8. Indicators — main & secondary

### 8.1 Hierarchy

```
IndicatorTemplate<T, K>   ← abstract
├── MainIndicator<T, K>     ← overlay trên main chart
│   ├── MAIndicator    (T = CandleEntity, K = MAStyle)
│   ├── BOLLIndicator
│   ├── EMAIndicator
│   ├── SARIndicator
│   └── ZigZagIndicator
└── SecondaryIndicator<T, K> ← panel riêng bên dưới
    ├── MACDIndicator  (T = MACDEntity, K = MACDStyle)
    ├── KDJIndicator
    ├── RSIIndicator
    ├── WRIndicator
    ├── CCIIndicator
    └── OBVIndicator
```

### 8.2 Field chung trên `IndicatorTemplate`

| Field | Ý nghĩa |
|---|---|
| `name` | Tên đầy đủ (vd `"movingAverage"`). |
| `shortName` | Hiển thị trong label (vd `"MA"`). |
| `calcParams` | `List<int>` — tham số cho thuật toán (vd MA = `[5,10,30,60]`, MACD = `[12,26,9]`). |
| `indicatorStyle` | Object style riêng cho indicator (xem 8.3). |

### 8.3 Built-in indicators chi tiết

#### MA (Moving Average) — main
- **Style:** `MAStyle({ List<Color> maColors })`
- **calcParams:** `[5,10,30,60]` (4 đường mặc định).
- **Output:** `entity.maValueList[i] = trung bình close của calcParams[i] nến gần nhất`.

#### BOLL (Bollinger Bands) — main
- **Style:** `BOLLStyle({ bollColor, ubColor, lbColor, fillColor })`
- **calcParams:** `[20, 2]` — `(period, std multiplier)`.
- **Output:** `entity.boll = Boll { up, mid, dn, bollMa }`.

#### EMA — main
- **Style:** `MAStyle` (dùng chung).
- **calcParams:** `[5, 10, 20]` mặc định.
- **Output:** `entity.emaValueList[i]`.

#### SAR (Stop And Reverse) — main
- **Style:** `SARStyle({ sarColor, radius, strokeWidth })`
- **Output:** `entity.sar = double?` (giá SAR tại nến).

#### ZigZag — main
- **Style:** `ZigZagStyle({ zigzagColor, lineWidth })`
- **calcParams:** `[5]` (deviation %).
- **Output:** `entity.zigzag = double?` chỉ ở pivot.

#### MACD — secondary
- **Style:** `MACDStyle({ upColor, dnColor, macdColor, difColor, deaColor, macdWidth })`
- **calcParams:** `[12, 26, 9]` — `(short EMA, long EMA, signal period)`.
- **Output:** `entity.dif`, `entity.dea`, `entity.macd = (dif-dea)*2`.
- **Vẽ:** histogram (macd) + 2 line (dif/dea). Histogram đảo màu khi đổi trend.

#### KDJ — secondary
- **Style:** `KDJStyle({ kColor, dColor, jColor })`
- **calcParams:** `[9, 3, 3]`.
- **Output:** `k`, `d`, `j` ∈ [0, 100].

#### RSI — secondary
- **Style:** `RSIStyle({ rsiColor })`
- **calcParams:** `[14]`.
- **Output:** `rsi` ∈ [0, 100].

#### WR (Williams %R) — secondary
- **Style:** `WRStyle({ wrColor })`
- **calcParams:** `[14]`.
- **Output:** `r` ∈ [-100, 0].

#### CCI — secondary
- **Style:** `CCIStyle({ cciColor })`
- **calcParams:** `[14]`.
- **Output:** `cci` (không giới hạn).

#### OBV — secondary
- **Style:** `OBVStyle({ obvColor, signalColor })`
- **calcParams:** `[5]` — period cho signal MA.
- **Output:** `obv` (cumulative), `obvSignal` (MA của OBV). Giá trị tuyệt đối không có nghĩa — chỉ xu hướng & cắt signal.

### 8.4 Custom indicator

Implement 4 method abstract:

```dart
class MyIndicator extends MainIndicator<CandleEntity, MyStyle> {
  MyIndicator() : super(
    name: 'myThing', shortName: 'MY',
    calcParams: [10], indicatorStyle: const MyStyle(),
  );

  @override
  void calc(List<KLineEntity> data) { /* populate field */ }

  @override
  (double, double) getMaxMinValue(KLineEntity e, double minV, double maxV) {
    // mở rộng range Y để chỗ vẽ chỉ báo không bị cắt
  }

  @override
  void drawChart(lastPoint, curPoint, lastX, curX, getY, canvas, colors) {
    // canvas.drawLine / drawRect ...
  }

  @override
  TextSpan? drawFigure(CandleEntity e, int precision, KChartColors c) {
    // label hiện trên top main chart
  }
}
```

Với secondary, thêm `drawVerticalText` để vẽ min/max label bên phải.

---

## 9. `DataUtil` & helpers

### 9.1 `DataUtil` (lib/utils/data_util.dart)

| Method | Effect |
|---|---|
| `calculateAll(data, mains, secondaries)` | Gọi `calcVolumeMA` + tính tất cả indicator. Phải gọi mỗi khi data thay đổi (load more, live tick…). |
| `calculateIndicators(data, mains, secondaries)` | Chỉ tính indicator, bỏ qua volume MA. |
| `calculateIndicator(data, indicator)` | Tính 1 indicator riêng. |
| `calcVolumeMA(data)` | Tính `MA5Volume` & `MA10Volume`. |

**Quan trọng:** Khi load thêm data cũ (left), bạn phải merge list rồi gọi `calculateAll` LẠI trên list mới — vì indicator phụ thuộc vào toàn bộ historical data trước nó.

### 9.2 `NumberUtil` (lib/utils/number_util.dart)

| Method | Ví dụ |
|---|---|
| `NumberUtil.format(value, precision)` | Format với precision tự động (loại trailing zero). |
| `NumberUtil.formatFixed(value, precision)` | Fix precision (giữ trailing zero). |

### 9.3 Date format

`dateFormat(DateTime, List<String> tokens)` — token constants nằm trong `date_format_util.dart`:

| Token | Output |
|---|---|
| `yyyy` `yy` | Năm 4/2 chữ số. |
| `mm` `m` `M` `monthNameLong` | Tháng (padded/compact/short name/long name). |
| `dd` `d` | Ngày (padded/compact). |
| `hh` `h` | Giờ 12h. |
| `hour24Padded` `H` | Giờ 24h. |
| `nn` `n` | Phút. |
| `ss` `s` | Giây. |
| `am` | AM/PM. |
| `z` `Z` | Timezone. |

### 9.4 `num_ext.dart`

Extension trên `num` — xem file để biết helper hiện có (vd loại trailing zero).

---

## 10. `DepthChart` — orderbook depth

File: `lib/depth_chart.dart`. Widget độc lập với `KChartWidget`, dùng để vẽ depth chart (Buy/Sell pressure).

### Constructor

```dart
DepthChart(
  bids,                              // List<DepthEntity>
  asks,                              // List<DepthEntity>
  chartColors, {                     // DepthChartColors
  baseUnit = 2,                      // decimal cho amount
  quoteUnit = 6,                     // decimal cho price
  offset = const Offset(8, 0),
  chartTranslations = const DepthChartTranslations(),
  chartStyle = const DepthChartStyle(),
  backgroundLogo,                    // Widget? — watermark giữa vùng depth chart
  backgroundLogoOpacity = 1,         // 0.0–1.0
  bottomLabelCount = 5,              // số mốc giá ở trục dưới (>=2)
})
```

| Field | Default | Ý nghĩa |
|---|---|---|
| `backgroundLogo` | `null` | Widget overlay ở giữa vùng depth chart (logo SVG, image…). Có `IgnorePointer` nội bộ — không nhận touch. Khi `null`, widget render `CustomPaint` trực tiếp (không tạo Stack thừa). |
| `backgroundLogoOpacity` | `1.0` | 0.0 ẩn — 1.0 hiện đầy đủ. |
| `bottomLabelCount` | `5` | Số mốc giá ở trục dưới. Mốc đầu align trái, mốc cuối align phải, các mốc giữa center quanh vị trí X (clamp để không tràn). Giá nội suy tuyến tính từng đoạn: `[bids.first.price..centerPrice]` ở nửa trái và `[centerPrice..asks.last.price]` ở nửa phải, với `centerPrice = (bids.last.price + asks.first.price) / 2`. Tối thiểu `2`. |

### Gesture

- **Long press** + drag → hiện crosshair, hiển thị `price` & `amount` tại điểm chạm.
- **Long press end** → ẩn crosshair.

### `DepthChartStyle`

| Field | Default | Ý nghĩa |
|---|---|---|
| `lineWidth` | `1.0` | Bề rộng đường bid/ask. |
| `radius` | `4.0` | Border-radius của label crosshair. |
| `strokeWidth` | `0.6` | Stroke của fill area. |
| `space` | `2.0` | Khoảng cách label. |
| `padding` | `6.0` | Padding trong label. |
| `dotRadius` | `5.0` | Bán kính dot ở điểm crosshair. |
| `crossWidth` | `0.5` | Bề rộng đường dash crosshair. |

### `DepthChartColors`

- `upColor` / `upFillPathColor` — bid (xanh + fill mờ).
- `dnColor` / `dnFillPathColor` — ask (đỏ + fill mờ).
- `defaultTextColor`, `annotationColor`, `crossColor`, `barrierColor`, `selectBorderColor`, `selectFillColor`.

### `DepthChartTranslations`

```dart
DepthChartTranslations({
  String price = 'Price',
  String amount = 'Amount',
})
```

### `DepthEntity`

```dart
DepthEntity(double price, double vol)
```

`vol` phải là **cumulative** (tích lũy từ best price ra xa), không phải vol từng level.

---

## 11. Renderer internals

Không cần để dùng package, nhưng giúp hiểu performance & extend.

| Class | Trách nhiệm |
|---|---|
| `BaseDimension` | Tính tổng chiều cao: `mBaseHeight + (mSecondaryHeight × n)`. `mVolumeHeight = 0` cứng (volume overlay vào main, không panel riêng). |
| `BaseChartPainter` | Tính `mStartIndex` / `mStopIndex` (nến trong view), `mDataLen`, `maxScrollX`, `getMinTranslateX()` (padding phải qua `effectiveRightPaddingPx`), scaling helpers. |
| `ChartPainter` | Subclass của `BaseChartPainter`. Orchestrate paint: bg → grid → main → vol → secondary → crosshair → labels. Apply canvas transform `scaleY + offsetY` quanh `centerY` của `mMainRect`. |
| `BaseChartRenderer<T>` | Helper render mỗi panel với min/max value, draw text, getY. |
| `MainRenderer` | Vẽ nến / line, MA/BOLL/EMA/SAR/ZigZag overlay. |
| `VolRenderer` | Vẽ cột volume. `drawVerticalText` hiển thị label max (top-right) và min vol thực tế (bottom-right). `mVolMinValue` được tính từ `item.vol` nhỏ nhất trong vùng hiển thị (không còn hardcode `0`). |
| `SecondaryRenderer` | Vẽ panel indicator phụ. Mỗi `SecondaryIndicator` 1 panel riêng, height = `mSecondaryHeight`. |

**Static field quan trọng:** `ChartPainter.maxScrollX` — set trong paint, dùng ở gesture để clamp `mScrollX`. Trigger `onLoadMore(true)` khi `maxScrollX <= 0` (tất cả data vừa khung hình) HOẶC `mScrollX >= maxScrollX * 0.8` (gần biên trái). Sau pinch zoom out, check thêm trong post-frame callback của `onScaleEnd`.

---

## 12. Gesture model

Implemented trong `_KChartWidgetState.build()` (file `k_chart_widget.dart` ~line 224).

### 12.1 Single tap (`onTapUp`)

- Trong main rect: toggle crosshair. Tap lần 1 hiện, lần 2 ẩn.
- Nếu `isTrendLine: true`: tap = record điểm cho trend line (cần 2 tap để xác định 2 đầu).

### 12.2 Long press (`onLongPressStart` / `onLongPressMoveUpdate` / `onLongPressEnd`)

- Hiện crosshair tại vị trí ngón tay.
- Drag để di chuyển crosshair → cập nhật `mSelectX / Y`.
- Phát `InfoWindowEntity` qua stream → `detailBuilder` được gọi để render dialog.
- Thả ra: ẩn crosshair + dialog.

### 12.3 Scale (`onScaleStart` / `onScaleUpdate` / `onScaleEnd`)

`onScaleStart` chốt 2 cờ:

- `_isScaleYGesture` = `pointerCount == 1 && localFocalPoint.dx > width - effectiveRightPaddingPx(...)`
  → drag dọc trong vùng phải (width đồng bộ `xFrontPadding`, co theo chart hẹp).
- `_gestureInMain` = `painter.isInMainRect(localFocalPoint)` → finger có nằm
  trong `mMainRect` hay không. Nếu **false** (vol/secondary/date), toàn bộ
  scroll/scale của chart bị bypass; chỉ forward `dy` cho outer scroll.

`onScaleUpdate` flow:

```
if (!_gestureInMain && pointerCount < 2) {
  // vol/secondary/date + 1 ngón — chỉ chặn pan Y
  mScrollX += dx / mScaleX     // vẫn scroll nến theo dx
  onVerticalOverscroll(dy)     // forward Y cho outer scroll
  trigger onLoadMore nếu cần
  return;
}
// còn lại (chart hoặc pinch ngoài main): 4 nhánh xử lý chart như cũ
```

> **Pinch (≥2 ngón) trên vol/secondary** không bị bypass — vẫn chạy nhánh
> `details.scale != 1.0` → scaleX update. User pinch ở đâu cũng zoom được
> chart ngang.
>
> **Scroll X từ vol/secondary**: 1-ngón drag ngang trên panel phụ vẫn cuộn
> nến — vol/secondary chỉ chặn duy nhất pan Y, mọi gesture X khác giữ nguyên.

4 nhánh khi `_gestureInMain == true`:

| Điều kiện | Hành vi |
|---|---|
| `_dragStartedInTapMode` && 1 ngón && không phải scaleY zone | Di chuyển crosshair theo ngón. |
| `_isScaleYGesture` && 1 ngón | Drag dọc trong vùng phải (`effectiveRightPaddingPx`) → điều chỉnh `mScaleY` ± `delta * 0.005`, clamp `[0.3, 5.0]`. Sau đó re-clamp `mOffsetY`. |
| `details.scale != 1.0` (≥2 ngón) | Pinch zoom → `mScaleX = lastScale * scale`, clamp `[minScale, maxScale]`. |
| 1 ngón drag tự do | Cuộn ngang: `mScrollX += dx / mScaleX`, clamp `[0, maxScrollX]`. Pan dọc CHỈ active khi `mScaleY != 1.0`: `mOffsetY = _clampOffsetY(mOffsetY + dy)`. Trigger `onLoadMore(true)` khi `maxScrollX <= 0` (tất cả data vừa khung hình) HOẶC `mScrollX >= maxScrollX * 0.8`. |

`onScaleEnd`: fling X kích hoạt khi `!_dragStartedInTapMode` (không phải kéo
crosshair), kể cả khi gesture xuất phát từ vol/secondary — vì drag ngang ở
panel phụ cũng update `mScrollX` nên fling X tự nhiên là phần tiếp theo.

### 12.4 Clamp `mOffsetY`

```dart
double _clampOffsetY(double v) {
  final maxOffset = mBaseHeight * mScaleY / 2;
  return v.clamp(-maxOffset, maxOffset);
}
```

→ giữ tối thiểu 50% chart content trong view ở mọi scaleY.

### 12.5 Double-tap (vùng phải scaleY)

`Positioned(right: 0, bottom: mVolumeHeight + secondary + bottomPadding)` chứa `LayoutBuilder` → `GestureDetector` riêng:

- Width vùng = `BaseChartPainter.effectiveRightPaddingPx(xFrontPadding, chartWidth)` (không cố định 100px).
- Double-tap → reset `mScaleY = 1.0`, `mOffsetY = 0.0`.
- Vùng này chỉ phủ chiều cao của main rect (không vượt xuống panel secondary).
- `mInfoWindowStream` dùng `StreamController.broadcast()` để `StreamBuilder` rebuild an toàn.

### 12.6 Fling

Sau drag end, nếu user kéo nhanh (`!_dragStartedInTapMode`), animation Tween chạy với `flingTime` ms, `flingCurve`, `flingRatio` × velocity.

### 12.7 Vertical overscroll handoff

Khi pan Y đến biên clamp 50% và user vẫn drag tiếp, phần delta vượt biên được fire qua `onVerticalOverscroll(double delta)`:

```dart
if (mScaleY != 1.0) {
  final double dy = details.focalPointDelta.dy;
  final double newOffsetY = mOffsetY + dy;
  final double clampedOffsetY = _clampOffsetY(newOffsetY);
  mOffsetY = clampedOffsetY;
  final double overscroll = newOffsetY - clampedOffsetY;  // delta chart không hấp thụ
  if (overscroll != 0) widget.onVerticalOverscroll?.call(overscroll);
}
```

**Quy ước dấu:**
- `delta > 0` — finger drag DOWN, chart ở biên `+max` (mOffsetY = +mBaseHeight * mScaleY / 2).
- `delta < 0` — finger drag UP, chart ở biên `-max`.

**Khi `mScaleY == 1.0`**: chart không claim pan Y. Outer scroll's `VerticalDragGestureRecognizer` thắng gesture arena → vertical drag tự nhiên cuộn outer. Không có callback fire — không cần.

**Auto-cancel khi đảo chiều**: User drag ngược (lên sau khi đã ở biên dưới) → `newOffsetY` giảm về trong range → `overscroll = 0` → outer dừng. Chart absorb hết delta cho tới khi chạm biên ngược lại.

**Lưu ý implement parent**: phải đảo dấu khi forward sang `ScrollController.jumpTo` vì convention scroll Flutter ngược chiều pan finger (xem recipe 13.8).

---

## 13. Recipes — công thức thường dùng

### 13.1 Live tick (cập nhật nến cuối hoặc thêm nến mới)

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

Khi đóng nến hiện tại → push thêm 1 entity mới với `time = last.time + interval`.

### 13.2 Load more khi scroll trái

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

### 13.3 Dark theme

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

### 13.4 Toggle nhiều secondary

```dart
List<SecondaryIndicator> get _secondary => [
  if (showMACD) MACDIndicator(),
  if (showKDJ) KDJIndicator(),
  if (showRSI) RSIIndicator(),
];
```

Mỗi indicator thêm 1 panel `mSecondaryHeight` → tổng `mDisplayHeight` tự nở.

### 13.5 Custom date format

```dart
KChartWidget(
  data, style, colors,
  detailBuilder: ...,
  isTrendLine: false,
  timeFormat: const [dd, '/', mm, ' ', hour24Padded, ':', nn],
)
```

### 13.6 Watermark logo

```dart
KChartWidget(
  ...,
  backgroundLogo: SvgPicture.asset('assets/logo.svg', width: 80, height: 80),
  backgroundLogoOpacity: 0.15,
)
```

### 13.7 External zoom buttons

```dart
final ctrl = KChartController();
// ...
KChartWidget(..., controller: ctrl)
// ...
IconButton(onPressed: ctrl.zoomIn, icon: Icon(Icons.zoom_in))
IconButton(onPressed: ctrl.zoomOut, icon: Icon(Icons.zoom_out))
IconButton(onPressed: ctrl.reset, icon: Icon(Icons.refresh))
```

### 13.8 Overscroll handoff sang outer scrollview

Use case: chart nằm trong `SingleChildScrollView` cùng các widget khác (orderbook, trade list…). Khi user pan chart đến biên 50% và tiếp tục drag dọc, muốn outer scroll cuộn tiếp để xem widget bên dưới/trên.

```dart
class _PageState extends State<Page> {
  final _outerScrollController = ScrollController();
  bool _scaleYActive = false;     // tracked qua Listener trên chart (xem main.dart)
  bool _pointerOnChart = false;

  @override
  void dispose() {
    _outerScrollController.dispose();
    super.dispose();
  }

  void _onChartVerticalOverscroll(double delta) {
    if (!_outerScrollController.hasClients) return;
    final pos = _outerScrollController.position;
    // ⚠ Đảo dấu: chart pan dùng mOffsetY += dy (content theo finger).
    //   Scroll Flutter ngược lại: pixels TĂNG = reveal content dưới (finger UP).
    //   → finger DOWN (delta > 0) phải làm pos GIẢM (reveal content trên).
    final target = (pos.pixels - delta).clamp(
      pos.minScrollExtent,
      pos.maxScrollExtent,
    );
    if (target != pos.pixels) {
      // jumpTo bypass physics → vẫn cuộn được khi outer đang
      // NeverScrollableScrollPhysics (do _scaleYActive lock)
      _outerScrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _outerScrollController,
      physics: (_scaleYActive && _pointerOnChart)
          ? const NeverScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      child: Column(children: [
        KChartWidget(
          ...,
          onVerticalOverscroll: _onChartVerticalOverscroll,
        ),
        const OrderBookSection(),
      ]),
    );
  }
}
```

**Flow:**
1. User scaleY (drag dọc vùng phải `effectiveRightPaddingPx`) → `_scaleYActive = true` → outer scroll bị khoá.
2. User pan chart xuống → `mOffsetY` tăng đến `+mBaseHeight * mScaleY / 2`.
3. User vẫn drag xuống → `overscroll > 0` fire → outer `jumpTo(pos - positive)` → pos giảm → cuộn lên đầu trang.
4. User đảo chiều drag lên → chart absorb trước (`mOffsetY` giảm), outer dừng. Khi `mOffsetY` chạm `-max` → outer scroll xuống tiếp.

**Lưu ý:** `_scaleYActive` cần track riêng (qua `Listener` wrap chart) — xem implementation trong `example/lib/main.dart`. Khi default state (chưa scaleY), outer scroll natural xử lý vertical drag qua gesture arena, không cần handoff.

---

## 14. Troubleshooting & pitfalls

### "Indicator không hiện"
- Đã gọi `DataUtil.calculateAll(data, mains, secondaries)` chưa? Phải gọi lại MỖI khi list data thay đổi.
- Đủ data cho period chưa? VD MA30 cần ≥30 nến trước nó.

### "Sai data sau load more"
- Phải merge `[...older, ...current]` ROI `calculateAll` lại trên list merged — không tính riêng phần older rồi nối.

### "Time hiển thị sai"
- `time` phải là **milliseconds** Unix epoch, không phải seconds. Nếu API trả seconds, nhân 1000.

### "Crosshair label dính vào cạnh"
- Tăng `xFrontPadding` (mặc định 100px tại chart ≥375px).

### "Chart hẹp vẫn chừa khoảng trống lớn bên phải"
- Padding phải đã scale theo width (`effectiveRightPaddingPx`). Nếu vẫn rộng, giảm `xFrontPadding` hoặc chỉnh `referenceChartWidth` trong `base_chart_painter.dart`.

### "Stream has already been listened to"
- `mInfoWindowStream` phải là `StreamController.broadcast()`. Không bọc toàn bộ `GestureDetector` trong `LayoutBuilder` — chỉ `LayoutBuilder` trong `Positioned` scaleY.

### "Pan dọc không hoạt động"
- Pan dọc CHỈ active sau khi user đã scaleY (`mScaleY != 1.0`). Drag dọc vùng phải (`effectiveRightPaddingPx`) để zoom dọc trước. Hoặc double-tap vùng đó để reset.

### "Outer scroll ăn gesture chart"
- Khi nhúng `KChartWidget` trong `SingleChildScrollView` / `ListView`, vertical drag dễ bị scroll cha bắt. Giải pháp: track pointer events ở widget cha và toggle outer physics → `NeverScrollableScrollPhysics` khi finger trên chart (xem cách làm trong `example/lib/main.dart`).

### "Live tick lag"
- `DataUtil.calculateAll` chạy lại trên toàn list mỗi tick → O(n × số indicator). Với n lớn (>1000 nến) cân nhắc tính incremental chỉ cho nến cuối.

### "Mixin order error"
- Khi tự kế thừa `KEntity`, giữ đúng thứ tự mixin trong file `k_entity.dart`. `OBVEntity` PHẢI trước `MACDEntity`.

### "onLoadMore không được gọi khi zoom out nhỏ"
- Khi scale đủ nhỏ, tất cả data vừa khung hình → `maxScrollX = 0`. `onLoadMore(true)` vẫn được trigger vì điều kiện đã được mở rộng: `maxScrollX <= 0 || mScrollX >= maxScrollX * 0.8`. Nếu user chỉ pinch zoom mà không drag, trigger đến qua post-frame callback trong `onScaleEnd`.

### "Volume panel không tách ra dưới chart"
- Đó là design hiện tại: `BaseDimension._mVolumeHeight = 0`, volume vẽ overlay trên main rect. Comment trong file ghi rõ cách bật lại panel riêng nếu cần.

### "ZigZagIndicator chỉ vẽ vài điểm"
- Bình thường — chỉ pivot mới có value `zigzag`, các nến giữa = `null`. Tăng/giảm `calcParams[0]` (deviation %) để có nhiều/ít pivot.

---

**Generated:** 2026-05-29. Khi sửa code package, update lại tài liệu này nếu có thay đổi API public.
