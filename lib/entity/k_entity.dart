import 'candle_entity.dart';
import 'kdj_entity.dart';
import 'macd_entity.dart';
import 'obv_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';
import 'volume_entity.dart';
import 'cci_entity.dart';
import 'trix_entity.dart';
import 'mtm_entity.dart';
import 'stoch_rsi_entity.dart';
import 'zigzag_entity.dart';
import 'avl_entity.dart';
import 'brar_entity.dart';
import 'bias_entity.dart';
import 'psy_entity.dart';

// Thứ tự mixin quan trọng — OBVEntity/TRIXEntity/MTMEntity/StochRSIEntity/BRAREntity/
// BIASEntity/PSYEntity phải đứng trước MACDEntity vì MACDEntity khai báo `on
// OBVEntity, TRIXEntity, MTMEntity, StochRSIEntity, BRAREntity, BIASEntity, PSYEntity`
// (xem macd_entity.dart). Dart yêu cầu mixin trong `on` clause phải được apply trước.
class KEntity
    with
        CandleEntity,
        VolumeEntity,
        KDJEntity,
        RSIEntity,
        WREntity,
        CCIEntity,
        OBVEntity,   // phải trước MACDEntity
        TRIXEntity,  // phải trước MACDEntity
        MTMEntity,      // phải trước MACDEntity
        StochRSIEntity, // phải trước MACDEntity
        BRAREntity,     // phải trước MACDEntity
        BIASEntity,     // phải trước MACDEntity
        PSYEntity,      // phải trước MACDEntity
        MACDEntity,
        ZigZagEntity,
        AVLEntity {}
