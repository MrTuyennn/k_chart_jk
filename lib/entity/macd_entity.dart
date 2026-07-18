import 'obv_entity.dart';
import 'cci_entity.dart';
import 'kdj_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';
import 'trix_entity.dart';
import 'mtm_entity.dart';
import 'stoch_rsi_entity.dart';
import 'brar_entity.dart';

// OBVEntity/TRIXEntity/MTMEntity/BRAREntity được thêm vào `on` clause để MACDEntity
// có thể truy cập .obv / .obvSignal / .trix / .trixMa / .mtm / .mtmMa / .ar / .br
// trực tiếp — cho phép OBVIndicator/TRIXIndicator/MTMIndicator/BRARIndicator dùng
// MACDEntity làm generic T, nhất quán với RSI/KDJ/WR/CCI.
// Thứ tự `on` phải khớp thứ tự mixin trong KEntity (OBVEntity, TRIXEntity, MTMEntity, StochRSIEntity, BRAREntity trước MACDEntity).
mixin MACDEntity on KDJEntity, RSIEntity, WREntity, CCIEntity, OBVEntity, TRIXEntity, MTMEntity, StochRSIEntity, BRAREntity {
  double? dea;
  double? dif;
  double? macd;
}
