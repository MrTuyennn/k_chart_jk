# Ichimoku Kinko Hyo — Công thức & Ảnh hưởng Render

## 1. Ký hiệu

- `HH(n)` = giá **cao nhất** trong n nến gần nhất (bao gồm nến hiện tại)
- `LL(n)` = giá **thấp nhất** trong n nến gần nhất (bao gồm nến hiện tại)
- `i` = index nến hiện tại, `n` = tổng số nến

---

## 2. Công thức 5 đường

| Đường | Công thức | Vị trí vẽ |
|---|---|---|
| **Tenkan-sen** (Conversion Line) | `(HH(9) + LL(9)) / 2` | tại nến hiện tại |
| **Kijun-sen** (Base Line) | `(HH(26) + LL(26)) / 2` | tại nến hiện tại |
| **Senkou Span A** (Leading A) | `(Tenkan + Kijun) / 2` | dịch **tới trước 26** nến |
| **Senkou Span B** (Leading B) | `(HH(52) + LL(52)) / 2` | dịch **tới trước 26** nến |
| **Chikou Span** (Lagging) | `Close` | dịch **lùi 26** nến |

**Kumo (mây)** = vùng tô giữa Span A và Span B.

- `Span A > Span B` → mây tăng (thường tô xanh)
- `Span A < Span B` → mây giảm (thường tô đỏ)
- Điểm 2 đường cắt nhau = **Kumo twist**, thường được đánh dấu riêng

### Bộ tham số

| Bộ | Giá trị | Dùng cho |
|---|---|---|
| Cổ điển | 9 / 26 / 52, shift 26 | chứng khoán, forex (gốc Nhật) |
| Crypto | 20 / 60 / 120, shift 30 | thị trường 24/7, không có phiên nghỉ |

> Shift luôn bằng giá trị Kijun period. Nếu cho user chỉnh param thì shift phải đổi theo, đừng hardcode 26.

---

## 3. Warm-up (số nến tối thiểu)

| Đường | Cần tối thiểu |
|---|---|
| Tenkan | 9 nến |
| Kijun | 26 nến |
| Span A | 26 nến (phụ thuộc Kijun) |
| Span B | 52 nến |
| Chikou | 1 nến (nhưng cần 26 nến để có điểm neo) |

→ Chart chưa đủ **52 nến** thì mây chưa vẽ được đầy đủ. Trả `NaN` / `null` cho vùng warm-up thay vì `0`, nếu không sẽ có đường tụt thẳng xuống đáy chart.

---

## 4. Ảnh hưởng tới render

### 4.1 Bố cục index

```
nến:      [0 .................................. n-1]
tenkan:   [0 .................................. n-1]
kijun:    [0 .................................. n-1]
chikou:   [0 ...................... n-27]              ← hụt 26 ở cuối
spanA/B:            [26 .............................. n-1+26]  ← thừa 26
                                          ^n-1        ^vùng tương lai
```

### 4.2 Những điểm phải xử lý

**Mảng dữ liệu**
- Buffer vẽ Span A/B phải có độ dài `n + shift`, không phải `n`
- Chikou có `shift` phần tử cuối là `null` — đừng vẽ nối tới nến cuối

**Trục X / viewport**
- Phải mở rộng thêm `shift` slot trống bên phải, kể cả khi user pan tới cuối chart
- Nếu viewport clamp ở `n-1` thì mây bị cắt cụt ở mép phải — lỗi hay gặp nhất
- Max scroll offset = `(n + shift) * candleWidth`, không phải `n * candleWidth`

**Timestamp vùng tương lai**
- 26 slot đó không có nến, chỉ có timestamp ngoại suy: `lastTime + k * interval`
- Cần cho crosshair / tooltip hiển thị đúng thời gian ở vùng chưa có giá
- Với thị trường có phiên (chứng khoán), phải ngoại suy theo lịch phiên chứ không cộng thẳng interval

**Tính toán Y-axis**
- Min/max giá phải tính cả Span A/B trong vùng tương lai đang hiển thị
- Nếu chỉ scan high/low của nến thì mây sẽ tràn ra ngoài khung

**Realtime update**
- Nến mới đóng → **append** thêm 1 slot tương lai, không chỉ shift mảng
- Nến đang chạy (chưa đóng) làm Tenkan/Kijun thay đổi → Span A tại `i+26` phải tính lại mỗi tick
- Chikou của nến hiện tại ghi vào vị trí `i-26`, tức là **sửa lại vùng quá khứ** mỗi tick

**Hiệu năng**
- Vòng lặp naive là `O(n × 52)` → giật khi pan/zoom trên chart nhiều nến
- Dùng **monotonic deque** cho sliding max/min → `O(n)`
- Cache kết quả, chỉ tính lại phần tử cuối khi có tick mới

**Vẽ mây**
- Phải tách polygon tại điểm Span A/B giao nhau để đổi màu, không thì fill sai màu cả đoạn
- Tính điểm giao bằng nội suy tuyến tính giữa 2 index liền kề

---

## 5. Code Dart

### Helper — trung điểm Donchian

```dart
double _mid(List<Candle> c, int i, int n) {
  final s = i - n + 1;
  if (s < 0) return double.nan;
  var hi = -double.infinity, lo = double.infinity;
  for (var k = s; k <= i; k++) {
    if (c[k].high > hi) hi = c[k].high;
    if (c[k].low  < lo) lo = c[k].low;
  }
  return (hi + lo) / 2;
}
```

### Tính toàn bộ

```dart
class IchimokuResult {
  final List<double> tenkan;   // length n
  final List<double> kijun;    // length n
  final List<double> spanA;    // length n + shift
  final List<double> spanB;    // length n + shift
  final List<double> chikou;   // length n
  const IchimokuResult(this.tenkan, this.kijun, this.spanA, this.spanB, this.chikou);
}

IchimokuResult calcIchimoku(
  List<Candle> c, {
  int tenkanP = 9,
  int kijunP  = 26,
  int spanBP  = 52,
  int shift   = 26,
}) {
  final n = c.length;
  final nan = double.nan;

  final tenkan = List<double>.filled(n, nan);
  final kijun  = List<double>.filled(n, nan);
  final chikou = List<double>.filled(n, nan);
  final spanA  = List<double>.filled(n + shift, nan);
  final spanB  = List<double>.filled(n + shift, nan);

  for (var i = 0; i < n; i++) {
    final t = _mid(c, i, tenkanP);
    final k = _mid(c, i, kijunP);
    tenkan[i] = t;
    kijun[i]  = k;

    // dịch tới trước
    if (!t.isNaN && !k.isNaN) spanA[i + shift] = (t + k) / 2;
    spanB[i + shift] = _mid(c, i, spanBP);

    // dịch lùi
    if (i - shift >= 0) chikou[i - shift] = c[i].close;
  }

  return IchimokuResult(tenkan, kijun, spanA, spanB, chikou);
}
```

### Trục X mở rộng

```dart
int get totalSlots => candles.length + shift;

DateTime timeAt(int index) {
  if (index < candles.length) return candles[index].time;
  final over = index - candles.length + 1;
  return candles.last.time.add(interval * over);   // ngoại suy
}
```

---

## 6. Checklist trước khi ship

- [x] Mây hiển thị đủ 26 nến bên phải nến cuối, không bị cắt
- [x] Pan tới cuối chart vẫn thấy trọn vùng tương lai
- [x] Chikou dừng trước nến cuối 26 slot, không kéo dài tới cuối
- [x] Chart < 52 nến: không vẽ đường rác về 0
- [x] Y-axis auto-scale có tính cả Span A/B vùng tương lai
- [ ] Crosshair ở vùng tương lai hiện đúng timestamp, giá để trống — **không làm** (xem §7, mục 4)
- [x] Đổi param → shift đổi theo
- [x] Pan/zoom mượt trên 5000+ nến (sliding-window O(n), không phải O(n×52))

---

## 7. Đã triển khai trong `k_chart_jk` (Flutter) — ghi chú khác spec

Bản Flutter thật (`lib/indicator/main/ichimoku_indicator.dart` + phần mở rộng dùng chung trong `lib/renderer/base_chart_painter.dart`/`chart_painter.dart`) đi theo đúng công thức ở §1-§5, nhưng khác cách hiện thực hoá §5 (mảng Span A/B dài `n+shift`) ở vài điểm. Chi tiết đầy đủ, trung lập nền tảng (để port sang RN/Android/iOS) nằm ở `architecture.md` §3.5 (cơ chế "vùng tương lai") và §9.1 (mục Ichimoku trong catalogue indicator) — dưới đây chỉ tóm tắt phần khác biệt với tài liệu này:

1. **Không lưu mảng đã dịch sẵn (`spanA[n+shift]`)** — Span A/B/Chikou vẫn lưu 1 giá trị/nến TẠI INDEX TỰ NHIÊN (giống mọi indicator khác trong thư viện, vd `entity.boll`, `entity.sar`), thay vì mảng dài `n+shift` như code mẫu ở §5. Phép dịch `±shift` được áp bằng cách cộng/trừ thẳng `shift * pointWidth` vào toạ độ X **ngay tại draw-time** (`IchimokuIndicator.drawChart`), tận dụng tính tuyến tính của `getX(i) = i*pointWidth + pointWidth/2`. Kết quả số học giống hệt cách tiếp cận mảng-dịch-sẵn, nhưng không phải kéo dài entity/mảng dữ liệu.
2. **Mở rộng trục X là cơ chế dùng chung, không riêng cho Ichimoku** — `MainIndicator.futureShift` (mặc định `0`) là hook chung; renderer tự tính `mFutureSlots = max(futureShift)` và mở rộng `mDataLen`/biên scroll/binary-search theo đó (architecture.md §3.5). Indicator tương lai khác cần dịch trục chỉ việc override `futureShift`, không phải sửa renderer lần nữa.
3. **3 phạm vi index tách biệt** (viewport thô / vùng hiển thị thật / vùng "real" mở rộng cho vẽ) — đây là phần dễ làm sai nhất khi thêm cơ chế này (đã từng bị lẫn lộn ở bản đầu, gây lệch label max/min giá, lệch autoscale trục Y main/volume/secondary, và lệch label chỉ số góc trên khi scroll giữa lịch sử — đều đã fix). Xem giải thích đầy đủ + bảng "dùng phạm vi nào cho việc gì" ở `architecture.md` §3.5.
4. **Crosshair/tap-selection**: cố ý **không** triển khai "chọn được vào vùng tương lai, giá để trống, timestamp vẫn hiện" như liệt kê trong checklist §6 gốc — bị clamp về nến thật đang hiển thị. Đơn giản hoá có chủ đích cho một tương tác biên hiếm dùng; có thể làm sau nếu cần, không ảnh hưởng tới việc mây/5 đường hiển thị đúng.
5. **Ngoại suy timestamp vùng tương lai** (`timeAt()`) dùng khoảng cách 2 nến thật cuối cùng, tuyến tính — đúng cho thị trường 24/7 (crypto), KHÔNG xử lý lịch phiên nghỉ (chứng khoán).
