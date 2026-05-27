import 'obv_entity.dart';
import 'cci_entity.dart';
import 'kdj_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';

// OBVEntity được thêm vào `on` clause để MACDEntity có thể truy cập
// .obv / .obvSignal trực tiếp — cho phép OBVIndicator dùng MACDEntity
// làm generic T, nhất quán với RSI/KDJ/WR/CCI.
// Thứ tự `on` phải khớp thứ tự mixin trong KEntity (OBVEntity trước MACDEntity).
mixin MACDEntity on KDJEntity, RSIEntity, WREntity, CCIEntity, OBVEntity {
  double? dea;
  double? dif;
  double? macd;
}
