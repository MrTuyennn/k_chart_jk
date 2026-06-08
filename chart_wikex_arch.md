# k_chart_wikex — Kiến trúc & sơ đồ

Doc này mô tả lại nguồn hiện tại theo cùng cấu trúc với `chart_plush.md`
(mục lục giữ nguyên, nội dung cập nhật theo source).

**Khớp với sơ đồ đơn giản của `chart_plush.md`:** 3 renderer riêng
(`MainRenderer` + `VolRenderer` + `SecondaryRenderer`) chạy trong cùng
`ChartPainter.drawChart`. Vol có panel `mVolRect` dedicated giữa
`mMainRect` và `mDateRect`, toggle bằng `volHidden`.

**Bổ sung so với chart_plush.md gốc:**
- `scaleY` + `offsetY` transform (chỉ áp cho main).
- `backgroundLogo` watermark.
- `DepthChart` thêm `backgroundLogo` + `bottomLabelCount` cấu hình được.
- `secondaryIndicators` là `List<SecondaryIndicator>` (multi-select)
  thay vì enum đơn `secondaryState`.
- Label dùng `getItem(mStopIndex)` (nến phải nhất hiển thị) thay
  `datas.last`.
- Pan Y clamp 50% + overscroll handoff với outer scroll.

---

## 1. Tổng quan kiến trúc

Mã nguồn chart được thiết kế theo mô hình:

- `KChartWidget`: widget chứa, xử lý tương tác (gesture, scroll, scale, long-press,
  pointer tracking cho parent), và tạo `ChartPainter`.
- `ChartPainter`: lớp vẽ chính, kế thừa `BaseChartPainter`.
- `BaseChartPainter`: xử lý layout (chia rect), phạm vi dữ liệu (visible window),
  và điều phối paint.
- `MainRenderer`: vẽ đồ thị chính (nến hoặc line), chạy từng `MainIndicator`
  (MA/BOLL/EMA/SAR/ZigZag) trong cùng vùng `mMainRect`.
- `VolRenderer`: vẽ panel volume (bars + MA5/MA10) trong `mVolRect`. Toggle
  bằng `volHidden` ở `KChartWidget`.
- `SecondaryRenderer`: vẽ một panel indicator phụ (MACD/KDJ/RSI/WR/CCI/OBV).
  Mỗi entry trong `secondaryIndicators` có 1 instance riêng.
- `DepthChartPainter`: vẽ orderbook depth (Buy/Sell pressure) — standalone,
  không gắn với `KChartWidget`.

> **Ghi chú quan trọng:** toàn bộ chart chính của `KChartWidget` được vẽ
> trong một `CustomPaint` duy nhất. `KChartWidget` tạo ra `ChartPainter`,
> và `ChartPainter` quản lý canvas chung, dùng các renderer nội bộ để vẽ
> từng phần trong cùng một hộp vẽ.
>
> - `KChartWidget` = widget chứa và điều khiển tương tác.
> - `ChartPainter` = painter duy nhất gắn vào `CustomPaint`.
> - `MainRenderer`, `VolRenderer`, `SecondaryRenderer` = lớp hỗ trợ vẽ nội bộ.
>
> Box vẽ có 3 vùng con (`main`, `volume`, `secondary list`) khớp với sơ đồ
> đơn giản của `chart_plush.md`. Vol không phải overlay trong main — có rect
> riêng (`mVolRect`) giữa `mMainRect` và `mDateRect`.

### Cách hiểu chi tiết

1. `KChartWidget` nhận dữ liệu và trạng thái cấu hình từ bên ngoài.
2. Trong `build()`, `KChartWidget` tạo `ChartPainter` với:
   - `datas`, `scaleX`, `scaleY`, `scrollX`, `offsetY`, `selectX`.
   - `mainIndicators`, `secondaryIndicators` (list, không phải enum), `isLine`.
   - `volHidden` (toggle panel vol).
   - `chartStyle`, `chartColors`, `xFrontPadding`, `verticalTextAlignment`.
   - `livePrice`, `showNowPrice`, `hideGrid`, `fixedLength`.
   - `skipBg` (true khi `backgroundLogo != null`).
3. `CustomPaint` sử dụng `ChartPainter` làm painter duy nhất.
   `Stack` ngoài bọc thêm: `ColoredBox(bgColor)` + `backgroundLogo`
   (IgnorePointer, centered) + `CustomPaint` + `Positioned` scaleY zone.
4. Flutter gọi `ChartPainter.paint(canvas, size)` để vẽ toàn bộ chart.
5. `BaseChartPainter.paint()` làm:
   - cắt vùng vẽ bằng `canvas.clipRect(0, 0, w, h)`.
   - tính `mDisplayHeight` và `mWidth`.
   - gọi `initRect(size)` để chia `mMainRect`, `mVolRect` (nếu không ẩn),
     `mSecondaryRectList[]`, rồi `mDateRect` ở đáy cùng.
   - gọi `calculateValue()` để:
     - tính `maxScrollX` và `mTranslateX`.
     - xác định `mStartIndex`, `mStopIndex` cho dữ liệu hiển thị.
     - tính `mMainMaxValue/MinValue`, `mVolMaxValue/MinValue`, và mỗi
       `mSecondaryRectList[i].mMaxValue/mMinValue` chỉ trên vùng visible.
   - gọi `initChartRenderer()` để tạo:
     - `mMainRenderer` (1 instance).
     - `mVolRenderer` (1 instance, null nếu `volHidden`).
     - `mSecondaryRendererList[]` (1 instance/SecondaryIndicator).
   - vẽ nền (`drawBg` — skip nếu `skipBg`) và lưới (`drawGrid`).
   - nếu có dữ liệu, gọi `drawChart()`.
6. Trong `ChartPainter.drawChart()`:
   - `canvas.translate(mTranslateX * scaleX, 0)` + `canvas.scale(scaleX, 1.0)`
     → áp dụng cuộn ngang + zoom ngang cho toàn frame.
   - mở canvas scope thứ hai cho `scaleY`:
     - `canvas.clipRect(mMainRect band)`.
     - `canvas.translate(0, centerY*(1-scaleY) + offsetY)`.
     - `canvas.scale(1.0, scaleY)`.
   - lặp `i = mStartIndex..mStopIndex` và gọi `mMainRenderer.drawChart()`.
   - đóng scaleY scope.
   - lặp lại `i = mStartIndex..mStopIndex` và gọi
     `mVolRenderer?.drawChart()` + mỗi `SecondaryRenderer.drawChart()` —
     **ngoài** scaleY transform để vol + secondary không bị giãn theo zoom dọc.
   - sau vòng lặp: nếu cần vẽ crosshair hoặc trend line thì vẽ thêm.
7. Sau `drawChart()`, `BaseChartPainter.paint()` tiếp tục:
   - `drawVerticalText(canvas)` — text trục dọc bên phải.
   - `drawDate(canvas, size)` — ngày giờ ở `mDateRect`.
   - `drawText(canvas, getItem(mStopIndex), chartStyle.space)` — label
     MA/MACD/VOL theo nến phải nhất đang hiển thị (không phải `datas!.last`).
   - `drawMaxAndMin(canvas)` và `drawNowPrice(canvas)` — đã đi qua
     `_applyScaleY(rawY)` để khớp với canvas đã scaleY.
   - `drawCrossLineText(canvas, size)` nếu đang chọn dữ liệu
     (`isLongPress` hoặc `isTapShowInfoDialog && isOnTap`).

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

### Quy tắc quan trọng để port sang source khác

- **Widget quản lý trạng thái + gesture, painter vẽ toàn bộ.**
- **Một `CustomPaint`** cho main chart; secondary indicators KHÔNG phải widget riêng.
- **Tính min/max chỉ trên vùng dữ liệu visible** (`mStartIndex..mStopIndex`),
  không trên toàn dataset.
- **`scrollX` và `scaleX` thành phép biến đổi canvas**, không vẽ tay từng phần.
- **`scaleY` áp riêng cho main**, secondary nằm ngoài transform để không bị giãn.
- **Mỗi renderer chỉ chịu trách nhiệm vẽ trong vùng của nó** (`chartRect`).
- **Mọi label vẽ ngoài canvas transform** phải đi qua `_applyScaleY(rawY)`.

---

## 2. Luồng dữ liệu và tham số chính

### 2.1 Dữ liệu đầu vào

Dữ liệu chính là `List<KLineEntity>` truyền vào `KChartWidget`. `KEntity` là
class mix nhiều mixin để chứa field cho mọi indicator:

```dart
class KEntity with
    CandleEntity,    // open, high, low, close
    VolumeEntity,    // vol, MA5Volume, MA10Volume        ★ trước MACDEntity
    KDJEntity,       // k, d, j
    RSIEntity,       // rsi
    WREntity,        // r (Williams %R)
    CCIEntity,       // cci
    OBVEntity,       // obv, obvSignal                    ★ trước MACDEntity
    MACDEntity,      // dif, dea, macd  (on Vol+OBV+...)
    ZigZagEntity {}  // zigzag points
```

Trường quan trọng theo nhóm:

- **Candle**: `open`, `high`, `low`, `close`, `time`.
- **Volume**: `vol`, `MA5Volume`, `MA10Volume`.
- **Main indicators**: `maValueList` (MA), `up/mb/dn` (BOLL), `ema` (EMA),
  `sar` (SAR), `zigzag`.
- **Secondary indicators**: `dif/dea/macd`, `k/d/j`, `rsi`, `r`, `cci`,
  `obv/obvSignal`.

Tính field bằng `DataUtil.calculateAll(data, mainIndicators, secondaryIndicators)`
— gọi mỗi khi data thay đổi (load more, live tick, init).

### 2.2 Cấu hình hiển thị

Các tham số chính của `KChartWidget`:

- `scaleX` (state): tỷ lệ zoom theo trục X (`minScale`–`maxScale`, default 0.5–2.2).
- `scaleY` (state): tỷ lệ zoom theo trục Y main (0.3–5.0).
- `scrollX` (state): giá trị scroll ngang, clamp `[0, maxScrollX]`.
- `offsetY` (state): pan dọc main, clamp `|offsetY| ≤ baseHeight × scaleY / 2`.
- `isLine`: chuyển giữa line chart và candlestick.
- `mainIndicators`: `List<MainIndicator>` — overlay trên main (MA/BOLL/EMA/SAR/ZigZag).
- `secondaryIndicators`: `List<SecondaryIndicator>` — mỗi entry sinh 1 panel
  (VOL/MACD/KDJ/RSI/WR/CCI/OBV). Thứ tự = thứ tự panel.
- `hideGrid`: ẩn lưới.
- `showNowPrice`: vẽ đường + label giá hiện tại.
- `livePrice`: override giá now-price (realtime socket).
- `xFrontPadding`: padding bên phải sau nến cuối (default 100px tại chart ≥375px). Chart hẹp hơn → `effectiveRightPaddingPx` giảm tỷ lệ; đồng bộ vùng gesture scaleY.
- `mBaseHeight` / `mSecondaryHeight`: chiều cao mỗi panel.
- `backgroundLogo` / `backgroundLogoOpacity`: watermark widget giữa main.
- `onLoadMore` / `isLoadingMore`: lazy load data cũ.
- `onVerticalOverscroll`: forward overscroll Y ra parent (scroll handoff).

> **Khác chart_plush.md gốc:** không còn `mainState`/`secondaryState` enum —
> indicator chính / phụ truyền bằng `List<MainIndicator>` / `List<SecondaryIndicator>`
> để hỗ trợ multi-select. Cờ `volHidden` giữ nguyên như chart_plush.md.

---

## 3. Cách chia vùng và tính toán layout

`BaseDimension` tính tổng chiều cao:

```dart
mDisplayHeight = mBaseHeight + totalSecondaryHeight + totalLabelHeight
// totalSecondaryHeight = mSecondaryHeight × secondaryIndicators.length
// totalLabelHeight     = 12 × mainIndicators.length  (chỗ label MA/BOLL...)
```

`BaseChartPainter.initRect(size)` chia bố cục dọc theo thứ tự:

```
┌───────────────────────────────────────────┐
│  mTopPadding (chartStyle.topPadding + N×12) │ ← N main indicators
├───────────────────────────────────────────┤
│                                           │
│              mMainRect                    │ candles + main indicators
│                                           │
├───────────────────────────────────────────┤
│  mVolRect   (mVolumeHeight)               │ vol panel (null nếu volHidden)
├───────────────────────────────────────────┤
│  mSecondaryRectList[0]                    │ panel đầu (vd: MACD)
├───────────────────────────────────────────┤
│  mSecondaryRectList[1]                    │ panel kế (vd: RSI)
├───────────────────────────────────────────┤
│  ...                                      │
├───────────────────────────────────────────┤
│  mDateRect  (chartStyle.bottomPadding)    │ trục thời gian (đáy cùng)
└───────────────────────────────────────────┘
```

- `mMainRect`: vùng nến + main indicators (không bị overlay volume).
- `mVolRect`: panel volume riêng — `null` khi `volHidden = true`.
- `mSecondaryRectList[i]`: xếp chồng dưới `mVolRect` (hoặc `mMainRect` nếu vol
  ẩn). Mỗi cái cao `mSecondaryHeight` + `mChildPadding` ở đỉnh để chừa chỗ label.
- `mDateRect`: **đáy cùng** — dưới panel cuối (vol/secondary/main). Khớp UX
  trading app: time axis luôn ở dưới cùng, mọi panel chart nằm liên tục phía trên.

> **Khớp chart_plush.md:** layout có 3 vùng `main/vol/secondary` như sơ đồ
> đơn giản. Vol KHÔNG còn overlay 20% trong `mMainRect` — nó là rect độc lập.

---

## 4. Tính toán giá trị hiển thị

`BaseChartPainter.calculateValue()`:

- Xác định `maxScrollX = |getMinTranslateX()|`.
- Set `mTranslateX = scrollX + getMinTranslateX()`.
- Tìm `mStartIndex = indexOfTranslateX(xToTranslateX(0))`,
  `mStopIndex  = indexOfTranslateX(xToTranslateX(mWidth))`
  bằng tìm kiếm nhị phân.

### 4.0 Padding phải & `getMinTranslateX`

Khoảng trống sau nến cuối khi scroll tới biên phải:

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

- `effectiveRightPaddingPx / scaleX`: chuyển padding **screen px** → **data space** để gap màn hình ổn định khi pinch `scaleX`.
- `referenceChartWidth`: tại 375px logical, padding = `xFrontPadding` đầy đủ; chart hẹp hơn co tỷ lệ.
- `KChartWidget`: vùng scaleY + `_isScaleYGesture` dùng cùng helper; `mInfoWindowStream` = `broadcast()`.
- Duyệt `i = mStartIndex..mStopIndex`:
  - `getMainMaxMinValue(item, i)` → `mMainMaxValue`, `mMainMinValue`,
    `mMainMaxIndex`, `mMainMinIndex`, `mMainHighMaxValue`, `mMainLowMinValue`.
  - `getVolMaxMinValue(item)` (nếu `mVolRect != null`) → `mVolMaxValue` =
    `max(vol, MA5Volume, MA10Volume)`, `mVolMinValue = 0` (chốt 0 để cột vol
    neo đáy panel).
  - `getSecondaryMaxMinValue(idx, item)` → cập nhật
    `mSecondaryRectList[idx].mMaxValue/mMinValue` qua
    `secondaryIndicators[idx].getMaxMinValue(item, minV, maxV)`.

### 4.1 Main range

`MainIndicator.getMaxMinValue` mở rộng `(high, low)` ban đầu:
- **MA**: cộng vào range mọi `maValueList[i]`.
- **BOLL**: cộng `up`, `dn` (mb nằm trong khoảng).
- **EMA**: cộng các đường EMA period.
- **SAR/ZigZag**: cộng điểm SAR / zigzag point.
- **isLine == true**: bypass — chỉ dùng `close`.

### 4.2 Vol range

Tính qua `BaseChartPainter.getVolMaxMinValue` (chỉ gọi khi `mVolRect != null`):

```dart
final ma5 = item.MA5Volume ?? 0;
final ma10 = item.MA10Volume ?? 0;
mVolMaxValue = max(mVolMaxValue, max(item.vol, max(ma5, ma10)));
mVolMinValue = 0;   // cột vol luôn neo đáy panel
```

### 4.3 Secondary range

Tuỳ indicator, cộng vào `(minV, maxV)`:

- **MACD**: `macd`, `dif`, `dea`.
- **KDJ**: `k`, `d`, `j`.
- **RSI**: `rsi`.
- **WR**: `r` (giá trị âm).
- **CCI**: `cci`.
- **OBV**: `obv`, `obvSignal` (giá trị tích luỹ rất lớn).

---

## 5. Chuyển đổi toạ độ & hiển thị dữ liệu

### 5.1 Tọa độ X

```dart
getX(index)         = index * mPointWidth + mPointWidth / 2
xToTranslateX(x)    = -mTranslateX + x / scaleX
indexOfTranslateX() = binary search trên getX(i)
translateXtoX(tx)   = (tx + mTranslateX) * scaleX
```

### 5.2 Tọa độ Y

`BaseChartRenderer.getY(value)`:

```dart
scaleY = chartRect.height / (maxValue - minValue)
getY(v) = (maxValue - v) * scaleY + chartRect.top
```

Cho main, **screen Y** thực sự (sau canvas transform scaleY + offsetY):

```dart
double _applyScaleY(double rawY) {
  final centerY = (mMainRect.top + mMainRect.bottom) / 2;
  return (centerY + (rawY - centerY) * scaleY + offsetY)
      .clamp(mMainRect.top, mMainRect.bottom);
}
```

Dùng cho `drawNowPrice`, `drawMaxAndMin` (vẽ ngoài canvas transform).

---

## 6. Vẽ chart chính

`ChartPainter.drawChart(canvas, size)`:

```
canvas.save()
canvas.translate(mTranslateX * scaleX, 0)
canvas.scale(scaleX, 1.0)

  canvas.save()  ─── scaleY scope ───
  canvas.clipRect(mMainRect band)
  canvas.translate(0, centerY*(1-scaleY) + offsetY)
  canvas.scale(1.0, scaleY)
  for i in mStartIndex..mStopIndex:
      mMainRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas)
  canvas.restore()

  for i in mStartIndex..mStopIndex:                  ← ngoài scaleY
      mVolRenderer?.drawChart(lastPoint, curPoint, lastX, curX, size, canvas)
      for each renderer in mSecondaryRendererList:
          renderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas)

  if longPress|tap && !isTrendLine:  drawCrossLine()
  if isTrendLine:                    drawTrendLines()

canvas.restore()
```

### 6.1 MainRenderer

`MainRenderer.drawChart()`:

- `drawPolyline` khi `isLine == true` (line + gradient fill bên dưới).
- `drawCandle` khi `isLine == false`:
  - Thân nến: `canvas.drawRect(open..close)` màu `upColor`/`dnColor`.
  - Bóng nến: line đứng từ `high` đến `low`.
- Sau nến, gọi từng `MainIndicator.drawChart(lastPoint, curPoint, lastX, curX,
  getY, canvas, chartColors)` → MA/BOLL/EMA/SAR/ZigZag overlay trên nến.

#### 6.1.1 Vẽ nến

- Dùng `curPoint.high/low/open/close` để tính `top/bottom`.
- Vẽ thân (rect) + bóng (line) bằng `canvas.drawRect` / `drawLine`.
- Màu: `chartColors.upColor` khi `close >= open`, ngược lại `dnColor`.

#### 6.1.2 Vẽ đường (line chart)

- `Path` + `cubicTo` nối điểm `close`.
- Fill path bằng gradient `kLineFillColors`, stroke `kLineColor`.

#### 6.1.3 Vẽ MA / BOLL / EMA

- Chạy qua `MainIndicator.drawChart(getY, ...)` cho mỗi indicator trong
  `mainIndicators`. Mỗi indicator quản lý paint + màu riêng từ
  `indicatorStyle`.

---

## 7. Vẽ volume

Volume có **renderer riêng** (`VolRenderer extends BaseChartRenderer<VolumeEntity>`)
vẽ vào `mVolRect`. Toggle bằng cờ `volHidden`:

```dart
KChartWidget(
  data, chartStyle, chartColors,
  volHidden: false,    // bật panel vol
  secondaryIndicators: [MACDIndicator()],
)
```

`VolRenderer.drawChart(lastPoint, curPoint, lastX, curX, size, canvas)`:

- Bar: `canvas.drawRect(curX - r, getY(vol), curX + r, chartRect.bottom)`,
  màu `chartColors.volUpColor`/`volDnColor`, alpha = `chartStyle.volBarOpacity`
  (default 1.0 = đặc, set thấp hơn để cột mờ).
- MA5 line: `drawLine(MA5Volume, MA5Volume, ...)`, màu `chartColors.ma5Color`.
- MA10 line: tương tự `MA10Volume`, màu `chartColors.ma10Color`.
- `getY` của `VolRenderer` override: `(max - v) * (height / max) + top` —
  giả định min = 0, cột vol luôn neo đáy panel.

`MA5Volume`/`MA10Volume` được `DataUtil.calcVolumeMA(data)` tính sẵn — gọi
qua `DataUtil.calculateAll(data, mainIndicators, secondaryIndicators)` mỗi khi
data đổi.

**Tách scope với scaleY:** mặc dù `VolRenderer` chạy ngay sau `mMainRenderer`,
nó nằm **ngoài** `canvas.scale(1, scaleY)` của main → panel vol không bị giãn
khi user zoom dọc nến. Đây là điểm bổ sung so với chart_plush.md gốc (gốc
không có scaleY).

---

## 8. Vẽ secondary indicator

`SecondaryRenderer.drawChart()` chỉ là wrapper, gọi
`indicator.drawChart(getY: getY, ...)`. Mỗi indicator tự vẽ:

- **VOL**: bars + MA5/MA10 line (xem mục 7).
- **MACD**: thanh MACD (rect tô đặc/stroke theo trend) + đường `dif`, `dea`.
- **KDJ**: 3 đường `k`, `d`, `j` màu khác nhau.
- **RSI**: đường `rsi`.
- **WR**: đường `r` (Williams %R, giá trị âm).
- **CCI**: đường `cci`.
- **OBV**: đường `obv` + signal MA (`obvSignal`).

Mỗi indicator có `IndicatorStyle` con (`MACDStyle`, `KDJStyle`, `OBVStyle`, …)
chứa color overrides + line width.

---

## 9. Vẽ nền và lưới

`ChartPainter.drawBg(canvas, size)`:

- **Skip nếu `skipBg == true`** (khi có `backgroundLogo` → canvas trong suốt,
  background được render bằng `ColoredBox` layer dưới).
- Vẽ `mMainRect` band + `mVolRect` band (nếu có) + mỗi `mSecondaryRect` band +
  `mDateRect` bằng `chartColors.bgColor`.

`drawGrid()` gọi:

- `mMainRenderer.drawGrid(canvas, mGridRows, mGridColumns)`.
- `mVolRenderer?.drawGrid(...)` — đường đáy panel vol + cột dọc.
- Mỗi `SecondaryRenderer.drawGrid(...)` — đường đáy + cột dọc theo `gridColumns`.

---

## 10. Vẽ text hiển thị

### 10.1 Giá trị trục dọc

- `mMainRenderer.drawVerticalText`: max/min ở cạnh phải `mMainRect`, vị trí
  theo `verticalTextAlignment` (`left`/`right`).
- `mVolRenderer?.drawVerticalText`: chỉ hiển thị max (compact) ở góc phải
  panel — min = 0 nên skip để không đè đường lưới đáy.
- Mỗi `SecondaryRenderer.drawVerticalText`: gọi
  `indicator.drawVerticalText(chartRect, maxValue, minValue, …)` →
  hiển thị max + min ở góc trên-phải / dưới-phải panel.

### 10.2 Ngày giờ dưới đáy

`drawDate()`:

- Lặp `i = 0..mGridColumns`, tính `translateX = xToTranslateX(columnSpace*i)`.
- Nếu nằm trong `[startX, stopX]`, lấy `indexOfTranslateX(translateX)` và format
  `datas[index].time` theo `mFormats` (auto theo khoảng cách 2 nến hoặc
  `chartStyle.dateTimeFormat` override).

### 10.3 Thông tin MA/indicator dòng trên cùng

`drawText(canvas, getItem(mStopIndex), chartStyle.space)`:

- Khi long-press/tap: thay `data` bằng `getItem(calculateSelectedX(selectX))`
  (nến tại crosshair).
- `mMainRenderer.drawText()` → label MA/BOLL/EMA trên đầu `mMainRect`.
- `mVolRenderer?.drawText()` → label `VOL: 1.23K  MA5: 1.5K  MA10: 1.8K`
  trên đầu `mVolRect`.
- Mỗi `SecondaryRenderer.drawText()` → label panel (vd MACD: `MACD(12,26,9)
  MACD:… DIF:… DEA:…`).

> **Khác chart_plush.md gốc:** label dùng `getItem(mStopIndex)` (nến phải nhất
> đang hiển thị) thay vì `datas!.last` cố định. Khi user scroll sang trái, label
> cập nhật theo nến hiển thị, không kẹt ở nến cuối.

---

## 11. Tương tác và crosshair

`KChartWidget` xử lý tap, drag, scale, long press, pointer tracking:

### 11.1 Trục X (scroll + zoom)

- **Horizontal drag (1 ngón)**: `mScrollX += dx / scaleX`, clamp
  `[0, maxScrollX]`. Trigger `onLoadMore(true)` khi `mScrollX >= 0.8 * maxScrollX`.
- **Pinch (2 ngón)**: `mScaleX = lastScale * details.scale`, clamp
  `[minScale, maxScale]`.
- **Fling**: animate `mScrollX` theo velocity sau khi thả tay (ngoại trừ khi
  drag bắt đầu trong tap mode để di chuyển crosshair).

### 11.2 Trục Y (zoom dọc + pan dọc) — chỉ áp cho main

- **ScaleY gesture**: 1 ngón drag dọc trong vùng `Positioned` bên phải (width =
  `effectiveRightPaddingPx`) → `mScaleY -= delta * 0.005`, clamp `[0.3, 5.0]`.
- **Pan Y**: chỉ active khi `mScaleY != 1.0`. `mOffsetY += dy`, clamp
  `|offsetY| ≤ baseHeight × scaleY / 2` (50% rule).
- **Overscroll handoff**: phần `dy` vượt clamp emit qua
  `onVerticalOverscroll(delta)` → parent forward sang outer `ScrollController`
  (negate dấu, dùng `jumpTo` để bypass physics).
- **Double-tap vùng phải**: reset `mScaleY = 1.0`, `mOffsetY = 0.0`.

### 11.2.1 Gesture gate theo vùng — vol/secondary không di chuyển nến

**Vấn đề:** Trước đây `GestureDetector` của `KChartWidget` bọc toàn bộ stack
(`mMainRect` + `mVolRect` + `mSecondaryRectList` + `mDateRect`). Mọi drag bất
kể chạm vào panel nào đều update `mScrollX` / `mOffsetY` → kéo trên vol panel
cũng kéo nến đi theo. Khi chart được nhúng trong list cuộn (vd page có
Order Book / form trade), user kỳ vọng drag trên vol/MACD/RSI cuộn list,
không phải xê dịch chart.

**Giải pháp:** Gate gesture bằng vị trí touch start. Chỉ khi điểm chạm xuất
phát trong `mMainRect`, chart mới xử lý scroll/scale. Ngoài ra forward
`dy` cho outer scroll.

#### State

```dart
// true khi gesture bắt đầu TRONG mMainRect. Khi false (vol/secondary/date),
// chart không xử lý scroll/scale — forward delta Y cho outer scroll qua
// `onVerticalOverscroll`, parent tự quyết định cuộn theo.
bool _gestureInMain = true;
```

#### Lifecycle

```dart
onScaleStart: (details) {
  // ... existing logic (isScale, _stopAnimation, _isScaleYGesture …)
  _gestureInMain = painter.isInMainRect(details.localFocalPoint);
},

onScaleUpdate: (details) {
  // Touch ngoài main + 1 ngón: chỉ chặn pan Y, vẫn cho scroll X.
  //   - dx → scrollX nến (giống main)
  //   - dy → forward outer scroll (KHÔNG pan chart Y)
  // Pinch (≥2 ngón) đi xuống nhánh dưới → scaleX bình thường.
  if (!_gestureInMain && details.pointerCount < 2) {
    isOnTap = false;
    mScrollX = (mScrollX + details.focalPointDelta.dx / mScaleX)
        .clamp(0.0, ChartPainter.maxScrollX)
        .toDouble();
    final dy = details.focalPointDelta.dy;
    if (dy != 0 && widget.onVerticalOverscroll != null) {
      widget.onVerticalOverscroll!(dy);
    }
    if (!widget.isLoadingMore &&
        widget.onLoadMore != null &&
        ChartPainter.maxScrollX > 0 &&
        mScrollX >= ChartPainter.maxScrollX * 0.8) {
      widget.onLoadMore!(true);
    }
    notifyChanged();
    return;
  }
  // ... existing logic (scaleY zone, pinch, scroll X, pan Y, …)
},

onScaleEnd: (details) {
  // fling X cho mọi drag scroll thường, kể cả từ vol/secondary
  // (vì 1-ngón drag ở đó cũng update mScrollX).
  if (!_dragStartedInTapMode) {
    _onFling(details.velocity.pixelsPerSecond.dx);
  }
  _dragStartedInTapMode = false;
  _gestureInMain = true;   // reset cho gesture kế tiếp
},
```

#### Decision tree khi user drag

```
Finger chạm xuống
│
├─ Trong mMainRect ?
│   ├─ YES → _gestureInMain = true
│   │   └─ onScaleUpdate xử lý bình thường:
│   │       ├─ 2 ngón tay      → pinch scaleX
│   │       ├─ 1 ngón vùng phải → scaleY (zoom dọc)
│   │       ├─ 1 ngón crosshair → di chuyển selectX
│   │       └─ 1 ngón drag tự do → scrollX (+ pan Y nếu scaleY≠1)
│   │   onScaleEnd
│   │       └─ fling X theo velocity (nếu không phải crosshair drag)
│   │
│   └─ NO (vol / secondary / date) → _gestureInMain = false
│       └─ onScaleUpdate phân nhánh theo pointerCount:
│           ├─ pointerCount ≥ 2 (pinch) →
│           │   ★ vẫn xử lý scaleX bình thường (như drag trong main)
│           │   → user pinch trên vol/secondary vẫn zoom chart ngang
│           │
│           └─ pointerCount == 1 (drag 1 ngón) →
│               ├─ dx → scrollX nến (như drag trong main)
│               ├─ dy → forward onVerticalOverscroll (KHÔNG pan chart Y)
│               ├─ chart KHÔNG đổi mScaleX/mScaleY/mOffsetY
│               └─ vẫn trigger onLoadMore khi scroll X đạt 80%
│       onScaleEnd
│           └─ fling X bình thường (vẫn chạy cho drag từ vol/secondary)
```

**Tóm gọn:** vol/secondary chỉ chặn duy nhất **pan Y**. Mọi thao tác khác
(scroll X, fling X, pinch scaleX, lazy load) vẫn hoạt động.

#### Vùng chính xác

`painter.isInMainRect(point)` chỉ test `mMainRect.contains(point)`:

```dart
bool isInMainRect(Offset point) => mMainRect.contains(point);
```

Layout (xem mục 3):

```
┌─────────────────────────────────────────────────────────┐
│  mMainRect          ★ full chart gestures               │ ← scroll/pan/pinch
├─────────────────────────────────────────────────────────┤
│  mVolRect           ◐ scroll X + pinch | outer scroll Y │
├─────────────────────────────────────────────────────────┤
│  mSecondaryRect[0]  ◐ scroll X + pinch | outer scroll Y │
├─────────────────────────────────────────────────────────┤
│  mSecondaryRect[1]  ◐ scroll X + pinch | outer scroll Y │
├─────────────────────────────────────────────────────────┤
│  mDateRect          ◐ scroll X + pinch | outer scroll Y │
└─────────────────────────────────────────────────────────┘
```

Ngoài `mMainRect`: tách rạch giữa **X (chart)** và **Y (outer scroll)**.
Pan Y của chart bị chặn riêng để không xung đột với outer scroll.

#### Tương tác với physics của outer scroll

Example tham khảo set physics theo state `_scaleYActive && _pointerOnChart`:

```dart
SingleChildScrollView(
  controller: _outerScrollController,
  physics: (_scaleYActive && _pointerOnChart)
      ? const NeverScrollableScrollPhysics()  // khoá outer khi chart focused
      : const ClampingScrollPhysics(),
  ...
)
```

Khi user touch vol/secondary, có 2 case:

1. **Chưa từng kích hoạt scaleY** → `_scaleYActive == false` → physics =
   `ClampingScrollPhysics` → outer scroll bằng cả gesture tự nhiên (Flutter
   propagate vertical gesture lên parent qua gesture arena) **lẫn**
   `jumpTo` từ `onVerticalOverscroll`. Cả 2 cùng đẩy parent → có thể double.
   Thực tế gesture của chart đã giành arena trước (vì `GestureDetector` ngoài
   cùng) → tự nhiên không propagate; chỉ `jumpTo` là kênh duy nhất.

2. **Đã scaleY → `_scaleYActive == true` & `_pointerOnChart`** → physics =
   `NeverScrollableScrollPhysics` → outer khoá hoàn toàn với gesture native.
   Nhưng `jumpTo` **bypass physics**, vẫn cuộn được → list ngoài cuộn theo
   `dy` được forward từ chart.

Kết luận: dùng `jumpTo` là quan trọng — đảm bảo outer cuộn bất kể state
physics, không cần đổi physics khi user chạm vol/secondary.

#### Hành vi không bị ảnh hưởng

- **Tap** (`onTapUp`) đã có check `painter.isInMainRect(details.localPosition)`
  trước khi toggle crosshair → tap vol/secondary không hiện crosshair, đã
  đúng từ trước.
- **Long press** (`onLongPressStart`) hiện vẫn set `isLongPress = true` ở mọi
  vị trí — vì long press chỉ hiển thị crosshair (info), không di chuyển chart.
  Có thể gate bằng `isInMainRect` nếu cần, nhưng UX thông dụng là cho phép
  long press ở vol/secondary để inspect candle tương ứng.
- **Scroll X**: 1-ngón drag ngang ở vol/secondary vẫn cuộn nến — user kỳ vọng
  drag X bất cứ đâu trong chart đều cuộn timeline.
- **Fling X**: vẫn chạy sau scroll X từ vol/secondary để có momentum tự nhiên
  khi user vuốt nhanh.
- **Lazy load**: vol/secondary drag X vẫn trigger `onLoadMore(true)` khi
  `mScrollX >= maxScrollX * 0.8`.
- **Pinch scaleX**: 2-ngón pinch bất cứ đâu (kể cả vol/secondary) đều zoom
  được chart ngang.

#### Edge cases

- **Drag chéo từ main sang vol**: `onScaleStart` đã chốt `_gestureInMain`
  theo điểm bắt đầu. Nếu start trong main thì cả sequence được xử lý như
  drag chart (gồm scroll X + pan Y nếu scaleY≠1), kể cả khi finger lướt
  sang vol giữa chừng — đúng UX (gesture thuộc về vùng bắt đầu).
- **Drag chéo từ vol sang main**: start ngoài main → vẫn áp dụng nhánh
  vol/secondary: scroll X qua dx, forward dy. Finger lướt vào main không
  giành lại pan Y, tránh giật chart.
- **Pinch 2 ngón trên vol**: `localFocalPoint` ngoài main → `_gestureInMain =
  false`. Nhưng `pointerCount >= 2` nên bypass không kích hoạt — pinch vẫn
  xử lý scaleX bình thường ở nhánh `details.scale != 1.0`.
- **Pinch 1 ngón main + 1 ngón vol**: focalPoint nằm giữa 2 ngón. `_gestureInMain`
  set theo focalPoint nhưng `pointerCount >= 2` nên vẫn pinch bình thường.
- **Drag chéo (dx + dy lớn) ở vol/secondary**: chart cuộn X theo dx, đồng
  thời outer scroll Y theo dy. Cả 2 chuyển động xảy ra song song — user thấy
  nến lướt ngang đồng thời list cuộn dọc, phản ánh đúng gesture chéo.
- **Drag X nhanh ở vol rồi nhả**: `onScaleEnd` không skip fling nữa →
  nến tiếp tục trượt theo momentum như drag từ main.

### 11.3 Crosshair / Trend line

- **Tap (`isTapShowInfoDialog: true`)**: tap lần 1 hiện crosshair, tap lần 2 ẩn.
- **Long press**: cố định cross line tại vị trí ngón tay, drag → di chuyển.
- **Trend line mode (`isTrendLine: true`)**: tap 2 điểm liên tiếp để vẽ
  `TrendLine(p1, p2)`. State giữ trong `lines: List<TrendLine>`.

`ChartPainter` vẽ:

- `drawCrossLine`: đường dash ngang/dọc + dot tại nến chọn.
- `drawCrossLineText`: box giá (close của nến) bên trái/phải tuỳ vị trí,
  box ngày trong `mDateRect`. Emit `InfoWindowEntity` qua `sink` →
  `KChartWidget` build popup bằng `detailBuilder`.
- `drawTrendLines`: nối các điểm trong `lines` bằng `canvas.drawLine`.

---

## 12. Depth chart (độ sâu)

`DepthChartPainter` standalone, không kế thừa `BaseChartPainter`.

```dart
DepthChart(
  bids, asks, chartColors, {
  baseUnit = 2,                       // decimal cho amount
  quoteUnit = 6,                      // decimal cho price
  offset = const Offset(8, 0),
  chartTranslations,
  chartStyle,
  backgroundLogo,                     // ★ watermark Widget?
  backgroundLogoOpacity = 1,          // ★ 0.0–1.0
  bottomLabelCount = 5,               // ★ số mốc giá ở trục dưới (>=2)
})
```

`DepthChartPainter.paint(canvas, size)`:

- `drawBuy`: path xanh nửa trái, `quadraticBezierTo` nối điểm.
- `drawSell`: path đỏ nửa phải.
- `drawText`:
  - 4 mốc volume bên phải.
  - **`bottomLabelCount` mốc giá ở trục dưới** (vòng lặp, nội suy tuyến tính
    từng đoạn quanh `centerPrice = (bids.last.price + asks.first.price) / 2`):

    ```dart
    for (int i = 0; i < n; i++) {
      final t = i / (n - 1);       // 0..1
      final x = t * mWidth;
      final price = t <= 0.5
          ? startPrice + (centerPrice - startPrice) * (t * 2)
          : centerPrice + (endPrice - centerPrice) * ((t - 0.5) * 2);
      // align: i=0 trái, i=n-1 phải, giữa center quanh x (clamp)
    }
    ```

  - Crosshair popup (`price` + `amount`) khi `isLongPress`.

Watermark `backgroundLogo`: khi != null, `build` bọc `CustomPaint` trong `Stack`
với logo `Center` + `IgnorePointer` ở dưới, chart vẽ chồng lên trên.

> **Khác chart_plush.md gốc:** thêm `backgroundLogo`, `backgroundLogoOpacity`,
> `bottomLabelCount`. Mốc giá ở trục dưới không còn hardcode 5.

---

## 13. Hướng dẫn cho source khác

Nếu muốn làm theo kiến trúc này, tách rõ thành 3 lớp chính:

1. **Widget** quản lý tương tác và trạng thái (gesture, scaleX/scaleY,
   scrollX/offsetY, selectX/Y, lines).
2. **Painter chung** điều phối:
   - tính toán vùng hiển thị (`mStartIndex..mStopIndex`),
   - xác định max/min cho main + từng secondary panel,
   - chia layout (main → date → secondary list),
   - vẽ background, grid, ngày giờ, text chung.
3. **Renderer riêng** từng phần:
   - `MainRenderer` cho nến + main indicators,
   - `VolRenderer` cho panel volume (bars + MA),
   - `SecondaryRenderer` cho mỗi panel indicator phụ
     (macd/kdj/rsi/wr/cci/obv… đều dùng chung lớp này).

### Các điểm cần kế thừa

- **Mỗi `KEntity` phải có đủ field** cho mọi indicator (mix nhiều mixin).
- **Tính `max/min` chỉ trên vùng visible**, không trên toàn dataset.
- **Dùng canvas transform** cho scroll/zoom:
  - `scaleX + translate` áp cho cả frame.
  - `scaleY + translate` áp riêng cho main (centerY anchor + offsetY pan).
- **Secondary indicators luôn vẽ ngoài `scaleY` transform** để không bị giãn.
- **Mọi label vẽ ngoài transform** qua helper `_applyScaleY`.
- **Volume có rect riêng (`mVolRect`)**, không phải overlay trong main và
  cũng không phải secondary indicator — toggle bằng cờ `volHidden`.
- **Mixin type system**: cho mọi secondary dùng cùng generic `T`
  (project này dùng `MACDEntity` mix `on` OBV+KDJ+RSI+WR+CCI) để
  `List<SecondaryIndicator<T, _>>` chứa được tất cả.
- **Pan Y clamp 50%** + **overscroll handoff** để chart sống cùng outer scroll.
- **Lazy load**: trigger `onLoadMore(true)` ở 80% maxScrollX, guard bằng
  `isLoadingMore`. Sau khi prepend data nhớ `DataUtil.calculateAll` lại.

---

## 14. Tổng kết

Mô hình này ưu tiên:

- **Tách biệt rõ trách nhiệm** giữa widget (state), painter (layout +
  orchestration), renderer (draw).
- **Tối ưu dữ liệu visible** bằng `mStartIndex` / `mStopIndex`.
- **3 renderer độc lập** khớp với sơ đồ đơn giản của `chart_plush.md`:
  `MainRenderer` + `VolRenderer` + `SecondaryRenderer`.
- **Hỗ trợ zoom/scroll cả 2 trục** + chọn điểm data trực tiếp +
  watermark logo + lazy load + overscroll handoff với outer scroll.

Với tài liệu này, source khác có thể tham khảo cách chia vùng, tính giá trị
và vẽ theo từng bước — phản ánh đúng nguồn hiện tại của `k_chart_wikex`.
