import 'candle_entity.dart';
import 'kdj_entity.dart';
import 'macd_entity.dart';
import 'obv_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';
import 'volume_entity.dart';
import 'cci_entity.dart';
import 'zigzag_entity.dart';

// Thứ tự mixin quan trọng — OBVEntity phải đứng trước MACDEntity
// vì MACDEntity khai báo `on OBVEntity` (xem macd_entity.dart).
// Dart yêu cầu mixin trong `on` clause phải được apply trước.
class KEntity
    with
        CandleEntity,
        VolumeEntity,
        KDJEntity,
        RSIEntity,
        WREntity,
        CCIEntity,
        OBVEntity,   // phải trước MACDEntity
        MACDEntity,
        ZigZagEntity {}
