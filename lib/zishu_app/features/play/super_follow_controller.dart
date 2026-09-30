import 'package:pure_live/common/models/live_room.dart';
import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/get/get.dart';

/// 播放侧栏「超级关注」本地标记控制器(对齐 zishu 侧栏超关 chip 的数据位)。
///
/// pure_live 无平台侧超关能力,这里按用户口径做**本地标记**:以房间
/// `platform:roomId` 为 key 的集合,落 Hive 持久化;头部紫系 chip 直接
/// `isSuper`/`toggle` 驱动即时态。
///
/// 注册采用 permanent 风格的惰性单例:与 `initial_services.dart` 的
/// `Get.put(..., permanent: true)` 同语义,但本轨道不允许改启动接线,
/// 故首次取用时自注册,进程内常驻。
class SuperFollowController extends GetxController {
  /// Hive 存储键:房间 key 字符串列表(`platform:roomId`)。
  static const String defaultStorageKey = 'zishuSuperFollowRooms';

  final String storageKey;

  /// 惰性取用(必要时注册,permanent 常驻):播放侧栏等调用点直接
  /// `SuperFollowController.to` 即可。
  static SuperFollowController get to {
    if (!Get.isRegistered<SuperFollowController>()) {
      Get.put(SuperFollowController(), permanent: true);
    }
    return Get.find<SuperFollowController>();
  }

  /// 超关房间 key 集合(集合语义,由 [toggle] 保证不重)。
  ///
  /// 复用仓库 `hiveStringList`:值经 `HivePrefUtil.setStringList` 自动持久化,
  /// 与 `DanmakuSettingsController` 等 Rx 设置同一持久化管线。
  final RxList<String> superRoomKeys;

  SuperFollowController({this.storageKey = defaultStorageKey}) : superRoomKeys = hiveStringList(storageKey, <String>[]);

  /// 房间稳定 key:`platform:roomId`。与收藏同源([LiveRoom.identityKey],
  /// live_room.dart 的规范化字段,平台/房间号已 trim + 小写)。
  static String keyOf(LiveRoom room) => room.identityKey;

  /// 当前房间是否已超关(Obx 内调用即即时态)。
  bool isSuper(LiveRoom room) => superRoomKeys.contains(keyOf(room));

  /// 切换超关标记,返回切换后的状态(true = 已超关)。
  ///
  /// 房间身份缺失(无 roomId)时不落 key,维持原状返回 false。
  bool toggle(LiveRoom room) {
    if (room.normalizedRoomId.isEmpty) return false;
    final key = keyOf(room);
    if (superRoomKeys.contains(key)) {
      superRoomKeys.remove(key);
      return false;
    }
    superRoomKeys.add(key);
    return true;
  }
}
