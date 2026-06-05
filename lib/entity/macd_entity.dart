import 'obv_entity.dart';
import 'cci_entity.dart';
import 'kdj_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';
import 'volume_entity.dart';

// VolumeEntity + OBVEntity được thêm vào `on` clause để MACDEntity có thể
// truy cập .vol / .MA5Volume / .MA10Volume / .obv / .obvSignal trực tiếp —
// cho phép VolIndicator và OBVIndicator dùng MACDEntity làm generic T,
// nhất quán với RSI/KDJ/WR/CCI.
// Thứ tự `on` phải khớp thứ tự mixin trong KEntity.
mixin MACDEntity
    on KDJEntity, RSIEntity, WREntity, CCIEntity, VolumeEntity, OBVEntity {
  double? dea;
  double? dif;
  double? macd;
}
