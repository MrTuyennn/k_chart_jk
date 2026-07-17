# Release Notes

Tổng hợp toàn bộ thay đổi/fix của package: nội dung từ `CHANGELOG.md` (theo version publish), các commit `fix:` lẻ chưa lên CHANGELOG, và các thay đổi đang làm việc (chưa commit) trong session gần đây.

## 2026-07-17

### Fixed — 4 bug correctness phát hiện qua `/code-review` high effort (8 finder angle + verify)

- **KDJ: null-check dùng `||` thay vì `&&`**: `KDJIndicator.drawChart` vẽ đường K/D/J khi `curPoint.k != null || lastPoint.k != null` rồi force-unwrap cả 2 điểm bằng `!` — nếu 1 trong 2 null (vd nến mới append từ tick live chưa kịp `calc()` lại) thì crash `Null check operator used on a null value`, sập cả painter. Sửa: đổi `||` → `&&`, chỉ vẽ khi CẢ 2 điểm đều đã có giá trị — khớp đúng pattern mọi secondary indicator khác (RSI/WR/MTM/TRIX/StochRSI) đã dùng.
  - File: `lib/indicator/secondary/kdj_indicator.dart`
- **SAR: chấm SAR không đọc `indicatorStyle`, hard-code màu theo `candleStyle` của main chart**: `SARIndicator.drawChart` tự tính màu chấm từ `candleStyle.upColor`/`dnColor`/`defaultTextColor`, bỏ qua hẳn `indicatorStyle` — set màu qua `KChartColors.sarStyle` chỉ đổi được label `"SAR: ..."`, không đổi được chấm (khác mọi indicator khác, tự đọc `indicatorStyle.xxxColor` cho cả đường vẽ lẫn label). Sửa: `SARStyle` đổi field `sarColor` (1 màu cố định) thành `upColor`/`dnColor` (theo đúng convention `SuperTrendStyle`) — chấm VÀ label giờ cùng tự chọn màu theo xu hướng thật của SAR (`sar <= (high+low)/2` = tăng → `upColor`, ngược lại → `dnColor`), không còn phụ thuộc `candleStyle`.
  - File: `lib/indicator/main/sar_indicator.dart`, `lib/indicator/indicator_style.dart`, `example/lib/main.dart` (`_demoColors`)
- **`LivePriceStyle.textStyle` không fallback màu khi user không tự set `color`**: `drawNowPrice` build `TextPainter` thẳng từ `chartColors.livePriceStyle.textStyle`, không qua guard "dùng `textStyle.color` nếu đã set, không thì fallback" như 5 chỗ khác trong codebase — set `LivePriceStyle(textStyle: TextStyle(fontSize: 12))` (không kèm `color`) sẽ ra chữ màu đen mặc định của `TextPainter`, gần như vô hình trên nền badge màu `upColor`/`dnColor`. Sửa: dùng chung helper `resolveTextStyle(...)` (xem mục cleanup bên dưới), fallback về `Colors.white`.
  - File: `lib/renderer/chart_painter.dart`
- **Alpha bị ghi đè thay vì nhân dồn — còn sót ở 2 renderer khác sau fix hôm 07-16**: bug cùng lớp với `VolRenderer` (đã fix 07-16) vẫn còn nguyên ở `MainRenderer` (`chartColors.bgColor.withAlpha(80)` cho nền label indicator) và `SecondaryRenderer` (`chartColors.defaultTextColor.withAlpha(90)` cho đường tham chiếu nét đứt) — set alpha thẳng trong `Color` bị `.withAlpha()` ghi đè vô điều kiện. Sửa cả 2 theo đúng pattern đã áp cho volume: `color.withValues(alpha: color.a * factor)`.
  - File: `lib/renderer/main_renderer.dart`, `lib/renderer/secondary_renderer.dart`

### Improved (cleanup/efficiency — cùng đợt code review)

- **Gom logic "fallback màu textStyle" thành 1 helper dùng chung**: cùng 1 đoạn `textStyle.color != null ? textStyle : textStyle.copyWith(color: fallback)` (kèm biến thể `forceColor`) từng lặp lại độc lập ở 6 chỗ/5 file với chữ ký khác nhau (positional/named `forceColor`). Rút thành `resolveTextStyle(base, fallback, {forceColor})`.
  - File: `lib/utils/text_style_util.dart` (mới), áp dụng ở `lib/renderer/chart_painter.dart`, `vol_renderer.dart`, `secondary_renderer.dart`, `lib/indicator/indicator_template.dart`, `lib/depth_chart.dart` (2 chỗ)
- **Thay cơ chế `identical()` phát hiện "indicator còn dùng style mặc định" bằng cờ tường minh**: `identical(indicatorStyle, const XxxStyle())` không phân biệt được "caller không truyền gì" với "caller chủ động truyền `const XxxStyle()` y hệt default" (Dart const-canonicalization khiến 2 trường hợp không thể phân biệt) — trường hợp sau bị nhận nhầm là "chưa customize" và bị `KChartColors` ghi đè ngoài ý muốn. Sửa: đổi constructor cả 16 indicator sang nhận `XxxStyle?` (nullable, mặc định `null`), thêm field `isDefaultStyle` (= `indicatorStyle == null`) tường minh thay `identical()`.
  - File: `lib/indicator/indicator_template.dart` + 16 file `lib/indicator/{main,secondary}/*.dart`
- **`forceColor` đổi từ positional bool sang named param**: `getTextStyle(color, style, true)` — tham số bool cuối không tên, phải nhớ đúng vị trí, dễ chép sai khi copy giữa 16 file indicator gần giống nhau. Đổi sang `getTextStyle(color, base: style, forceColor: true)`.
  - File: `lib/indicator/indicator_template.dart` + ~30 call site trong `lib/indicator/{main,secondary}/*.dart`
- **`LivePriceBadgePainter` cache `Paint`/`Path` thành `static`**: trước đó dựng mới 2 `Paint` + 1 `Path` mỗi lần `paint()` — chạy mỗi frame theo tick giá live (không throttle). Đổi sang `static final`, chỉ đổi `.color` mỗi lần vẽ.
  - File: `lib/styles/live_price_style.dart`
- **`applyIndicatorColorStyles()` thêm cache theo `identical()` của tham số đầu vào**: hàm này chạy lại mỗi lần `ChartPainter` được dựng (mỗi build/tick giá) dù `mainIndicators`/`secondaryIndicators`/`chartColors` thường không đổi giữa các lần gọi liên tiếp — bỏ qua hoàn toàn khi cả 3 vẫn `identical` với lần gọi trước.
  - File: `lib/indicator/indicator_template.dart`

### Fixed — lint `library_private_types_in_public_api`

- `DepthChart.createState()` trả về kiểu private `_DepthChartState` trong API public — đổi return type sang `State<DepthChart>` (public), theo đúng gợi ý của lint (và đúng pattern đã áp dụng từ commit `c1d04f8` cho chính widget này trước đây — có lẽ bị lệch lại qua refactor sau này).
  - File: `lib/depth_chart.dart`

---

## 2026-07-16

### Feat — `LivePriceStyle` + `LivePriceBadgePainter` (now-price badge)

Tách `nowPriceUpColor`/`nowPriceDnColor` khỏi `KChartColors` thành model riêng `LivePriceStyle` (`lib/styles/live_price_style.dart`), cùng convention `CandleStyle`/`VolumeStyle` dựng hôm 07-15. `upColor`/`dnColor` CHỈ tô nền badge + đường kẻ ngang — màu CHỮ luôn lấy từ `textStyle.color` riêng (mặc định `Colors.white`), không dùng chung màu nền cho chữ (nền đặc + chữ cùng màu sẽ vô hình — bug phát hiện ngay khi wiring).

Badge "flag" (nền bo góc + mũi tên nhỏ trỏ trái) — convert từ `assets/Number.svg` (`viewBox="0 0 54 14"`) — gắn thẳng vào `ChartPainter.drawNowPrice()` thay `RRect + border` phẳng cũ (gọi trực tiếp `LivePriceBadgePainter(...).paint(canvas, size)`, không qua widget `CustomPaint`). Nền và mũi tên cùng nhân 1 cặp tỉ lệ `scaleX = size.width/54`, `scaleY = size.height/14` — bug ban đầu: chỉ nền được scale theo tỉ lệ SVG, mũi tên để nguyên toạ độ tuyệt đối copy từ path SVG → lệch khi badge không đúng 54×14 (phát hiện khi so trực tiếp với `assets/Number.svg` gốc, biết viewBox thật mới tính đúng hệ số quy đổi). Badge tự co giãn đúng tỉ lệ theo độ dài số giá. Mũi tên trỏ trái khớp đúng ngữ nghĩa khi badge ở mép PHẢI chart (`VerticalTextAlignment.right`, mặc định); dùng `left` thì mũi tên trỏ ra ngoài thay vì vào chart (hạn chế asset gốc — chỉ 1 chiều, chưa có bản mirror).

Padding badge (`drawNowPrice`) đổi `(paddingX: 3, paddingY: 1.5)` → `(5, 3)`. Kéo theo xoá 2 field thừa `nowPriceSelectorPaint`/`nowPriceSelectorBorderPaint` trên `ChartPainter`.

- File: `lib/styles/live_price_style.dart` (mới), `lib/renderer/chart_painter.dart`

### Feat — `textStyle` riêng từng indicator style

Thêm field `textStyle` (default `fontSize: 10`) vào base class `IndicatorStyle`, forward qua `super.textStyle` ở cả 15 subclass (`MAStyle`, `BOLLStyle`, `SARStyle`, `SuperTrendStyle`, `AVLStyle`, `ZigZagStyle`, `MACDStyle`, `KDJStyle`, `RSIStyle`, `WRStyle`, `CCIStyle`, `OBVStyle`, `TRIXStyle`, `MTMStyle`, `StochRSIStyle`). Label mỗi indicator giờ chỉnh font độc lập nhau qua `KChartColors.xxxStyle.textStyle`, thay vì dùng chung `candleStyle.textStyle` như bản fix hôm 07-15.

- File: `lib/indicator/indicator_style.dart`, `lib/indicator/indicator_template.dart` + 16 file `lib/indicator/{main,secondary}/*.dart`

### Fixed — volume bar opacity bị ghi đè thay vì nhân dồn

`VolRenderer.drawChart` dùng `base.withValues(alpha: chartStyle.volBarOpacity)` — **ghi đè hoàn toàn** alpha sẵn có của `volumeStyle.upColor`/`dnColor`. Set alpha thẳng trong `Color` (vd `Color(0x8076FF03)`) bị bỏ qua nếu `volBarOpacity` giữ default `1.0`. Sửa: `base.withValues(alpha: base.a * chartStyle.volBarOpacity)` — nhân dồn, set qua `Color` hoặc `volBarOpacity` đều dùng được, kết hợp được cả hai.

- File: `lib/renderer/vol_renderer.dart`

### Fixed — `textStyle.color` tự set bị ghi đè vô điều kiện (5 chỗ)

Set `color` trong `textStyle` (vd `CandleStyle(textStyle: TextStyle(color: Colors.amber))`) không có tác dụng — `getTextStyle()`/`getTextPainter()` ở cả 5 nơi đều gọi `.copyWith(color: mauNguQuNghia)` **vô điều kiện**, ghi đè `textStyle.color` bằng `defaultTextColor`/`crossTextColor`/`maxColor`/`indicatorStyle.xxxColor`/`annotationColor` tuỳ chỗ gọi. Sửa: chỉ `copyWith(color: ...)` khi `textStyle.color == null` (chưa tự set); nếu người dùng đã set thì dùng nguyên `textStyle`, bỏ qua màu ngữ nghĩa truyền vào. Không set `color` (mặc định) → hành vi giữ nguyên như cũ, không breaking.

- File: `lib/renderer/chart_painter.dart` (`candleStyle.textStyle`), `lib/renderer/vol_renderer.dart` (`volumeStyle.textStyle`), `lib/indicator/indicator_template.dart` (`indicatorStyle.textStyle`, dùng chung cho cả 16 indicator), `lib/depth_chart.dart` (`chartStyle.textStyle` + `annotationTextStyle`)

---

## 2026-07-15

### Breaking — `KChartColors`/`KChartStyle` refactor toàn bộ

Gom màu/text rời rạc thành style theo khu vực, cho phép cấu hình màu indicator từ 1 chỗ duy nhất. Chi tiết đầy đủ: `chart_jk_arch.md` §1 Unreleased + §8.2.

- **`CandleStyle`/`VolumeStyle`** thay `kLineColor`, `kLineFillColors`, `upColor`, `dnColor`, `volColor` (xoá — dead field), `volUpColor`, `volDnColor`, `ma5Color`, `ma10Color` — mỗi class tự chứa cả màu lẫn `textStyle` riêng.
- **16 field style indicator** (`avlStyle`, `maStyle`, `rsiStyle`, `macdStyle`...) thêm vào `KChartColors` — set màu toàn bộ indicator từ 1 nơi, cơ chế `applyIndicatorColorStyles()` tự áp cho instance nào chưa tự custom `indicatorStyle`.
- `KChartColors.copyWith()` — method mới.
- File: `lib/styles/k_chart_style.dart`, `lib/indicator/indicator_style.dart`, `lib/indicator/indicator_template.dart`, `lib/renderer/*.dart`.

### Fixed — 5 bug correctness (phát hiện qua `/code-review` high effort)

- **`AVLIndicator`/`ZigZagIndicator`/`BOLLIndicator._fillPaint`**: Paint màu bake 1 lần trong constructor từ `indicatorStyle`, không đọc lại khi vẽ → set màu qua `KChartColors` không có tác dụng lên đường/vùng tô (chỉ đổi được label). Sửa: đọc lại `indicatorStyle.xxxColor` ngay trước mỗi lần vẽ.
  - File: `lib/indicator/main/avl_indicator.dart`, `zigzag_indicator.dart`, `boll_indicator.dart`
- **`applyIndicatorColorStyles()` "đơ" màu sau lần áp đầu tiên**: dùng `identical(indicatorStyle, const XxxStyle())` để biết "còn default không" — sau khi tự gán 1 lần, field không còn `identical` với default → các lần build sau (vd đổi theme runtime) không bao giờ áp lại màu mới nếu app giữ indicator instance ổn định qua nhiều build. Sửa: thêm `_originalIndicatorStyle` (snapshot bất biến chụp lúc khởi tạo), so `identical()` với snapshot thay vì giá trị hiện tại.
  - File: `lib/indicator/indicator_template.dart`
- **`VolumeStyle.textStyle` không áp cho label trục volume**: `ChartPainter.drawVerticalText` tính chung 1 `textStyle` (từ `candleStyle.textStyle`) rồi truyền cho cả main lẫn volume renderer. Sửa: gọi riêng `mVolRenderer.getTextStyle(...)`.
  - File: `lib/renderer/chart_painter.dart`
- **Label indicator không đổi font theo `KChartColors`**: `IndicatorTemplate.getTextStyle` hard-code `fontSize: 10`. Sửa: nhận thêm param `base`, mọi `drawFigure()` (16 file) truyền `chartColors.candleStyle.textStyle` vào (sau nâng cấp tiếp thành `indicatorStyle.textStyle` riêng từng indicator, xem mục 07-16).
  - File: `lib/indicator/indicator_template.dart` + 16 file `lib/indicator/{main,secondary}/*.dart`

### Improved (cleanup — non-correctness, cùng đợt code review)

- `KChartColors.copyWith()` — override 1-2 field giữ nguyên phần còn lại.
- `applyIndicatorColorStyles()` gộp switch 16 case lặp code thành 1 helper generic `_applyDefaultStyle<K>()` — rút từ ~90 dòng còn ~45.
- `DepthChartStyle` thêm `textStyle`/`annotationTextStyle` (default fontSize 10/9) — cùng convention `CandleStyle`/`VolumeStyle`, thay hard-code fontSize trong `depth_chart.dart`.
- `example/lib/main.dart`: cache `_mainIndicatorsFor`/`_secondaryIndicatorsFor` theo nội dung `Set` — trước đó mỗi tick `livePrice` (WS, không throttle) kéo theo rebuild lại toàn bộ 15 indicator + Paint dù `mainTypes`/`secondaryTypes` không đổi.

---

## 2026-07-09

### Fixed

- **Main Indicator hỗ trợ chọn nhiều (multi-select), giống Secondary Indicator**
  - Trước đây `_MainType` chỉ chọn được 1 loại tại 1 thời điểm (`_mainType` là single enum, có giá trị `none`).
  - Đổi sang `Set<_MainType> _mainTypes` — có thể bật đồng thời nhiều indicator (MA, BOLL, EMA, SuperTrend, ZigZag, AVL) cùng lúc trên chart, tương tự cách `_secondaryTypes` hoạt động.
  - Bỏ giá trị `none` khỏi enum — bỏ chọn hết chip tương đương "không có main indicator".
  - Đổi `_setMain(type)` → `_toggleMain(type)`, cập nhật getter `_mainIndicators` và toàn bộ chip UI trong section "Main Indicator".
  - File: `example/lib/main.dart`

- **Lỗi compile: `Undefined name '_mainType'`**
  - Nguyên nhân: sau khi đổi sang `_mainTypes` (Set), phần chip UI "Main Indicator" chưa được cập nhật đồng bộ, vẫn còn gọi `_mainType == _MainType.x` / `_setMain(...)` (API cũ đã bị xoá).
  - Đã sửa toàn bộ chip sang dùng `_mainTypes.contains(...)` / `_toggleMain(...)`.

### Investigated — chưa merge (đã revert theo yêu cầu)

- **Tối ưu live-tick bằng `livePrice`** (tách giá tick khỏi `_data`, tránh gọi `DataUtil.calculateAll` ở mỗi tick trong cùng 1 nến — chỉ recalc khi nến thực sự đóng).
  - Lý do đề xuất: đo bằng Flutter DevTools Performance Overlay cho thấy khi `_tickInterval` giảm xuống 50ms, `_updateLastCandle` vẫn gọi `DataUtil.calculateAll` (full O(n) recalc toàn bộ indicator trên cả lịch sử `_data`) ở **mọi tick**, kể cả tick intra-candle → jank (~13ms) lặp lại rất thường xuyên, dù FPS trung bình vẫn báo ~106fps (số trung bình che mất phần giật thực tế).
  - Đã implement (thêm field `_livePrice`, `KChartWidget(livePrice: _livePrice)`, chỉ gọi `calculateAll` trong `_addNewCandle` khi nến đóng) nhưng bị revert theo yêu cầu — chưa rõ lý do không đạt, cần thêm thông tin để làm lại đúng hướng.
  - `_updateLastCandle` hiện vẫn giữ nguyên hành vi cũ (recalc toàn bộ mỗi tick).

### Performance review (ghi nhận, không phải code fix)

- `_tickInterval = 250ms`: không cạnh tranh trực tiếp với khung hình 60fps vì `Timer.periodic` tách biệt với frame scheduler của Flutter — rủi ro thật nằm ở việc `DataUtil.calculateAll` chạy full O(n) trên toàn bộ `_data` (không tăng dần theo lịch sử) mỗi khi bị gọi.
- Đo trên thiết bị màn 120Hz: 117fps trung bình, chỉ 1 jank spike trong ~3.2s (khớp đúng chu kỳ đóng nến 2.5s = `_ticksPerCandle × _tickInterval`) — chấp nhận được.
- Khi giảm `_tickInterval` xuống 50ms (trong khi `_updateLastCandle` vẫn full-recalc mỗi tick): 106fps trung bình nhưng jank (~13ms) lặp lại dày đặc hơn hẳn — minh hoạ rằng số FPS trung bình có thể gây hiểu lầm, cần xem trực tiếp timeline (Timeline Events) để đánh giá đúng mức độ giật.

## 2026-07-08

_Ngày suy ra từ mtime file (thay đổi chưa commit tại thời điểm ghi chú này), không phải từ git log._

### Fixed

- **AVL Indicator: sửa công thức tính sai bản chất**
  - Trước: cumulative VWAP — `Σ(typicalPrice × vol) / Σ(vol)` cộng dồn từ nến đầu tiên (giá trị bị kéo dài/trôi theo toàn bộ lịch sử, không phản ánh đúng từng nến).
  - Sau: per-candle average — `avl = amount / vol` tính riêng cho từng nến; fallback `(H+L+C)/3` khi thiếu `amount` (luôn nằm trong range high-low của nến).
  - Mở rộng điều kiện fallback: coi `amount <= 0` (không chỉ `amount == null`) cũng là dữ liệu không đáng tin khi `vol > 0`, vì amount thật phải dương nếu đã có khớp lệnh.
  - File: `lib/entity/avl_entity.dart`, `lib/indicator/main/avl_indicator.dart`, `chart_jk_arch.md`

- **StochRSI: fix RSI sai khi thị trường đi ngang tuyệt đối**
  - Trước: `avgGain == 0 && avgLoss == 0` (không tăng cũng không giảm) bị tính là `avgLoss == 0` → RSI = 100 (overbought giả).
  - Sau: tách riêng case này → RSI = 50 (neutral), đúng bản chất thị trường đi ngang.
  - File: `lib/indicator/secondary/stoch_rsi_indicator.dart`

- **StochRSI: bỏ ép cứng range 20/80 trùng lặp**
  - `getMaxMinValue` không còn tự `min(minV, 20.0)` / `max(maxV, 80.0)` — logic bao range theo `referenceValues` được chuyển lên xử lý chung ở `BaseChartPainter` (xem mục renderer bên dưới), tránh mỗi indicator phải tự chép lại.
  - File: `lib/indicator/secondary/stoch_rsi_indicator.dart`

### Improved (renderer pipeline)

- **`getSecondaryMaxMinValue` tự động bao `indicator.referenceValues` vào min/max range** — bất kỳ secondary indicator nào khai báo `referenceValues` (đường tham chiếu ngang, vd 20/80 của StochRSI) đều tự động được đảm bảo hiển thị đủ trong panel, không cần tự ép range trong `getMaxMinValue()` của từng indicator.
  - File: `lib/renderer/base_chart_painter.dart`

- **`drawReferenceLines` gate bởi `hideGrid`** — coi đường tham chiếu ngang nét đứt là một dạng lưới nền, ẩn/hiện đồng bộ với `drawGrid`.
  - File: `lib/renderer/chart_painter.dart`

- **Tối ưu vẽ đường tham chiếu**: gom toàn bộ đoạn nét đứt vào 1 `Path`, vẽ 1 lần bằng `canvas.drawPath()` thay vì hàng chục/hàng trăm lệnh `canvas.drawLine()` riêng lẻ mỗi frame — giảm tải canvas.
  - File: `lib/renderer/secondary_renderer.dart`

- **`drawReferenceLines` trở thành method ảo trên `BaseChartRenderer`** (trước chỉ tồn tại ở `SecondaryRenderer`) — cho phép renderer khác cũng implement đường tham chiếu riêng nếu cần. `mSecondaryRendererList` đổi kiểu từ `Set<SecondaryRenderer>` sang `Set<BaseChartRenderer>` để phù hợp.
  - File: `lib/renderer/base_chart_renderer.dart`, `lib/renderer/chart_painter.dart`

---

## Lịch sử phiên bản (copy từ `CHANGELOG.md`)

> Nội dung dưới đây copy nguyên văn từ `CHANGELOG.md` tại thời điểm ghi chú này (2026-07-09). Nếu `CHANGELOG.md` được cập nhật sau này, 2 file có thể lệch nhau — coi `CHANGELOG.md` là nguồn chính thức.

### 1.0.3

* **feat:** New secondary indicator `StochRSIIndicator` (StochRSI) — Stochastic RSI oscillator, `calcParams: [n1, n2, m1, m2]` (default `14, 14, 3, 3`: RSI period, Stoch period, %K smoothing, %D smoothing). Computes an internal Wilder-smoothed RSI (independent of `RSIIndicator` so it works even when RSI isn't enabled), then `StochRSI = (RSI - min(RSI, n2)) / (max(RSI, n2) - min(RSI, n2)) × 100`, `%K = SMA(StochRSI, m1)`, `%D = SMA(%K, m2)`. Draws the %K/%D line pair (`StochRSIStyle.kColor`/`dColor`) plus fixed 20/80 dashed reference lines, with the panel's min/max range always widened to include 20 and 80 so the reference lines never clip.
* **feat:** New main indicator `AVLIndicator` (AVL) — average value line, no period parameter. Plots the average execution price of each candle, `AVL = amount / vol` (quote volume ÷ base volume), falling back to typical price `(high + low + close) / 3` when `amount` is missing or zero, so the line always tracks inside the candle body like Binance's AVL. Styled via `AVLStyle.avlColor`.
* **feat:** New secondary indicator `MTMIndicator` (MTM) — momentum oscillator, `calcParams: [n, m]` (default `12, 6`: momentum period, signal MA period). `MTM = close - close[n bars ago]`, `MTMMA = MA(MTM, m)`. Draws the MTM/MTMMA line pair via `MTMStyle.mtmColor`/`mtmMaColor`, following the same `SecondaryIndicator` structure as MACD/TRIX.

### 1.0.2

* **feat:** New main indicator `SuperTrendIndicator` (SUPER) — an ATR-based trend line (Wilder's smoothing), `calcParams: [period, multiplier*10]`, direction (`isUp`) derived from the final upper/lower band, colored via `upColor`/`dnColor`. Also draws a shaded fill (`upFillColor`/`dnFillColor` on `SuperTrendStyle`) between the SuperTrend line and the close price to highlight the trend region, instead of just a single line.
* **feat:** New secondary indicator `TRIXIndicator` (TRIX) — a triple-smoothed EMA rate-of-change oscillator, `calcParams: [12, 20]` (triple-EMA period, signal MA period). Draws the TRIX/MATRIX line pair (`TRIXStyle.trixColor`/`trixMaColor`) in the secondary panel, following the same `SecondaryIndicator` structure as MACD/RSI.

### 1.0.1

* **fix:** `onLoadMore(true)` was never called when the initial data (or data after a previous load) didn't fill the chart's width (`ChartPainter.maxScrollX <= 0`) and the user hadn't performed any gesture yet. Previously `onLoadMore` only triggered from `onScaleUpdate`/`onScaleEnd`/fling, so a chart rendering fewer candles than its viewport width would sit stuck indefinitely. Added `_maybeLoadMoreForNarrowData()`, called from `initState`/`didUpdateWidget` (via `addPostFrameCallback` to wait for `ChartPainter.maxScrollX` to update after paint), guarded by `_narrowLoadRequestedForLength` so `onLoadMore` isn't re-fired on every rebuild unrelated to `datas` (style/theme changes, etc.).
* **docs:** Fixed doc comments that produced `dartdoc` warnings: the generic type `List<SecondaryIndicator<MACDEntity, dynamic>>` was being parsed as an HTML tag, and `[0]`/`[i]`/`[i-1]`/`[scaleX]` were being parsed as unresolved doc-reference links.

### 1.0.0

* **feat:** `KChartScaleState` — a class to save/restore zoom state (`scaleX`, `scaleY`, `scrollX`). Passed through `KChartWidget.chartScale` to restore when switching timeframes; `scaleX` is auto-clamped to `minScale`/`maxScale`. The `onChartScaleChanged` callback (`OnChartScaleChanged`) fires after a pinch ends, a scaleY drag, a zoom-controller action, or a double-tap scaleY reset.
* **fix:** `onLoadMore(true)` wasn't called when scale was small enough that all data fit within the viewport (`maxScrollX == 0`). Removed the `ChartPainter.maxScrollX > 0` guard and added a post-frame callback in `onScaleEnd` to trigger loading more data after a pinch zoom-out.
* **feat:** The volume panel now shows a minimum-value label (min volume in the visible range) in the bottom-right corner, mirroring how MACD shows its min. `mVolMinValue` is no longer hardcoded to `0` and is now computed from the actual data.

### 0.0.1

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

---

## Các commit `fix:` lẻ khác (git log, chưa có trong `CHANGELOG.md`)

> Commit message gốc chỉ có 1 dòng subject, không có body. Nội dung dưới đây đọc trực tiếp từ diff (`git show <hash>`) để ghi chi tiết thật.

### 2026-05-19 — `63d636b` fix: lazy load data

Trước đó `onLoadMore(true)` (load thêm data lịch sử) chỉ được gọi khi animation fling cuộn tới đúng `mScrollX <= 0` (tức phải fling hết cỡ chạm biên trái). Thêm check trực tiếp trong `onScaleUpdate`/`onScaleEnd`: bắn `onLoadMore(true)` ngay khi `mScrollX >= maxScrollX * 0.8` (đã cuộn 80% về phía nến cũ) — load chủ động trước khi user chạm đáy, không cần chờ fling xong. Thêm param `isLoadingMore` vào `KChartWidget` để chặn gọi trùng khi đang fetch dở.
File: `lib/k_chart_widget.dart`

### 2026-05-19 — `c1d04f8` fix: remove warning

Dọn lint `flutter analyze` trên ~20 file: thêm `{}` cho `if` 1 dòng, bỏ `this.` thừa, đổi `KLineEntity` từ field `late` gán sau sang constructor param bắt buộc, đổi enum `TimeFormat.YEAR_MONTH_DAY_WITH_HOUR` → `yearMonthDayWithHour` (chuẩn lowerCamelCase), thêm `const`/`super.key` cho `DepthChart`, đổi kiểu trả về `createState()` từ private `_DepthChartState` sang `State<DepthChart>` public. Không đổi hành vi.

### 2026-05-19 — `3c99c2d` fix: scale chart

Đổi kiến trúc scaleY: trước đó scale bằng cách co giãn range min/max giá trị đưa vào `MainRenderer` (làm sai lệch cách tính label trục giá, gắn chặt zoom-Y vào logic tính range indicator). Sau: scaleY áp dụng qua **canvas transform** (`canvas.translate` + `canvas.scale(1.0, scaleY)` quanh tâm `mMainRect`), có `canvas.clipRect` để nội dung scale không tràn ra time bar/secondary panel. Secondary indicator giờ vẽ ở vòng lặp **riêng, ngoài** transform này — pinch-zoom-Y chỉ ảnh hưởng nến/volume chính, không ảnh hưởng RSI/MACD/...
Volume panel gộp làm overlay đè lên 20% dưới của main chart thay vì panel riêng bên dưới (bỏ khoảng `mChildPadding` + nền riêng). Thêm helper `_applyScaleY()` để các label vẽ ngoài canvas transform (label max/min giá, đường livePrice) căn đúng vị trí theo nến đã scale.
File: `lib/k_chart_widget.dart`, `lib/renderer/base_chart_painter.dart`, `lib/renderer/chart_painter.dart`, `lib/renderer/main_renderer.dart`, `lib/renderer/vol_renderer.dart`

### 2026-05-23 — `e259e0a` fix: scroll scaleY chart

Nối tiếp `3c99c2d`: label trục giá (`MainRenderer.drawVerticalText`) vẫn tính theo range giá trị **trước khi** transform, nên sau khi pinch đổi scaleY thì label giá in ra không còn khớp vị trí nến thật render. Sửa bằng cách truyền `externalScaleY`/`scaleCenterY` vào `MainRenderer` và đảo ngược transform khi map vị trí Y của mỗi grid row về giá trị giá.
File: `lib/renderer/chart_painter.dart`, `lib/renderer/main_renderer.dart`

### 2026-05-27 — `1865875` fix: add OBVEntity in MACDEnity

`MACDEntity` mixin mở rộng `on` clause để bắt buộc thêm `OBVEntity` (`mixin MACDEntity on KDJEntity, RSIEntity, WREntity, CCIEntity, OBVEntity`) — để bất kỳ entity nào dựng trên `MACDEntity` truy cập được `.obv`/`.obvSignal` trực tiếp, không cần cast.
Đây cũng là commit gốc thêm `_liveChip()` — tính năng mô phỏng tick real-time (`Timer.periodic`) trong `example/lib/main.dart` mà cả session vừa rồi mình liên tục chỉnh sửa.
File: `example/lib/main.dart`, `lib/entity/macd_entity.dart`

### 2026-05-27 — `a23ded7` fix: add obv

Sửa bug thứ tự mixin phát sinh từ commit trước: `KEntity` khai `MACDEntity` **trước** `OBVEntity`, nhưng `MACDEntity on ... OBVEntity` đòi hỏi `OBVEntity` phải đứng trước theo thứ tự linearization của Dart — đổi lại thành `..., OBVEntity, MACDEntity, ZigZagEntity`.
`OBVIndicator` đổi generic type từ `SecondaryIndicator<OBVEntity, OBVStyle>` sang `SecondaryIndicator<MACDEntity, OBVStyle>`, nhất quán với cách RSI/KDJ/WR/CCI khai kiểu, tránh phải cast vì mixin chain đã đảm bảo `MACDEntity` có sẵn field OBV.
File: `lib/entity/k_entity.dart`, `lib/indicator/secondary/obv_indicator.dart`

### 2026-06-06 — `0f0e2b8` fix: auto reset scroll

Thêm `KChartWidget.didUpdateWidget` → `_compensateScrollOnDataChange`: khi parent append nến mới (live tick) hoặc prepend nến cũ (lazy-load), `mScrollX` (offset tính từ biên phải) sẽ bị "trôi" vì `getMinTranslateX` tính lại theo độ dài data mới. Fix bù `mScrollX` thêm `diff × pointWidth` khi append để view không bị giật — **trừ** khi user đang ở rightmost (`mScrollX <= 0`), lúc đó cố ý giữ nguyên để chart tự follow nến mới nhất (kiểu UX TradingView/Binance). Prepend nến cũ không cần bù vì `getMinTranslateX` tự đúng.
File: `lib/k_chart_widget.dart`

### 2026-06-06 — `0ed6fed` fix: minScale chart

`KChartWidget.minScale` mặc định nới từ `0.5` → `0.2`, cho phép pinch-zoom-out xa hơn nhiều (nhìn được nhiều nến hơn cùng lúc).
File: `lib/k_chart_widget.dart`

### 2026-06-08 — `4d53e73` fix: add padding when scale chart

Fix `StreamController<InfoWindowEntity?>()` → `.broadcast()`: stream của info-window vốn single-subscription, nên `StreamBuilder` trong info dialog rebuild lại là ném lỗi "Stream has already been listened to."
Vùng gesture scaleY / double-tap-reset ở cạnh phải chart trước đó hardcode cố định `100px`; giờ tính qua `BaseChartPainter.effectiveRightPaddingPx(xFrontPadding, width)` để co giãn theo tỉ lệ, tránh chiếm tỉ lệ quá lớn trên màn hình hẹp.
File: `lib/k_chart_widget.dart`

### 2026-06-12 — `8c9377e` fix: loadmore chart

Cùng nhóm bug với fix `onLoadMore` ở CHANGELOG **1.0.0**: bỏ điều kiện `ChartPainter.maxScrollX > 0` khỏi trigger `onLoadMore` khi scroll/pinch (để vẫn bắn khi đã zoom out tới mức `maxScrollX <= 0` — hết chỗ cuộn thêm để tự trigger), và thêm `WidgetsBinding.instance.addPostFrameCallback` check sau khi kết thúc gesture pinch-zoom-out, vì `maxScrollX` chỉ được cập nhật sau khi `paint()` chạy xong.
File: `lib/k_chart_widget.dart`

### 2026-06-12 — `e5bbbe2` fix: add min volum chart

Cùng nội dung với CHANGELOG **1.0.0** mục "min-volume label": `mVolMinValue` trước đó hardcode `0`; giờ tính `min(mVolMinValue, item.vol)` theo data thực tế đang hiển thị, và `VolRenderer` vẽ thêm label giá trị min ở góc dưới-phải panel volume (giống cách label max/min của MACD).
File: `lib/renderer/base_chart_painter.dart`, `lib/renderer/vol_renderer.dart`

### 2026-07-06 — `5dcd0d8` fix: refactor loadmore candle chart

Cùng nội dung với CHANGELOG **1.0.1**: thêm `_maybeLoadMoreForNarrowData()`, gọi từ `initState`/`didUpdateWidget` qua post-frame callback, để trigger `onLoadMore(true)` khi data **ban đầu** (hoặc mới load) chưa lấp đầy chiều rộng chart và user chưa hề thao tác gì — trước đó `onLoadMore` chỉ bắn từ gesture pan/pinch/fling nên chart hẹp hơn data có thể bị kẹt không bao giờ load thêm. Chặn gọi trùng bằng `_narrowLoadRequestedForLength`.
File: `lib/k_chart_widget.dart`

### Các commit `refactor:`/`feat:` mang nội dung fix hiệu năng/hiển thị (không gắn tag `fix:` nhưng thực chất là sửa lỗi)

### 2026-05-19 — `505145d` feat: reorder chart layout and fix scaleY gesture area

Đổi thứ tự layout panel: main chart → volume → thanh thời gian → secondary indicators (trước đó thanh thời gian nằm **giữa** main chart và volume — layout không hợp lý). Sửa vùng gesture scaleY (`Positioned(... bottom: 0)`) dừng đúng ở đáy `main + volume + secondary` thay vì kéo dài tới tận đáy widget, tránh đè lên vùng label thời gian.
File: `example/lib/main.dart`, `lib/k_chart_widget.dart`, `lib/renderer/base_chart_painter.dart`

### 2026-06-26 — `9f10934` refactor: fix performance chart

**Nguồn gốc thật của `shouldRepaint`**: `BaseChartPainter.shouldRepaint` trước đó chỉ `return true` vô điều kiện — nghĩa là **mọi** lần `CustomPainter` rebuild đều full-repaint bất kể có gì thay đổi hay không. Thay bằng so sánh field thật (`datas`, `scaleX`, `scrollX`, `isLongPress`, `selectX`, `isOnTap`, `offsetY`, `volHidden`, `mainIndicators`, `secondaryIndicators`).
Đưa việc khởi tạo `Paint` (background, trend-line) ra khỏi `paint()`/`drawBg()`, chuyển vào constructor của `ChartPainter` — trước đó cứ mỗi frame lại `new Paint()` mới, 1 anti-pattern hiệu năng kinh điển trong Flutter.
Đây chính là commit gốc của cơ chế `shouldRepaint` được ghi trong project memory (`[[project-live-price]]`).
File: `lib/renderer/base_chart_painter.dart`, `lib/renderer/chart_painter.dart`, `lib/renderer/base_chart_renderer.dart`

### 2026-06-26 — `c14f6fa` refactor: fix render live-price

Thêm `ChartPainter.shouldRepaint` override check `oldDelegate.livePrice != livePrice` — đây chính xác là cơ chế đứng sau pattern `livePrice` (tách giá real-time khỏi `datas`) đã ghi trong project memory.
Đồng thời sửa `DepthChartPainter.shouldRepaint` — cũng bị lỗi `return true` vô điều kiện y hệt main chart — đổi sang so sánh thật trên `mBuyData`/`mSellData`/`isLongPress`/`pressOffset`.
Thêm `scaleY` vào danh sách so sánh của `BaseChartPainter.shouldRepaint` (trước đó thiếu, nên đổi scaleY qua pinch không đảm bảo repaint).
File: `lib/depth_chart.dart`, `lib/renderer/base_chart_painter.dart`, `lib/renderer/chart_painter.dart`

### 2026-07-02 — `a80f2ca` refactor: check perfomance render isLine

Fix tiếp 3 lỗ hổng `shouldRepaint` phát hiện qua code review, có ghi lại đầy đủ trong `chart_jk_arch.md`:
1. `isLine` (toggle nến ↔ line) bị thiếu trong `BaseChartPainter.shouldRepaint` — chuyển đổi loại chart không trigger repaint cho tới khi có field khác đổi kèm.
2. `isTrendLine`/`selectY`/`lines` thiếu trong `ChartPainter.shouldRepaint`. Bug sâu hơn: `lines` (điểm trend line) bị `KChartWidget` **mutate in-place** (`lines.add(...)`) rồi truyền cùng reference vào `ChartPainter` mỗi build → `oldDelegate.lines != lines` không bao giờ đúng (cùng 1 object). Sửa bằng cách (1) truyền snapshot mới `List<TrendLine>.of(lines)` mỗi build, và (2) so sánh `lines` theo giá trị (`_trendLinesEqual`, so từng field) thay vì reference.
3. Cache chuỗi ngày của `getDate()` (`_dateStringCache`) gần như bị clear mỗi frame: so sánh `mFormats` theo identity (`_cacheFormats != mFormats`), nhưng `initFormats()` luôn gán 1 list literal **mới** mỗi lần `ChartPainter` được dựng lại (mỗi build) dù nội dung format không đổi — cache coi như vô dụng. Sửa bằng so sánh theo giá trị (`_formatsEqual`).
- Đây chính là cùng 1 lớp lỗi "mutate in-place → `!=` không bao giờ đúng → shouldRepaint không nhận ra thay đổi" đã ghi trong anti-pattern của `livePrice`/`datas` trong project memory — chỉ khác field.
File: `chart_jk_arch.md`, `lib/k_chart_widget.dart`, `lib/renderer/base_chart_painter.dart`, `lib/renderer/chart_painter.dart`

*Chi tiết từng commit có thể xem bằng `git show <hash>` hoặc `git log -p <hash>^..<hash>`.*
