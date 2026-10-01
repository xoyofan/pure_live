import 'package:pure_live/get/get.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';

/// 浏览侧栏折叠偏好(true = 展开,false = 收起)。
///
/// 真源 `features/browse/application/sidebar_pref_provider.dart` 同语义移植:
/// 键 `zishu.browse.sidebarOpen`、默认展开(真源 defaultValue = true)。
/// 持久化管线不用真源的 shared_preferences,对齐本仓设置同管线
/// [hiveBool](HiveRx 读盘缺省回落出厂值 + ever 自动落盘,见 hive_rx.dart):
/// 读盘失败/首启回落展开,开合即写,方向与真源「失败保默认」一致。
/// 构造是同步读盘(真源为 microtask 异步恢复),无「默认值先行再跳变」窗口。
final RxBool zishuSidebarOpen = hiveBool('zishu.browse.sidebarOpen', true);
