/// 观看人数展示取值:桥接层(purelive backend)统一口径。
///
/// 适配器层存在两代字段:legacy `watching`(裸展示串)与新口径
/// `popularity`/`totalViewers`/`onlineViewers` + `audienceMetricType`。
/// 部分平台(CHZZK/PandaTV/17LIVE/京东/niconico)只在列表行填了新口径
/// 字段,裸读 `watching` 会让首页观看数徽标丢失;这里以 legacy 值优先、
/// 空缺时回落 `LiveRoom.audienceValue()` 统一取值,保证既有平台显示
/// 零变化,仅补齐缺口。
library;

import 'package:pure_live/core/models/live_room.dart';

/// 首页/搜索卡片徽标用的观看数字符串;平台无任何测量值时返回空串。
String audienceDisplayOf(LiveRoom room) {
  final legacy = (room.watching ?? '').trim();
  if (legacy.isNotEmpty && legacy != '0' && legacy != 'null') return legacy;
  return room.audienceValue(preferRealOnline: false, platformEnabled: false);
}
