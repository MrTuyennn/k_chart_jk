# k_chart_wikex — Tài liệu tham khảo

## Mục lục
- [Thay đổi gần đây](#thay-đổi-gần-đây)
- [OBV Indicator](#obv-indicator)
- [Thêm secondary indicator mới](#thêm-secondary-indicator-mới)
- [KChartWidget — Tham số](#kchartwidget--tham-số)
- [KChartColors — Màu sắc](#kchartcolors--màu-sắc)
- [KChartStyle — Kích thước & layout](#kchartstyle--kích-thước--layout)
- [Kiến trúc renderer](#kiến-trúc-renderer)
- [Lazy Load Data](#lazy-load-data)

---

## OBV Indicator

### Tổng quan

OBV (On-Balance Volume) là indicator phụ, hiển thị trong panel riêng bên dưới chart chính giống MACD/RSI/KDJ.

| Đường | Màu mặc định | Ý nghĩa |
|-------|-------------|---------|
| OBV | `#217AFF` (xanh) | Giá trị OBV tích lũy |
| Signal | `#FFC634` (vàng) | MA5 của OBV |

### Công thức

```
obv[0] = vol[0]
obv[i] = obv[i-1] + vol[i]   // nến tăng (close > close trước)
obv[i] = obv[i-1] - vol[i]   // nến giảm (close < close trước)
obv[i] = obv[i-1]            // close bằng nhau
signal = SMA(obv, 5)         // MA5 của OBV
```

### Cách đọc tín hiệu

| Tình huống | Ý nghĩa |
|-----------|---------|
| OBV tăng + giá tăng | Xu hướng tăng được xác nhận |
| OBV tăng + giá đi ngang/giảm | **Bullish divergence** — tiền đang vào dù giá chưa phản ánh |
| OBV giảm + giá giảm | Xu hướng giảm được xác nhận |
| OBV giảm + giá tăng/đi ngang | **Bearish divergence** — tiền đang thoát dù giá còn cao |
| OBV cắt lên signal line | Tín hiệu mua |
| OBV cắt xuống signal line | Tín hiệu bán |

### Dùng trong code

```dart
// Thêm vào secondaryIndicators
KChartWidget(
  _data,
  chartStyle,
  chartColors,
  secondaryIndicators: [OBVIndicator()],
  ...
)

// Tuỳ chỉnh màu và period signal
OBVIndicator(
  indicatorStyle: OBVStyle(
    obvColor: Colors.blue,
    signalColor: Colors.orange,
  ),
)
// Đổi period signal (ví dụ MA10): sửa calcParams trong OBVIndicator constructor
```

### Files liên quan

| File | Vai trò |
|------|---------|
| `lib/entity/obv_entity.dart` | Mixin `OBVEntity` — 2 field: `obv`, `obvSignal` |
| `lib/indicator/secondary/obv_indicator.dart` | Toàn bộ logic: calc, drawChart, drawFigure, drawVerticalText |
| `lib/indicator/indicator_style.dart` | `OBVStyle` — cấu hình màu sắc |
| `lib/entity/k_entity.dart` | `KEntity` mixes `OBVEntity` |

---

## Thêm secondary indicator mới

Pattern để implement thêm một indicator phụ bất kỳ:

```
1. Tạo lib/entity/<name>_entity.dart
   └─ mixin <Name>Entity { double? field1; ... }

2. Thêm mixin vào lib/entity/k_entity.dart
   └─ class KEntity with ..., <Name>Entity {}

3. Export trong lib/entity/index.dart

4. Thêm <Name>Style vào lib/indicator/indicator_style.dart

5. Tạo lib/indicator/secondary/<name>_indicator.dart
   └─ part of '../indicator_template.dart';
   └─ class <Name>Indicator extends SecondaryIndicator<<Name>Entity, <Name>Style>
      ├─ getMaxMinValue() — cho secondary renderer biết scale
      ├─ drawFigure()     — label text khi scroll/long press
      ├─ drawVerticalText() — nhãn max/min bên phải panel
      ├─ drawChart()      — vẽ đường/bar lên canvas
      └─ calc()           — tính giá trị, gán vào từng KLineEntity

6. Thêm part '<name>_indicator.dart' vào indicator_template.dart

7. Thêm button + case vào example/main.dart
```

---

## Thay đổi gần đây

### 1. Label indicator cập nhật theo scroll (`base_chart_painter.dart`)

**File:** `lib/renderer/base_chart_painter.dart` — `paint()`

```dart
// Trước:
drawText(canvas, datas!.last, chartStyle.space);

// Sau:
drawText(canvas, getItem(mStopIndex), chartStyle.space);
```

**Lý do:** `datas!.last` luôn cố định ở nến cuối cùng. Dùng `getItem(mStopIndex)` (candle phải nhất đang hiển thị) để label MA, VOL, MACD... cập nhật khi người dùng scroll sang trái.

**Hành vi khi long press / tap:** vẫn hiển thị data của nến được chọn (xử lý trong `chart_painter.drawText`).

---

### 2. Multi-select secondary indicator (`example/main.dart`)

**Trước:** Chỉ 1 indicator phụ cùng lúc (single enum `_secondaryType`). Bấm indicator khác → đổi, không cộng dồn.

**Sau:** Dùng `Set<_SecondaryType> _secondaryTypes` — bấm để thêm/bỏ từng panel độc lập.

```dart
// Toggle thêm/bỏ indicator
void _toggleSecondary(_SecondaryType type) {
  setState(() {
    if (_secondaryTypes.contains(type)) {
      _secondaryTypes.remove(type);
    } else {
      _secondaryTypes.add(type);
    }
    _recalculate();
  });
}

// Map theo thứ tự cố định (MACD → KDJ → RSI → WR → CCI)
List<SecondaryIndicator> get _secondaryIndicators {
  const order = [macd, kdj, rsi, wr, cci];
  return order
      .where((t) => _secondaryTypes.contains(t))
      .map<SecondaryIndicator>((t) => switch (t) { ... })
      .toList();
}
```

**Thứ tự panel:** luôn theo thứ tự cố định `MACD → KDJ → RSI → WR → CCI`, không phụ thuộc thứ tự bấm.

---

### 3. Layout volume overlay (`chart_painter.dart` + `base_chart_painter.dart`)

Volume **không phải panel riêng bên dưới** mà là overlay chiếm **20% dưới của `mMainRect`**:

```
mMainRect
├── mainContentRect  (80% trên) ← nến, MA, BOLL...
└── mVolRect         (20% dưới) ← vol bars
```

```dart
// base_chart_painter.initRect()
final double overlayHeight = mMainRect.height * 0.2;
mVolRect = Rect.fromLTRB(0, mMainRect.bottom - overlayHeight, mWidth, mMainRect.bottom);

// chart_painter.initChartRenderer()
final Rect mainContentRect = mVolRect != null
    ? Rect.fromLTRB(mMainRect.left, mMainRect.top, mMainRect.right, mVolRect!.top)
    : mMainRect;
```

Cả `mMainRenderer` và `mVolRenderer` đều được vẽ trong cùng canvas transform (`scaleY`), clip vào `mMainRect`.

---

### 4. ScaleY + offsetY transform (`chart_painter.drawChart`)

Main chart và volume đều được scale/pan bằng canvas transform, **không** scale giá trị:

```dart
canvas.translate(0, centerY * (1 - scaleY) + offsetY);
canvas.scale(1.0, scaleY);
// vẽ main + vol bên trong transform này
```

**Secondary indicators** vẽ ngoài transform này → không bị ảnh hưởng bởi scaleY.

Các label vẽ ngoài transform (nowPrice, maxMin, volText) phải tính lại vị trí screen bằng:
```dart
double _applyScaleY(double rawY) {
  final double centerY = (mMainRect.top + mMainRect.bottom) / 2;
  return centerY + (rawY - centerY) * scaleY + offsetY;
}
```

---

## KChartWidget — Tham số

### Dữ liệu

| Tham số | Kiểu | Giải thích |
|---------|------|-----------|
| `datas` | `List<KLineEntity>?` | Danh sách nến cần vẽ. Mỗi `KLineEntity` chứa open, high, low, close, volume, time. Nullable — khi null hoặc rỗng chart trắng. |
| `livePrice` | `double?` | Giá realtime từ socket/stream. Nếu có, đường giá hiện tại dùng giá trị này thay vì `datas.last.close`. |

### Indicator chính (vẽ đè lên nến)

| Tham số | Kiểu | Giải thích |
|---------|------|-----------|
| `mainIndicators` | `List<MainIndicator>` | Indicator hiển thị trên khung nến chính. Hỗ trợ: `MAIndicator`, `BOLLIndicator`, `EMAIndicator`, `SARIndicator`, `ZigZagIndicator`. |
| `secondaryIndicators` | `List<SecondaryIndicator>` | Indicator phụ, mỗi cái sinh ra 1 khung riêng bên dưới. Hỗ trợ: `MACDIndicator`, `KDJIndicator`, `RSIIndicator`, `WRIndicator`, `CCIIndicator`. |
| `volHidden` | `bool` | `true` = ẩn khung volume. Chỉ nên ẩn khi dùng MA/BOLL/SAR. |

### Kiểu hiển thị chart

| Tham số | Kiểu | Mặc định | Giải thích |
|---------|------|----------|-----------|
| `isLine` | `bool` | `false` | `true` = line chart (giá đóng cửa). `false` = candlestick. |
| `hideGrid` | `bool` | `false` | `true` = ẩn lưới ngang/dọc. |
| `showNowPrice` | `bool` | `true` | Hiển thị đường kẻ ngang + nhãn giá hiện tại. |
| `isTrendLine` | `bool` | — | `true` = bật chế độ vẽ trend line thủ công (nhấn giữ 2 điểm). |

### Popup thông tin khi chạm

| Tham số | Kiểu | Mặc định | Giải thích |
|---------|------|----------|-----------|
| `showInfoDialog` | `bool` | `true` | Cho phép hiện popup OHLCV khi tap/long press. |
| `isTapShowInfoDialog` | `bool` | `false` | `true` = popup hiện khi tap thường. `false` = chỉ hiện khi long press. |
| `materialInfoDialog` | `bool` | `true` | Dành cho style popup — chưa dùng trong code, giữ cho tương lai. |
| `detailBuilder` | `WidgetDetailBuilder` | — | **Bắt buộc.** Hàm nhận `KLineEntity` → trả về Widget popup tùy chỉnh. |

### Định dạng thời gian

| Tham số | Kiểu | Mặc định | Giải thích |
|---------|------|----------|-----------|
| `timeFormat` | `List<String>` | `YEAR_MONTH_DAY` | Định dạng ngày giờ trục X. Dùng `TimeFormat.YEAR_MONTH_DAY` hoặc `TimeFormat.YEAR_MONTH_DAY_WITH_HOUR`. Chart cũng tự suy định dạng theo khoảng cách giữa 2 nến. |

### Kích thước layout

| Tham số | Kiểu | Mặc định | Giải thích |
|---------|------|----------|-----------|
| `mBaseHeight` | `double` | `360` | Chiều cao khung nến chính (px). |
| `mSecondaryHeight` | `double?` | `mBaseHeight * 0.2` | Chiều cao mỗi khung indicator phụ. Nếu null tự tính = 20% chiều cao chính. |
| `xFrontPadding` | `double` | `100` | Khoảng trống bên phải chart sau cây nến cuối (px). |

### Cuộn & zoom

| Tham số | Kiểu | Mặc định | Giải thích |
|---------|------|----------|-----------|
| `minScale` | `double` | `0.5` | Mức zoom tối thiểu (thu nhỏ tối đa). |
| `maxScale` | `double` | `2.2` | Mức zoom tối đa (phóng to tối đa). |
| `flingTime` | `int` | `600` | Thời gian (ms) animation quán tính sau khi thả tay. |
| `flingRatio` | `double` | `0.5` | Hệ số tốc độ fling — càng cao chart trượt càng xa. |
| `flingCurve` | `Curve` | `Curves.decelerate` | Curve animation cho fling. |

### Callback

| Tham số | Kiểu | Mặc định | Giải thích |
|---------|------|----------|-----------|
| `onLoadMore` | `Function(bool)?` | `null` | Gọi khi scroll đạt 80% về biên. `true` = biên trái (load data cũ hơn). `false` = biên phải. |
| `isLoadingMore` | `bool` | `false` | App truyền vào để báo đang fetch — widget dùng để chặn double-trigger. |
| `isOnDrag` | `Function(bool)?` | `null` | Gọi khi trạng thái kéo thay đổi. `true` = đang kéo, `false` = đã dừng. |

### Giao diện & điều khiển

| Tham số | Kiểu | Giải thích |
|---------|------|-----------|
| `chartColors` | `KChartColors` | Toàn bộ màu sắc của chart. |
| `chartStyle` | `KChartStyle` | Kích thước nến, padding, grid... |
| `verticalTextAlignment` | `VerticalTextAlignment` | Vị trí nhãn giá trục Y: `left` hoặc `right`. |
| `controller` | `KChartController?` | Điều khiển chart từ bên ngoài: `reset()`, `zoomIn()`, `zoomOut()`. |

---

## KChartColors — Màu sắc

### Nền & khung

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `bgColor` | `#FFFFFF` | Màu nền toàn bộ chart. Đổi dark mode phải đổi cái này trước. |
| `gridColor` | `#D1D3DB` | Màu đường lưới ngang và dọc. |

### Nến

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `upColor` | `#14AD8F` | Màu nến tăng (close > open). |
| `dnColor` | `#D5405D` | Màu nến giảm (close < open). |

### Line chart

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `kLineColor` | `#217AFF` | Màu đường kẻ khi dùng chế độ line chart. |
| `kLineFillColors` | `[#80217AFF → #00217AFF]` | Gradient fill bên dưới đường line (xanh mờ → trong suốt). |

### Volume

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `volColor` | `#2F8FD5` | Màu cột volume mặc định (ít dùng). |
| `volUpColor` | `#14AD8F` | Màu cột volume của nến tăng. |
| `volDnColor` | `#D5405D` | Màu cột volume của nến giảm. |

### Moving Average (trên khung volume)

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `ma5Color` | `#FFC634` | Màu đường MA5 Volume. |
| `ma10Color` | `#35CDAC` | Màu đường MA10 Volume. |

> Màu đường MA/BOLL/EMA/MACD... trên khung chính và phụ được cấu hình trong `IndicatorStyle` của từng indicator riêng (`MAStyle`, `BOLLStyle`, `MACDStyle`...).

### Giá hiện tại

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `nowPriceUpColor` | `#14AD8F` | Màu đường & nhãn giá khi giá > open nến cuối. |
| `nowPriceDnColor` | `#D5405D` | Màu đường & nhãn giá khi giá < open nến cuối. |

### Cross line (khi long press)

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `crossColor` | `#191919` | Màu đường chữ thập ngang/dọc. |
| `crossTextColor` | `#222223` | Màu chữ trong box giá và box ngày giờ. |
| `selectBorderColor` | `#222223` | Viền box giá / box ngày khi cross line hiển thị. |
| `selectFillColor` | `#FFFFFF` | Nền bên trong box giá / box ngày. |

### Max/Min label

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `maxColor` | `#222223` | Màu nhãn giá cao nhất vùng hiển thị. |
| `minColor` | `#222223` | Màu nhãn giá thấp nhất vùng hiển thị. |

### Trend line

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `trendLineColor` | `#F89215` | Màu đường và crosshair khi vẽ trend line. |

### Văn bản chung

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `defaultTextColor` | `#909196` | Màu chữ số trục Y (giá), trục X (ngày), spinner. |

### Ví dụ dark mode

```dart
const KChartColors(
  bgColor:           Color(0xFF1C1C1E),
  defaultTextColor:  Color(0xFF8E8E93),
  gridColor:         Color(0xFF2C2C2E),
  selectFillColor:   Color(0xFF2C2C2E),
  selectBorderColor: Color(0xFF636366),
  crossColor:        Color(0xFFEBEBF5),
  crossTextColor:    Color(0xFFEBEBF5),
  maxColor:          Color(0xFFEBEBF5),
  minColor:          Color(0xFFEBEBF5),
  // upColor / dnColor giữ nguyên xanh/đỏ
)
```

---

## KChartStyle — Kích thước & layout

> Tất cả thuộc tính là `final`. Muốn thay đổi cần tạo subclass hoặc sửa trực tiếp trong source.

### Padding

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `topPadding` | `20.0` | Khoảng trống phía trên khung nến chính, chỗ hiển thị nhãn MA/BOLL. |
| `bottomPadding` | `16.0` | Chiều cao vùng ngày tháng đáy chart (trục X). |
| `childPadding` | `12.0` | Khoảng cách giữa khung nến chính và khung volume/secondary. |
| `space` | `4.0` | Khoảng cách giữa nhãn text và mép chart ở trục Y. |

### Nến

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `pointWidth` | `11.0` | Khoảng cách tâm-tâm giữa 2 nến liền kề. Ảnh hưởng số nến hiển thị và tốc độ scroll. |
| `candleWidth` | `8.5` | Độ rộng thân nến (hình chữ nhật). Phải nhỏ hơn `pointWidth`. |
| `candleLineWidth` | `1.0` | Độ rộng bóng nến (đường thẳng đứng high/low). |

### Volume

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `volWidth` | `8.5` | Độ rộng cột volume. Thường bằng `candleWidth` để căn thẳng. |

### Cross line & now price

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `crossWidth` | `0.8` | Độ dày đường chữ thập khi long press. |
| `nowPriceLineWidth` | `0.8` | Độ dày đường kẻ ngang giá hiện tại (dashed line). |
| `borderWidth` | `0.5` | Độ dày viền box giá trên cross line và box giá hiện tại. |

### Grid

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `gridRows` | `4` | Số hàng lưới ngang (chia khung theo chiều dọc). |
| `gridColumns` | `4` | Số cột lưới dọc (chia chart theo chiều ngang). |

### Định dạng thời gian

| Thuộc tính | Mặc định | Giải thích |
|-----------|----------|-----------|
| `dateTimeFormat` | `null` | Override định dạng ngày giờ trục X. Nếu `null`, chart tự chọn theo khoảng thời gian giữa các nến. |

---

## Lazy Load Data

### Cơ chế scroll

| Giá trị `mScrollX` | Vị trí | Ý nghĩa |
|-------------------|--------|---------|
| `0` | Biên phải | Data mới nhất — vị trí mặc định khi mở chart |
| `maxScrollX` | Biên trái | Data cũ nhất |

Kéo tay sang trái → `mScrollX` **tăng** dần về `maxScrollX`.

### Trigger lazy load

Widget tự động gọi `onLoadMore(true)` khi:

```
mScrollX >= maxScrollX * 0.8   →  đã scroll qua 80% → trigger sớm trước khi chạm biên
```

Guard bằng `isLoadingMore`: nếu đang fetch thì không trigger thêm.

### Các param liên quan

| Param | Kiểu | Mặc định | Giải thích |
|-------|------|----------|-----------|
| `onLoadMore` | `Function(bool)?` | `null` | `true` = biên trái (load data cũ hơn). `false` = biên phải (load data mới hơn). |
| `isLoadingMore` | `bool` | `false` | App truyền vào để báo đang fetch. Widget dùng để chặn double-trigger. |

### Flow hoạt động

```
User kéo trái → mScrollX >= maxScrollX * 0.8
  └─> !widget.isLoadingMore → gọi onLoadMore(true)
       └─> App: setState(() => _isFetching = true)   [isLoadingMore = true → chặn trigger]
            └─> fetch API async...
                 └─> App: prepend data → recalculate → setState(() => _isFetching = false)
                                                                     [isLoadingMore = false → cho phép trigger lại]
```

### Cách implement trong app

```dart
bool _isFetching = false;

void _onLoadMore(bool isLeft) async {
  if (!isLeft) return;        // chỉ xử lý load data cũ hơn
  if (_isFetching) return;    // double-guard phía app

  setState(() => _isFetching = true);

  final olderData = await fetchOlderCandles(); // gọi API
  if (!mounted) return;

  // Bắt buộc: tính lại indicator trên toàn bộ data mới
  final merged = [...olderData, ..._data];
  DataUtil.calculateAll(merged, _mainIndicators, _secondaryIndicators);

  setState(() {
    _data = merged;
    _isFetching = false;
  });
}

// Truyền vào widget
KChartWidget(
  _data,
  chartStyle,
  chartColors,
  onLoadMore: _onLoadMore,
  isLoadingMore: _isFetching,   // widget dùng để chặn re-trigger
  ...
)
```

### Lưu ý quan trọng

- **Phải gọi `DataUtil.calculateAll()`** trên toàn bộ list mới trước khi `setState` — các indicator (MA, BOLL, MACD...) cần tính lại từ đầu vì phụ thuộc vào data trước đó.
- **Prepend** (thêm vào đầu list) = `isLeft: true` = data cũ hơn.
- **Append** (thêm vào cuối list) = `isLeft: false` = data mới hơn.
- Widget tự detect khi `datas.length` thay đổi và `datas.first.time` thay đổi → tự bù scroll.
- Nếu sau 30 giây widget không nhận data mới, spinner tự tắt (timeout fallback).

---

## Kiến trúc renderer

### Luồng vẽ mỗi frame (`BaseChartPainter.paint`)

```
paint()
├── initRect()          — tính mMainRect, mVolRect, mDateRect, mSecondaryRectList
├── calculateValue()    — tính mStartIndex/mStopIndex và max/min giá cho từng vùng
├── initChartRenderer() — tạo MainRenderer, VolRenderer, SecondaryRenderer
├── drawBg()
├── drawGrid()
├── drawChart()
│   ├── canvas transform (scaleX, translateX)
│   ├── canvas transform (scaleY, offsetY) → clip mMainRect
│   │   ├── MainRenderer.drawChart()   (nến, MA, BOLL...)
│   │   └── VolRenderer.drawChart()    (vol bars)
│   └── SecondaryRenderer.drawChart()  (MACD, KDJ... — ngoài scaleY)
├── drawVerticalText()  — nhãn giá trục Y
├── drawDate()          — trục X
├── drawText()          — label MA/VOL/MACD... (dùng getItem(mStopIndex))
├── drawMaxAndMin()     — nhãn giá cao/thấp nhất
└── drawNowPrice()      — đường & nhãn giá hiện tại
```

### Tại sao label vẽ ngoài scaleY transform

`drawText`, `drawMaxAndMin`, `drawNowPrice` được gọi sau khi `canvas.restore()` — canvas đã về trạng thái gốc. Tọa độ Y các hàm này truyền vào là tọa độ màn hình thực.

Để tính vị trí màn hình của một điểm `rawY` trong không gian chart (sau scaleY):
```dart
double screenY = centerY + (rawY - centerY) * scaleY + offsetY;
// centerY = (mMainRect.top + mMainRect.bottom) / 2
```

### Các rect chính

| Rect | Vùng | Ghi chú |
|------|------|---------|
| `mMainRect` | Toàn bộ khung nến + vol | `top = mTopPadding`, `bottom = mTopPadding + mainHeight` |
| `mainContentRect` | Phần nến thuần | `mMainRect.top → mVolRect.top` (80% trên) |
| `mVolRect` | Vol bars | `mMainRect.bottom - 20% height → mMainRect.bottom` |
| `mDateRect` | Trục X ngày giờ | Ngay dưới `mMainRect.bottom` |
| `mSecondaryRectList[i]` | Panel indicator phụ | Xếp chồng bên dưới `mDateRect` |
