import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/get/get.dart';

/// 播放侧栏「开播提醒」本地标记控制器(对齐 zishu 关注条目 remindOn 的数据位,
/// 真源 side_panel_header.dart 提醒 pill 的禁用/激活口径)。
///
/// pure_live 无平台侧开播提醒能力,这里按用户口径做**本地标记**:以房间
/// `platform:roomId` 为 key 的集合,落 Hive 持久化;头部提醒 pill 直接
/// `isRemind`/`toggle` 驱动即时态。模式与 SuperFollowController 一致
/// (GetxController + hiveStringList)。
///
/// 注册采用 permanent 风格的惰性单例:与 `initial_services.dart` 的
/// `Get.put(..., permanent: true)` 同语义,但本轨道不改启动接线,首次取用时
/// 自注册,进程内常驻。
class RoomReminderStore extends GetxController {
  /// Hive 存储键:房间 key 字符串列表(`platform:roomId`)。
  static const String defaultStorageKey = 'zishuRemindRooms';

  final String storageKey;

  /// 惰性取用(必要时注册,permanent 常驻):播放侧栏等调用点直接
  /// `RoomReminderStore.to` 即可。
  static RoomReminderStore get to {
    if (!Get.isRegistered<RoomReminderStore>()) {
      Get.put(RoomReminderStore(), permanent: true);
    }
    return Get.find<RoomReminderStore>();
  }

  /// 提醒房间 key 集合(集合语义,由 [toggle] 保证不重)。
  ///
  /// 复用仓库 `hiveStringList`:值经 `HivePrefUtil.setStringList` 自动持久化,
  /// 与 `DanmakuSettingsController` 等 Rx 设置同一持久化管线。
  final RxList<String> remindRoomKeys;

  RoomReminderStore({this.storageKey = defaultStorageKey}) : remindRoomKeys = hiveStringList(storageKey, <String>[]);

  /// 房间稳定 key:`platform:roomId`。与收藏/超关同源
  /// ([LiveRoom.identityKey],live_room.dart 的规范化字段,平台/房间号已
  /// trim + 小写)。
  static String keyOf(LiveRoom room) => room.identityKey;

  /// 当前房间提醒是否开启(Obx 内调用即即时态)。
  bool isRemind(LiveRoom room) => remindRoomKeys.contains(keyOf(room));

  /// 切换提醒标记,返回切换后的状态(true = 提醒中)。
  ///
  /// 房间身份缺失(无 roomId)时不落 key,维持原状返回 false。
  bool toggle(LiveRoom room) {
    if (room.normalizedRoomId.isEmpty) return false;
    final key = keyOf(room);
    if (remindRoomKeys.contains(key)) {
      remindRoomKeys.remove(key);
      return false;
    }
    remindRoomKeys.add(key);
    return true;
  }

  /// 批量开启提醒(关注页批量管理「开提醒」;真源 FollowController
  /// setRemindMany(keys, true) 的本仓等价物 —— pure_live 的提醒是本地
  /// 标记集合,批量即集合并集)。一次 assignAll 落 Hive,返回是否有变化。
  bool addMany(Iterable<LiveRoom> rooms) {
    final next = remindRoomKeys.toSet();
    var changed = false;
    for (final room in rooms) {
      if (room.normalizedRoomId.isEmpty) continue;
      if (next.add(keyOf(room))) changed = true;
    }
    if (!changed) return false;
    remindRoomKeys.assignAll(next);
    return true;
  }

  /// 批量关闭提醒(关注页批量管理「关提醒」):集合差集一次落 Hive,
  /// 返回是否有变化。
  bool removeMany(Iterable<LiveRoom> rooms) {
    final targets = {
      for (final room in rooms)
        if (room.normalizedRoomId.isNotEmpty) keyOf(room),
    };
    if (targets.isEmpty) return false;
    final next = remindRoomKeys.where((key) => !targets.contains(key)).toList();
    if (next.length == remindRoomKeys.length) return false;
    remindRoomKeys.assignAll(next);
    return true;
  }
}
