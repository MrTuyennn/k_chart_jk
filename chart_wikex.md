# k_chart_wikex — Tài liệu tham khảo

## Mục lục
- [Thay đổi gần đây](#thay-đổi-gần-đây) — gồm: **padding phải tỷ lệ theo width**, **tự bù scroll khi append nến mới**, **gesture gate vol/secondary**, **VolRenderer panel độc lập + date đáy cùng**, **DepthChart logo + bottomLabelCount**, label theo scroll, multi-select secondary, scaleY transform, **pan Y clamp 50%**, **overscroll handoff**
- [OBV Indicator](#obv-indicator)
- [Mixin type system — generic indicator](#mixin-type-system--generic-indicator)
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

## Mixin type system — generic indicator

### Vấn đề

Khi dùng `List<SecondaryIndicator<MACDEntity, dynamic>>`, tất cả indicator phải có `T = MACDEntity`. Nếu một indicator mới dùng entity riêng (ví dụ `OBVEntity`), Dart báo lỗi:

```
The element type 'OBVIndicator' can't be assigned to the list type
'SecondaryIndicator<MACDEntity, dynamic>'.
```

### Nguyên nhân

Dart generics **không covariant** — `SecondaryIndicator<OBVEntity, X>` và `SecondaryIndicator<MACDEntity, X>` là 2 type khác nhau dù `OBVEntity` và `MACDEntity` đều là mixin của `KEntity`.

### Giải pháp áp dụng

Thêm entity mới vào `on` clause của `MACDEntity`, và đặt nó trước `MACDEntity` trong `KEntity`:

```dart
// entity/macd_entity.dart
// Thêm OBVEntity vào on clause → MACDEntity có thể truy cập .obv / .obvSignal
mixin MACDEntity on KDJEntity, RSIEntity, WREntity, CCIEntity, OBVEntity {
  double? dea;
  double? dif;
  double? macd;
}

// entity/k_entity.dart
// OBVEntity phải đứng TRƯỚC MACDEntity vì MACDEntity khai báo `on OBVEntity`
class KEntity with ..., OBVEntity, MACDEntity, ZigZagEntity {}

// indicator/secondary/obv_indicator.dart
// Dùng MACDEntity làm T thay vì OBVEntity
class OBVIndicator extends SecondaryIndicator<MACDEntity, OBVStyle> { ... }
```

Sau fix, `OBVIndicator` fit vào `List<SecondaryIndicator<MACDEntity, dynamic>>` như MACD/RSI/KDJ.

### Quy tắc khi thêm entity mới

Nếu indicator mới cần entity riêng và phải dùng chung `List<SecondaryIndicator<MACDEntity, dynamic>>`:

1. Tạo `<Name>Entity` mixin đơn giản (không có `on`)
2. Thêm `<Name>Entity` vào `on` clause của `MACDEntity`
3. Đặt `<Name>Entity` **trước** `MACDEntity` trong `KEntity`
4. Dùng `MACDEntity` làm T trong `<Name>Indicator`

> **Lưu ý:** Nếu chỉ dùng `List<SecondaryIndicator>` (raw type, không generic) ở phía app thì không cần làm các bước trên — nhưng mất type safety.

---

## Thêm secondary indicator mới

Pattern để implement thêm một indicator phụ bất kỳ:

```
1. Tạo lib/entity/<name>_entity.dart
   └─ mixin <Name>Entity { double? field1; ... }

2. Thêm vào lib/entity/macd_entity.dart
   └─ mixin MACDEntity on ..., <Name>Entity { ... }
   (để indicator dùng MACDEntity làm T mà vẫn truy cập field của <Name>Entity)

3. Thêm vào lib/entity/k_entity.dart
   └─ class KEntity with ..., <Name>Entity, MACDEntity, ...
   (đặt <Name>Entity TRƯỚC MACDEntity)

4. Export trong lib/entity/index.dart

5. Thêm <Name>Style vào lib/indicator/indicator_style.dart

6. Tạo lib/indicator/secondary/<name>_indicator.dart
   └─ class <Name>Indicator extends SecondaryIndicator<MACDEntity, <Name>Style>
      ├─ getMaxMinValue() — cho secondary renderer biết scale
      ├─ drawFigure()     — label text khi scroll/long press
      ├─ drawVerticalText() — nhãn max/min bên phải panel
      ├─ drawChart()      — vẽ đường/bar lên canvas
      └─ calc()           — tính giá trị, gán vào từng KLineEntity

7. Thêm part '<name>_indicator.dart' vào indicator_template.dart

8. Thêm button + case vào example/main.dart
```

---

## Thay đổi gần đây

### −4. Padding phải tỷ lệ theo chiều rộng chart (`base_chart_painter.dart`, `k_chart_widget.dart`)

**Bug:** `xFrontPadding` mặc định `100` được trừ trực tiếp trong `getMinTranslateX()`
theo **data space**, không co theo `mWidth`. Chart hẹp (split view, màn nhỏ) vẫn
chừa ~100px bên phải như chart rộng → lãng phí vùng nến. Vùng gesture scaleY
cũng cố định `width: 100` / `width - 100`, không đồng bộ.

**Fix:**

1. Thêm `BaseChartPainter.effectiveRightPaddingPx(xFrontPadding, chartWidth)`:
   - `referenceChartWidth = 375` — tại width này padding = `xFrontPadding` đầy đủ.
   - Chart hẹp hơn → padding giảm tỷ lệ (`× chartWidth / 375`, cap tối đa = `xFrontPadding`).
2. `getMinTranslateX()` dùng `effectiveRightPaddingPx / scaleX` (px → data space) để
   khoảng trống màn hình ổn định khi pinch zoom `scaleX`.
3. Vùng scaleY (`Positioned` phải) + `_isScaleYGesture` dùng cùng helper — width zone
   đồng bộ với padding scroll.
4. `StreamController.broadcast()` cho `mInfoWindowStream` — tránh lỗi rebuild
   `StreamBuilder` ("Stream has already been listened to"). **Không** bọc toàn bộ
   `GestureDetector` trong `LayoutBuilder` (chỉ `LayoutBuilder` bên trong `Positioned`).

```dart
// base_chart_painter.dart
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

| `mWidth` (scaleX=1, xFrontPadding=100) | Padding màn hình |
|----------------------------------------|------------------|
| ≥ 375px | 100px |
| 250px | ~67px |
| 187px | ~50px |

**Tuning:** tăng `xFrontPadding` nếu label giá bị sát nến; giảm nếu muốn tối đa vùng candle trên màn rộng.

---

### −3. Tự bù `mScrollX` khi append nến mới (`k_chart_widget.dart`)

**Bug:** Khi user đang scroll xem history mà live tick append nến mới, view bị
"trôi" — mỗi nến mới đẩy user thêm 1 candle về phía data cũ. Trong example
trước đây còn gọi `_controller.reset()` trong `_addNewCandle` → user bị quăng
hẳn về rightmost. Phá hoàn toàn UX đọc lịch sử.

**Fix:** Thêm `didUpdateWidget` trong `KChartWidget` để detect khi parent
push thêm data và tự bù `mScrollX`:

```dart
@override
void didUpdateWidget(KChartWidget oldWidget) {
  super.didUpdateWidget(oldWidget);
  _compensateScrollOnDataChange(oldWidget);
}

void _compensateScrollOnDataChange(KChartWidget oldWidget) {
  // Chỉ xử lý append (nến đầu giữ nguyên, nến cuối mới hơn).
  // Prepend tự bảo toàn view trong data space → không cần bù.
  final diff = newData.length - oldData.length;
  if (diff <= 0) return;
  final appended = oldData.first.time == newData.first.time
      && oldData.last.time != newData.last.time;
  if (!appended) return;
  if (mScrollX <= 0.0) return;  // đang rightmost → auto-follow
  mScrollX += diff * widget.chartStyle.pointWidth;
}
```

**Logic:**
- `mScrollX` đại diện khoảng cách (px) từ biên phải tới vị trí đang xem.
- Append `diff` nến mới → biên phải tịnh tiến thêm `diff × pointWidth`.
- Để giữ user ở đúng vùng candle cũ → cộng `diff × pointWidth` vào `mScrollX`.
- Ngoại lệ: `mScrollX == 0` (rightmost) → giữ nguyên 0 để auto-follow nến mới
  (UX TradingView/Binance — chỉ stick rightmost khi user đang ở rightmost).

**Prepend (lazy-load nến cũ)** không cần bù: `getMinTranslateX` tự tính lại
đúng theo data mới → `mStartIndex` cũ ánh xạ tự nhiên sang `mStartIndex + diff`
trong data mới → view trong data space được bảo toàn.

**Example app:** xoá `_controller.reset()` khỏi `_addNewCandle` — chart tự
giữ vị trí mà không cần app can thiệp.

---

### −2. Gesture gate theo vùng — vol/secondary không di chuyển nến (`k_chart_widget.dart`)

**Vấn đề:** Trước đây drag bất cứ đâu trong chart (kể cả vol/secondary/date)
đều update `mScrollX`/`mOffsetY` → vol panel kéo theo nến. Khi nhúng chart
trong page có Order Book/form trade, user kỳ vọng drag dọc trên vol/MACD/RSI
cuộn page chứ không phải xê dịch nến.

**Fix:** Gate gesture theo điểm chạm start. Chỉ khi `painter.isInMainRect`
trả về `true` thì chart mới xử lý. Ngược lại forward `dy` sang outer.

```dart
// State
bool _gestureInMain = true;

onScaleStart: (details) {
  // ... existing
  _gestureInMain = painter.isInMainRect(details.localFocalPoint);
},
onScaleUpdate: (details) {
  // Vol/secondary + 1 ngón: chỉ chặn pan Y, vẫn scroll X như bình thường.
  // Pinch (≥2 ngón) đi xuống nhánh dưới → scaleX bình thường.
  if (!_gestureInMain && details.pointerCount < 2) {
    isOnTap = false;
    mScrollX = (mScrollX + details.focalPointDelta.dx / mScaleX)
        .clamp(0.0, ChartPainter.maxScrollX)
        .toDouble();
    final dy = details.focalPointDelta.dy;
    if (dy != 0) widget.onVerticalOverscroll?.call(dy);
    if (!widget.isLoadingMore &&
        widget.onLoadMore != null &&
        ChartPainter.maxScrollX > 0 &&
        mScrollX >= ChartPainter.maxScrollX * 0.8) {
      widget.onLoadMore!(true);
    }
    notifyChanged();
    return;
  }
  // ... existing logic
},
onScaleEnd: (details) {
  // Fling X chạy cho cả drag từ vol/secondary (vì cũng update scrollX).
  if (!_dragStartedInTapMode) {
    _onFling(details.velocity.pixelsPerSecond.dx);
  }
  _dragStartedInTapMode = false;
  _gestureInMain = true;
},
```

**Behaviour matrix:**

| Touch start | Drag X (1 ngón) | Drag Y (1 ngón) | Pinch (2 ngón) | Fling X | Lazy load |
|---|---|---|---|---|---|
| `mMainRect` | scrollX nến | pan Y (nếu scaleY≠1) | scaleX | có | có |
| `mVolRect` / secondary / date | **scrollX nến** | forward parent | **scaleX** | **có** | **có** |

Vol/secondary chỉ chặn **pan Y** — mọi hành vi khác (scroll/zoom/fling/lazy load)
đều giữ nguyên để timeline vẫn cuộn được khi user vuốt trên panel phụ.

**Tương thích outer scroll:** parent dùng `jumpTo` trong
`onVerticalOverscroll` callback → bypass physics, list ngoài cuộn được kể
cả khi parent đang `NeverScrollableScrollPhysics` (do scaleY focus mode).

**Tap & long-press không bị gate:**

- Tap đã có sẵn check `isInMainRect` trước khi toggle crosshair.
- Long press vẫn cho phép ở vol/secondary để inspect candle tương ứng — vì
  long press không di chuyển chart, chỉ hiển thị crosshair.

Chi tiết kèm decision tree + edge cases (drag chéo, pinch trên vol…): xem
`chart_wikex_arch.md` mục 11.2.1.

---

### −1. Vol = panel độc lập + date xuống đáy cùng (`base_chart_painter.dart`)

Layout cuối:

```
mMainRect          ← candles + main indicators
mVolRect           ← vol (null khi volHidden)
mSecondaryRect[0]  ← MACD
mSecondaryRect[1]  ← RSI
…
mDateRect          ← trục thời gian (đáy cùng)
```

Khớp với sơ đồ đơn giản của `chart_plush.md`: 3 renderer `MainRenderer +
VolRenderer + SecondaryRenderer`. Date axis ở đáy cùng — các panel chart
xếp liên tục phía trên, khớp UX trading app (Binance/MEXC/TradingView).

**File chính:**
- `lib/renderer/vol_renderer.dart` — `VolRenderer extends BaseChartRenderer<VolumeEntity>` (bars + MA5/MA10).
- `lib/renderer/base_chart_painter.dart` — `initRect` tính `mDateRect` sau cùng.
- `lib/styles/k_chart_style.dart` — `volBarOpacity` (default 1.0).

---

### 0. DepthChart: watermark logo + số mốc giá tuỳ chỉnh (`depth_chart.dart`)

**File:** `lib/depth_chart.dart`, `example/lib/main.dart`

Thêm 3 tham số mới cho `DepthChart`:

| Param | Default | Mô tả |
|---|---|---|
| `backgroundLogo` | `null` | Widget watermark đặt giữa vùng depth chart (giống `KChartWidget.backgroundLogo`). Có `IgnorePointer` nội bộ. Khi `null`, không tạo `Stack` thừa. |
| `backgroundLogoOpacity` | `1.0` | Độ trong suốt watermark, 0.0–1.0. |
| `bottomLabelCount` | `5` | Số mốc giá ở trục dưới — có thể đổi 3, 5, 7, 9… (tối thiểu 2). |

**Render logo:** Khi `backgroundLogo != null`, `build` bọc `CustomPaint` trong `Stack` với logo `Center` + `IgnorePointer` ở dưới, chart vẽ chồng lên trên.

**Vẽ mốc giá động:** thay 5 nhãn hardcoded (start, leftHalf, center, rightHalf, end) bằng vòng lặp `n = bottomLabelCount`:

```dart
for (int i = 0; i < n; i++) {
  final t = i / (n - 1);              // 0..1
  final x = t * mWidth;
  // Nội suy tuyến tính từng đoạn: trái [startPrice..centerPrice], phải [centerPrice..endPrice]
  final price = t <= 0.5
      ? startPrice + (centerPrice - startPrice) * (t * 2)
      : centerPrice + (endPrice - centerPrice) * ((t - 0.5) * 2);
  // ... layout text, align: i==0 trái, i==n-1 phải, còn lại center quanh x với clamp
}
```

`centerPrice = (bids.last.price + asks.first.price) / 2` — giữ ý nghĩa giá mid như cũ.

**Example (`example/lib/main.dart`):**

- Thêm `Switch "Depth"` ở `AppBar.actions` để toggle giữa candle chart và depth chart (state `_showDepth`).
- `_buildDepthChartSection()` dựng `DepthChart` từ `_generateMockDepth`, gắn cùng `logo_wikex.svg` watermark như candle chart.
- Hàng chip `3 | 5 | 7 | 9` phía trên depth chart bind vào state `_depthBottomLabelCount` để xem nhanh hiệu ứng của `bottomLabelCount`.

---

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

### 3. Volume = panel độc lập với `VolRenderer` + `mVolRect`

Khớp với sơ đồ đơn giản của `chart_plush.md`: 3 renderer (`Main` + `Vol` +
`Secondary`) chạy trong cùng `ChartPainter.drawChart`. Vol có rect riêng
(`mVolRect`) ngay dưới `mMainRect`, **không** overlay trong main và
**không** là `SecondaryIndicator`. Toggle bằng cờ `volHidden`.

**Layout:**

```
mMainRect          ← nến + main indicators
mVolRect           ← vol panel (null khi volHidden = true)
mSecondaryRect[0]  ← MACD
mSecondaryRect[1]  ← RSI
...
mDateRect          ← trục thời gian (đáy cùng)
```

**Files:**

| File | Vai trò |
|---|---|
| `lib/renderer/vol_renderer.dart` | `VolRenderer extends BaseChartRenderer<VolumeEntity>` — vẽ bar + MA5/MA10, label `VOL/MA5/MA10`, max vertical text. `getY` override giả định min=0. |
| `lib/renderer/base_chart_painter.dart` | Field `mVolRect`, `mVolMaxValue/MinValue`, cờ `volHidden`, hàm `getVolMaxMinValue`. `initRect` chèn `mVolRect` giữa main và date. |
| `lib/renderer/chart_painter.dart` | Field `mVolRenderer`. `drawBg/drawGrid/drawChart/drawVerticalText/drawText` đều gọi nhánh `mVolRenderer?`. `VolRenderer.drawChart` chạy ngoài scope scaleY (cùng nhánh với secondary). |
| `lib/renderer/base_dimension.dart` | `_mVolumeHeight = volHidden ? 0 : mSecondaryHeight`. `mDisplayHeight` cộng thêm. |
| `lib/k_chart_widget.dart` | Param `volHidden` (default `false`). |
| `lib/styles/k_chart_style.dart` | Thêm `volBarOpacity` (default 1.0) — override khi muốn cột vol mờ. |

**Hệ quả về scaleY:** `VolRenderer` vẽ **ngoài** `canvas.scale(1, scaleY)` của
main → panel vol không bị giãn khi user zoom dọc nến. Đây là điểm bổ sung
so với chart_plush.md gốc (gốc vẽ vol trong cùng scope).

**Cách dùng:**

```dart
KChartWidget(
  _data,
  chartStyle,
  chartColors,
  volHidden: false,                        // bật panel vol
  secondaryIndicators: [MACDIndicator()],
)

// Tuỳ chỉnh độ trong suốt của cột vol
KChartWidget(
  ...,
  chartStyle: const KChartStyle(null, 0.6),  // volBarOpacity = 0.6
)
```

---

### 4. ScaleY + offsetY transform (`chart_painter.drawChart`)

Main chart được scale/pan bằng canvas transform, **không** scale giá trị:

```dart
canvas.translate(0, centerY * (1 - scaleY) + offsetY);
canvas.scale(1.0, scaleY);
// vẽ main bên trong transform này
```

**Volume + Secondary indicators** vẽ ngoài transform này → không bị ảnh hưởng bởi scaleY.

Các label vẽ ngoài transform (nowPrice, maxMin) phải tính lại vị trí screen bằng:
```dart
double _applyScaleY(double rawY) {
  final double centerY = (mMainRect.top + mMainRect.bottom) / 2;
  return centerY + (rawY - centerY) * scaleY + offsetY;
}
```

---

### 5. Pan Y gate theo scaleY + clamp 50% (`k_chart_widget.dart`)

**Vấn đề:** 1-finger drag tự do trước đây cộng dồn cả `mScrollX` và `mOffsetY` — pan Y luôn active kể cả khi `mScaleY = 1.0` (chart fit viewport, không có gì để pan). Ngoài ra chart có thể pan ra ngoài viewport quá xa.

**Fix:** Pan Y chỉ active sau khi user đã scaleY (drag dọc vùng `Positioned` bên phải, width = `effectiveRightPaddingPx`) → `mScaleY != 1.0`. Đồng thời clamp `mOffsetY` để giữ tối thiểu 50% chart content trong view.

```dart
} else {
  // 1 ngón tay drag tự do → scroll X
  mScrollX = (mScrollX + dx / mScaleX).clamp(0.0, ChartPainter.maxScrollX);
  // Pan Y chỉ active sau khi user đã scaleY qua vùng Positioned bên phải
  if (mScaleY != 1.0) {
    mOffsetY = _clampOffsetY(mOffsetY + dy);
  }
  // ...
}
```

**Helper clamp:**
```dart
// |offsetY| ≤ baseHeight * scaleY / 2 → đúng 50% content height bị đẩy ra
// khỏi viewport tại biên, 50% còn lại luôn hiển thị.
double _clampOffsetY(double v) {
  final double maxOffset = widget.mBaseHeight * mScaleY / 2;
  return v.clamp(-maxOffset, maxOffset);
}
```

Re-clamp `mOffsetY` mỗi khi `mScaleY` thay đổi (bound phụ thuộc scaleY).

| `mScaleY` | `|mOffsetY|` max |
|---|---|
| 0.3 | 0.15 × baseHeight |
| 1.0 | 0.5 × baseHeight |
| 5.0 | 2.5 × baseHeight |

**UX:**
- Mặc định (`mScaleY = 1`): drag bình thường chỉ cuộn timeline (X), không trôi dọc.
- Drag dọc vùng phải (`effectiveRightPaddingPx`) → scaleY (zoom dọc). Sau đó drag bất kỳ đâu → pan Y, giới hạn 50%.
- Double-tap vùng phải → reset scaleY=1, offsetY=0 → tắt pan Y.

---

### 6. Vertical overscroll handoff (`k_chart_widget.dart` + parent)

**Vấn đề:** Khi nhúng chart trong `SingleChildScrollView` (có UI khác như OrderBook bên dưới), nếu user pan chart đến biên 50% và tiếp tục drag dọc, chart sẽ "tắc" — chart đã clamp, outer scroll bị khoá (do `_scaleYActive`), không gì cuộn nữa.

**Fix:** Emit phần delta vượt clamp ra ngoài qua callback `onVerticalOverscroll`, parent forward sang `ScrollController` của outer.

#### Bên `KChartWidget`

Thêm callback:
```dart
/// delta > 0: drag xuống quá biên dưới; delta < 0: drag lên quá biên trên.
final ValueChanged<double>? onVerticalOverscroll;
```

Detect overscroll trong `onScaleUpdate` (normal drag branch):
```dart
if (mScaleY != 1.0) {
  final double dy = details.focalPointDelta.dy;
  final double newOffsetY = mOffsetY + dy;
  final double clampedOffsetY = _clampOffsetY(newOffsetY);
  mOffsetY = clampedOffsetY;
  final double overscroll = newOffsetY - clampedOffsetY;
  if (overscroll != 0 && widget.onVerticalOverscroll != null) {
    widget.onVerticalOverscroll!(overscroll);
  }
}
```

Khi `mScaleY == 1`: chart không claim pan Y, vertical drag tự nhiên thuộc outer scroll qua gesture arena → không cần forward.

#### Bên parent

```dart
final _outerScrollController = ScrollController();

SingleChildScrollView(
  controller: _outerScrollController,
  physics: (_scaleYActive && _pointerOnChart)
      ? const NeverScrollableScrollPhysics()  // khoá outer khi chart đang focused
      : const ClampingScrollPhysics(),
  child: ...,
)

KChartWidget(
  ...,
  onVerticalOverscroll: _onChartVerticalOverscroll,
)

void _onChartVerticalOverscroll(double delta) {
  if (!_outerScrollController.hasClients) return;
  final pos = _outerScrollController.position;
  // Đảo dấu: convention scroll Flutter ngược chiều với pan finger.
  // Finger drag DOWN (delta > 0) → outer pos GIẢM (reveal content trên).
  // Finger drag UP (delta < 0) → outer pos TĂNG (reveal content dưới).
  final target = (pos.pixels - delta).clamp(
    pos.minScrollExtent,
    pos.maxScrollExtent,
  );
  if (target != pos.pixels) {
    // jumpTo bypass physics → vẫn cuộn được khi outer đang NeverScrollableScrollPhysics
    _outerScrollController.jumpTo(target);
  }
}
```

#### Cơ chế chuyển giao

```
mOffsetY     -max          0         +max
              │             │           │
finger UP ────┼─chart pan─→ │ ←─pan────┼──── finger DOWN
              │                         │
   overscroll ↓                         ↓ overscroll
   outer pos TĂNG                outer pos GIẢM
   (xuống OrderBook)             (lên đầu trang)
```

Khi user đảo chiều drag: chart absorb trước (mOffsetY rời biên trở lại 0), outer dừng. Chỉ khi mOffsetY chạm biên ngược → outer mới scroll tiếp ở hướng ngược.

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
| `secondaryIndicators` | `List<SecondaryIndicator>` | Indicator phụ, mỗi cái sinh ra 1 khung riêng bên dưới. Hỗ trợ: `MACDIndicator`, `KDJIndicator`, `RSIIndicator`, `WRIndicator`, `CCIIndicator`, `OBVIndicator`. |
| `volHidden` | `bool` | `true` = ẩn panel volume. Vol có rect riêng (`mVolRect`) giữa main và date, không phải secondary indicator. |

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
| `xFrontPadding` | `double` | `100` | Khoảng trống bên phải sau nến cuối (px) tại chart rộng ≥375px. Chart hẹp hơn → tự giảm tỷ lệ qua `effectiveRightPaddingPx`. Cùng giá trị quyết định width vùng gesture scaleY. |

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
| `mVolRect` | Panel volume | Ngay dưới `mMainRect.bottom`, null khi `volHidden` |
| `mSecondaryRectList[i]` | Panel indicator phụ | Xếp chồng bên dưới `mVolRect` (hoặc `mMainRect` nếu vol ẩn) |
| `mDateRect` | Trục X ngày giờ | **Đáy cùng** — dưới panel cuối |
