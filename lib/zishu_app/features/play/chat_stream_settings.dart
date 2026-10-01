/// 侧栏聊天流设置(对齐 zishu `settingsProvider` 的聊天段:总开关 + 字号/
/// 透明度/行距/限速与速度,消费方 = `_SettingsPanel` 与 `ZishuChatTab`)。
///
/// - 持久化:照 `SuperFollowController`/`hive_rx.dart` 助手模式,逐字段
///   `hiveBool/hiveInt`(写盘自动,读盘缺省回落出厂值);
/// - 范围/默认值逐字段照抄 zishu 真(对齐 web SideSettingsTab.vue 41-105 /
///   useDanmaku.ts DEFAULT_CHAT):字号 12-24 默认 14、透明度 10-100 默认
///   100、行距 0-16 默认 0、速度 1-10 秒默认 5(见
///   zishu settings_provider.dart:223-249 的同源常量);
/// - 注册:`Get.put(..., permanent: true)` 惰性单例,与
///   `initial_services.dart` 的常驻语义一致但不动启动接线。
library;

import 'package:pure_live/common/services/utils/hive_rx.dart';
import 'package:pure_live/get/get.dart';

/// 侧栏聊天流设置控制器(Hive 持久化,Obx 内读 `.v` 即即时态)。
class ChatStreamSettings extends GetxController {
  static ChatStreamSettings get to {
    if (!Get.isRegistered<ChatStreamSettings>()) {
      Get.put(ChatStreamSettings(), permanent: true);
    }
    return Get.find<ChatStreamSettings>();
  }

  /// 聊天流开关(真源 settings.chatEnabled,出厂开)。
  final RxBool chatEnabled;

  /// 消息字号 px(范围/默认见 [fontSizeMin]/[fontSizeMax]/[defaultFontSize])。
  final RxInt chatFontSize;

  /// 列表不透明度 %(10-100)。
  final RxInt chatOpacity;

  /// 行间距 px(0-16,渲染为行容器 padding bottom)。
  final RxInt chatLineSpacing;

  /// 限速开关(true = 按速度逐条放行;false = 全量直通)。
  final RxBool chatThrottleOn;

  /// 限速放行间隔(秒/条,1-10)。
  final RxInt chatSpeed;

  ChatStreamSettings()
    : chatEnabled = hiveBool(_kEnabledKey, true),
      chatFontSize = hiveInt(_kFontSizeKey, defaultFontSize),
      chatOpacity = hiveInt(_kOpacityKey, defaultOpacity),
      chatLineSpacing = hiveInt(_kLineSpacingKey, defaultLineSpacing),
      chatThrottleOn = hiveBool(_kThrottleKey, false),
      chatSpeed = hiveInt(_kSpeedKey, defaultSpeed);

  static const String _kEnabledKey = 'sideChatEnabled';
  static const String _kFontSizeKey = 'sideChatFontSize';
  static const String _kOpacityKey = 'sideChatOpacity';
  static const String _kLineSpacingKey = 'sideChatLineSpacing';
  static const String _kThrottleKey = 'sideChatThrottleOn';
  static const String _kSpeedKey = 'sideChatSpeed';

  /// 字号滑杆范围(对齐 zishu SettingsState.chatFontSizeMin/Max = 12-24,
  /// 对齐 web 字号滑杆;注意与飘屏 12-36 不是同一组常量)。
  static const int fontSizeMin = 12;
  static const int fontSizeMax = 24;

  /// 字号出厂默认(对齐 web DEFAULT_CHAT.fontSize = 14)。
  static const int defaultFontSize = 14;

  /// 透明度滑杆范围 %,下限 10 保可读(对齐 zishu chatOpacityMin/Max)。
  static const int opacityMin = 10;
  static const int opacityMax = 100;

  /// 透明度出厂默认(对齐 web DEFAULT_CHAT.opacity = 100)。
  static const int defaultOpacity = 100;

  /// 行间距滑杆范围 px(对齐 zishu chatLineSpacingMin/Max = 0-16)。
  static const int lineSpacingMin = 0;
  static const int lineSpacingMax = 16;

  /// 行间距出厂默认(对齐 web DEFAULT_CHAT.gap = 0)。
  static const int defaultLineSpacing = 0;

  /// 速度滑杆范围(秒/条,对齐 zishu chatSpeedMin/Max = 1-10)。
  static const int speedMin = 1;
  static const int speedMax = 10;

  /// 速度出厂默认(秒/条,对齐 zishu defaultChatSpeed = 5)。
  static const int defaultSpeed = 5;

  /// 消费侧取值:旧版本可能写过越界值,读出后 clamp 回合法区间,
  /// UI 滑杆/渲染永不收到非法位置(对齐 zishu SettingsState 读盘归一口径)。
  int get fontSize => chatFontSize.v.clamp(fontSizeMin, fontSizeMax);
  int get opacity => chatOpacity.v.clamp(opacityMin, opacityMax);
  int get lineSpacing => chatLineSpacing.v.clamp(lineSpacingMin, lineSpacingMax);
  int get speed => chatSpeed.v.clamp(speedMin, speedMax);

  /// 写入仍走原 Rx(滑杆本身有 min/max,双保险再 clamp 一次)。
  set fontSize(int value) => chatFontSize.v = value.clamp(fontSizeMin, fontSizeMax);
  set opacity(int value) => chatOpacity.v = value.clamp(opacityMin, opacityMax);
  set lineSpacing(int value) => chatLineSpacing.v = value.clamp(lineSpacingMin, lineSpacingMax);
  set speed(int value) => chatSpeed.v = value.clamp(speedMin, speedMax);
}
