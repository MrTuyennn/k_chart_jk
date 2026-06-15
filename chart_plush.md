# Chart Plush Documentation

## 1. Tổng quan kiến trúc

Mã nguồn chart được thiết kế theo mô hình:

- `KChartWidget`: widget chứa, xử lý tương tác và tạo `ChartPainter`.
- `ChartPainter`: lớp vẽ chính, kế thừa `BaseChartPainter`.
- `BaseChartPainter`: xử lý layout, phạm vi dữ liệu, chế độ hiển thị, và điều phối vẽ.
- `MainRenderer`: vẽ đồ thị chính (nến hoặc đường giá), MA, BOLL.
- `VolRenderer`: vẽ đồ thị volume.
- `SecondaryRenderer`: vẽ indicator phụ như MACD/KDJ/RSI/WR/CCI.
- `DepthChartPainter`: vẽ đồ thị độ sâu (depth chart) riêng.

> **Ghi chú quan trọng:** toàn bộ chart chính của `KChartWidget` được vẽ trong một `CustomPaint` duy nhất. `KChartWidget` tạo ra `ChartPainter`, và `ChartPainter` quản lý một canvas chung, sau đó sử dụng các renderer nội bộ để vẽ từng phần trong cùng một hộp vẽ.
>
> - `KChartWidget` = widget chứa và điều khiển tương tác.
> - `ChartPainter` = painter duy nhất gắn vào `CustomPaint`.
> - `MainRenderer`, `VolRenderer`, `SecondaryRenderer` = lớp hỗ trợ vẽ nội bộ, không phải widget riêng.
>
> Như vậy, bạn có thể hình dung đây là một “box” duy nhất với 3 vùng con (`main`, `volume`, `secondary`) do `ChartPainter` chia và vẽ.
>
> ## Cách hiểu chi tiết
>
> 1. `KChartWidget` nhận dữ liệu và trạng thái cấu hình từ bên ngoài.
> 2. Trong `build()`, `KChartWidget` tạo `ChartPainter` với:
>    - `datas`, `scaleX`, `scrollX`, `selectX`.
>    - `mainState`, `secondaryState`, `volHidden`, `isLine`.
>    - `chartStyle`, `chartColors`, `xFrontPadding`.
> 3. `CustomPaint` sử dụng `ChartPainter` làm painter duy nhất.
> 4. Flutter gọi `ChartPainter.paint(canvas, size)` để vẽ toàn bộ chart vào một canvas.
> 5. `BaseChartPainter.paint()` làm:
>    - cắt vùng vẽ bằng `canvas.clipRect(...)`.
>    - tính `mDisplayHeight` và `mWidth`.
>    - gọi `initRect(size)` để chia `mMainRect`, `mVolRect`, `mSecondaryRect`.
>    - gọi `calculateValue()` để:
>      - tính `maxScrollX` và `mTranslateX`.
>      - xác định `mStartIndex`, `mStopIndex` cho dữ liệu hiển thị.
>      - tính `mMainMaxValue`, `mMainMinValue`, `mVolMaxValue`, `mVolMinValue`, `mSecondaryMaxValue`, `mSecondaryMinValue` chỉ trên dữ liệu hiển thị.
>    - gọi `initChartRenderer()` để tạo:
>      - `MainRenderer`, `VolRenderer`, `SecondaryRenderer` với các rect và giá trị tính được.
>    - vẽ nền (`drawBg`) và lưới (`drawGrid`).
>    - nếu có dữ liệu, gọi `drawChart()`.
> 6. Trong `ChartPainter.drawChart()`:
>    - dịch và scale toàn bộ canvas theo `scrollX` và `scaleX`.
>    - lặp qua chỉ số dữ liệu từ `mStartIndex` đến `mStopIndex`.
>    - với mỗi điểm, gọi:
>      - `mMainRenderer.drawChart(...)`
>      - `mVolRenderer?.drawChart(...)`
>      - `mSecondaryRenderer?.drawChart(...)`
>    - sau vòng lặp, nếu cần vẽ crosshair hoặc trendline thì vẽ thêm.
> 7. Sau `drawChart()`, `BaseChartPainter.paint()` tiếp tục vẽ:
>    - `drawVerticalText(canvas)` cho các trục cạnh phải.
>    - `drawDate(canvas, size)` cho ngày ở đáy.
>    - `drawText(canvas, datas!.last, 5)` để hiển thị label MA/MACD...
>    - `drawMaxAndMin(canvas)` và `drawNowPrice(canvas)`.
>    - `drawCrossLineText(canvas, size)` nếu đang chọn dữ liệu.
>
> ## Sơ đồ đơn giản
>
> KChartWidget
> └─ CustomPaint(chartPainter)
> └─ ChartPainter.paint()
> ├─ initRect()
> ├─ calculateValue()
> ├─ initChartRenderer()
> ├─ drawBg()
> ├─ drawGrid()
> ├─ drawChart()
> │ ├─ translate/scale canvas
> │ ├─ loop indices
> │ │ ├─ MainRenderer.drawChart()
> │ │ ├─ VolRenderer.drawChart()
> │ │ └─ SecondaryRenderer.drawChart()
> │ └─ draw crossline/trendline
> ├─ drawVerticalText()
> ├─ drawDate()
> └─ draw info text/max/min/now price
>
> ## Quy tắc quan trọng để viết lại ở source khác
>
> - Giữ nguyên nguyên tắc: widget quản lý trạng thái, painter vẽ toàn bộ.
> - Chia layout bằng các `Rect` riêng, đừng tạo nhiều widget canvas con.
> - Tính giá trị hiển thị chỉ dựa trên vùng dữ liệu hiện tại (mStartIndex..mStopIndex).
> - Biến `scrollX` và `scaleX` thành phép biến đổi canvas, không vẽ từng phần bằng tay.
> - Mỗi renderer chỉ chịu trách nhiệm vẽ trong vùng của nó, dùng `chartRect` và `scaleY` riêng.
>
> Với ghi chú này, AI khác có thể đọc và hiểu rõ luồng xử lý, rồi tái tạo lại kiến trúc tương đương.

## 2. Luồng dữ liệu và tham số chính

### 2.1 Dữ liệu đầu vào

Dữ liệu chính là danh sách `KLineEntity` được truyền vào `KChartWidget`.
Các giá trị quan trọng:

- `time`: thời điểm
- `open`, `high`, `low`, `close`
- `vol`, `MA5Volume`, `MA10Volume`
- `maValueList`, `dif`, `dea`, `macd`, `k`, `d`, `j`, `rsi`, `cci`, `wr`...

### 2.2 Cấu hình hiển thị

Các tham số cấu hình chính:

- `scaleX`: tỷ lệ zoom theo trục X.
- `scrollX`: giá trị scroll ngang.
- `isLine`: chuyển giữa biểu đồ đường và nến.
- `mainState`: `MA`, `BOLL`, `NONE`.
- `secondaryState`: `MACD`, `KDJ`, `RSI`, `WR`, `CCI`, `NONE`.
- `volHidden`: ẩn hiện vùng volume.
- `hideGrid`: ẩn lưới.
- `xFrontPadding`: đệm bên phải sau nến cuối (px tại chart ≥375px). Chart hẹp hơn tự co qua `BaseChartPainter.effectiveRightPaddingPx`; đồng bộ vùng gesture scaleY.

## 3. Cách chia vùng và tính toán layout

`BaseChartPainter.initRect(size)` chịu trách nhiệm chia bố cục:

- `mMainRect`: vùng đồ thị chính.
- `mVolRect`: vùng volume nếu `volHidden == false`.
- `mSecondaryRect`: vùng indicator phụ nếu `secondaryState != NONE`.

Chiều cao mỗi vùng được tính linh hoạt dựa trên tổng chiều cao khả dụng và phần padding.

## 4. Tính toán giá trị hiển thị

`BaseChartPainter.calculateValue()` làm các công việc:

- Xác định `maxScrollX` và thiết lập `mTranslateX` từ `scrollX`.
- Tìm chỉ số bắt đầu/kết thúc hiển thị (`mStartIndex`, `mStopIndex`) bằng `indexOfTranslateX`.
- Duyệt dữ liệu trong vùng hiển thị để tính:
  - `mMainMaxValue`, `mMainMinValue`
  - `mVolMaxValue`, `mVolMinValue`
  - `mSecondaryMaxValue`, `mSecondaryMinValue`

### 4.1 Tính `main` range

- Với `MA`: so sánh `high/low` và các giá trị MA.
- Với `BOLL`: so sánh `up`, `dn`, `high`, `low`.
- Với đường giá: dùng `close`.

### 4.2 Tính `vol` range

- So sánh `vol`, `MA5Volume`, `MA10Volume`.
- `mVolMinValue` tính từ `min(mVolMinValue, item.vol)` (data thực tế, không hardcode 0). Dùng để render label min ở góc dưới-phải panel vol; scale cột vol vẫn neo đáy panel.

### 4.3 Tính `secondary` range

Tùy theo `secondaryState` mà lấy max/min từ:

- MACD: `macd`, `dif`, `dea`
- KDJ: `k`, `d`, `j`
- RSI/WR/CCI: sử dụng giá trị tương ứng

## 5. Chuyển đổi toạ độ & hiển thị dữ liệu

### 5.1 Tính toán tọa độ X

`BaseChartPainter.getX(index)` tạo điểm X dựa trên số lượng dữ liệu và `pointWidth`.

`xToTranslateX(x)` chuyển từ toạ độ canvas sang toạ độ dữ liệu đã dịch chuyển.

`indexOfTranslateX(translateX)` dùng tìm kiếm nhị phân để tìm chỉ số dữ liệu gần với toạ độ X.

### 5.2 Tính toán tọa độ Y

`BaseChartRenderer.getY(y)` quy đổi giá trị dữ liệu thành toạ độ Y trong vùng:

- Dựa trên `maxValue`, `minValue`, `scaleY`, và `chartRect.top`.

## 6. Vẽ chart chính

`ChartPainter.drawChart(canvas, size)` thực hiện:

- `canvas.save()` / `canvas.translate(mTranslateX * scaleX, 0)` / `canvas.scale(scaleX, 1)`
- Duyệt `i` từ `mStartIndex` tới `mStopIndex`.
- Gọi lần lượt:
  - `mMainRenderer.drawChart(...)`
  - `mVolRenderer?.drawChart(...)`
  - `mSecondaryRenderer?.drawChart(...)`

### 6.1 MainRenderer

`MainRenderer.drawChart()` vẽ:

- `drawPolyline` khi `isLine == true`.
- `drawCandle` và sau đó `drawMaLine` hoặc `drawBollLine` khi `isLine == false`.

#### 6.1.1 Vẽ nến

- Dùng `curPoint.high`, `low`, `open`, `close` để tính toạ độ.
- Vẽ thân nến và bóng nến bằng `canvas.drawRect`.
- Màu `upColor` khi giá tăng, `dnColor` khi giá giảm.

#### 6.1.2 Vẽ đường

- Dùng `Path` và `cubicTo` để nối các điểm giá đóng cửa.
- Vẽ cả bóng nền (`fill path`) và đường trên cùng.

#### 6.1.3 Vẽ MA / BOLL

- `drawMaLine`: vẽ các đường MA theo `maDayList`.
- `drawBollLine`: vẽ `up`, `mb`, `dn`.

## 7. Vẽ volume

`VolRenderer.drawChart()` thực hiện:

- Vẽ thanh volume màu `upColor` hoặc `dnColor`.
- Vẽ đường MA volume `MA5Volume` và `MA10Volume`.

## 8. Vẽ secondary indicator

`SecondaryRenderer.drawChart()` vẽ:

- `MACD`: thanh MACD + đường `dif`/`dea`.
- `KDJ`: 3 đường `k`, `d`, `j`.
- `RSI`, `WR`, `CCI`: đường tương ứng.

## 9. Vẽ nền và lưới

`ChartPainter.drawBg()` vẽ gradient nền cho mỗi vùng.

`drawGrid()` gọi renderer tương ứng để vẽ lưới:

- `MainRenderer.drawGrid`
- `VolRenderer.drawGrid`
- `SecondaryRenderer.drawGrid`

## 10. Vẽ text hiển thị

### 10.1 Giá trị trục dọc

- `drawVerticalText()` vẽ giá trị min/max trong mỗi vùng.
- `MainRenderer` và `SecondaryRenderer` vẽ text ở cạnh phải.
- `VolRenderer` vẽ text max volume.

### 10.2 Ngày giờ dưới đáy

`drawDate()` phân phối ngày theo `mGridColumns`.

- Lấy chỉ số dữ liệu gần với vị trí date line.
- Format theo `time` của dữ liệu.

### 10.3 Thông tin MA / indicator dòng trên cùng

- `MainRenderer.drawText()` hiển thị MA/BOLL label.
- `VolRenderer.drawText()` hiển thị VOL và MA volume.
- `SecondaryRenderer.drawText()` hiển thị MACD/KDJ/RSI/WR/CCI text.

## 11. Tương tác và crosshair

`KChartWidget` xử lý: tap, drag, scale, long press.

- Horizontal drag thay đổi `mScrollX`.
- Pinch zoom thay đổi `mScaleX`.
- Tap/long press cập nhật `mSelectX` và bật hiển thị crossline.

`ChartPainter` sẽ vẽ:

- Cross line khi `isLongPress == true` hoặc `isTapShowInfoDialog && isOnTap`.
- Thông tin dữ liệu tương ứng với vị trí chọn.

## 12. Depth chart (độ sâu)

`DepthChartPainter` là một painter riêng, không dùng `BaseChartPainter`.

- Chia nửa trái/phải cho `bids` và `asks`.
- Vẽ đường mua bán bằng `quadraticBezierTo`.
- Vẽ path fill màu dưới đường.
- Hiển thị giá trị khi long press.

## 13. Hướng dẫn cho source khác

Nếu muốn làm theo kiến trúc này, hãy tách rõ thành 3 lớp chính:

1. Widget quản lý tương tác và trạng thái.
2. Painter chung điều phối:
   - tính toán vùng hiển thị
   - xác định max/min
   - chia layout
   - vẽ background, grid, ngày giờ, text chung.
3. Renderer riêng từng phần:
   - main chart
   - volume
   - secondary indicator

### Các điểm cần kế thừa

- Dữ liệu trước hết phải được xử lý sao cho mỗi item có đủ trường cần thiết.
- Tính toán `max/min` chỉ trên vùng dữ liệu hiển thị.
- Dùng `scaleX` và `scrollX` để zoom/scroll bằng cách dịch canvas.
- Vẽ nến, đường và path với toạ độ Y tính từ `maxValue/minValue`.
- Vẽ lưới và text trong cùng một luồng `paint()`.
- Sử dụng `CustomPainter` cho hiệu năng vẽ cao.

## 14. Tổng kết

Mô hình này ưu tiên:

- tách biệt rõ trách nhiệm giữa layout và rendering,
- tối ưu dữ liệu nhìn thấy bằng `mStartIndex` / `mStopIndex`,
- tái sử dụng renderer cho các phần khác nhau,
- hỗ trợ zoom/scroll và chọn điểm data trực tiếp.

Với tài liệu này, source khác có thể tham khảo cách chia vùng, tính toán giá trị và vẽ theo từng bước.

---

## Bổ sung từ `k_chart_wikex` (source thực tế)

Các điểm source `k_chart_wikex` bổ sung/thay đổi so với kiến trúc gốc mô tả ở doc này:

| Tính năng | Mô tả ngắn |
|---|---|
| `scaleY` + `offsetY` transform | Zoom dọc + pan dọc chỉ áp cho `mMainRect`; vol/secondary nằm ngoài |
| `KChartScaleState` | Class lưu/khôi phục `scaleX/scaleY/scrollX`; callback `onChartScaleChanged` |
| `onLoadMore` khi `maxScrollX = 0` | Trigger load thêm ngay cả khi data vừa màn hình (không scroll được) |
| Min vol label | `mVolMinValue` từ data thực, label min ở góc dưới-phải panel vol |
| Multi-select secondary | `secondaryIndicators: List<SecondaryIndicator>` thay enum đơn |
| Gesture gate | Vol/secondary chặn pan Y, forward outer scroll; scroll X + pinch vẫn hoạt động |
| Pan Y clamp 50% + overscroll handoff | `|offsetY| ≤ baseHeight × scaleY / 2`; delta vượt biên emit qua `onVerticalOverscroll` |
| `backgroundLogo` watermark | Widget overlay giữa `mMainRect`, `IgnorePointer` |

Chi tiết từng mục xem `chart_wikex.md` (thay đổi gần đây) và `chart_wikex_arch.md`.
