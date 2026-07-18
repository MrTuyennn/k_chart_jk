import 'obv_entity.dart';
import 'cci_entity.dart';
import 'kdj_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';
import 'trix_entity.dart';
import 'mtm_entity.dart';
import 'stoch_rsi_entity.dart';
import 'brar_entity.dart';
import 'bias_entity.dart';

// OBVEntity/TRIXEntity/MTMEntity/BRAREntity/BIASEntity được thêm vào `on` clause để
// MACDEntity có thể truy cập .obv / .obvSignal / .trix / .trixMa / .mtm / .mtmMa /
// .ar / .br / .biasValueList trực tiếp — cho phép OBVIndicator/TRIXIndicator/
// MTMIndicator/BRARIndicator/BIASIndicator dùng MACDEntity làm generic T, nhất
// quán với RSI/KDJ/WR/CCI.
// Thứ tự `on` phải khớp thứ tự mixin trong KEntity (OBVEntity, TRIXEntity, MTMEntity, StochRSIEntity, BRAREntity, BIASEntity trước MACDEntity).
mixin MACDEntity on KDJEntity, RSIEntity, WREntity, CCIEntity, OBVEntity, TRIXEntity, MTMEntity, StochRSIEntity, BRAREntity, BIASEntity {
  double? dea;
  double? dif;
  double? macd;
}
