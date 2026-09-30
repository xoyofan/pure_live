import 'package:pure_live/common/index.dart';

/// 人数/热度统一展示格式(zh 档规则对齐 zishu `formatFollowersValue`,
/// platform_display.dart:31):
/// 去千分位逗号后可解析纯数字时 —— ≥100万 取整数万(四舍五入,
/// 如 1234000 → 123万);≥1万 取一位小数万(保留尾零,如 10000 → 1.0万);
/// <1万 / 非数字 / 空 原样返回(不造 0,不打断调用方空值不渲染逻辑)。
/// en 档保持既有 X.K(≥1000)档不动。
String readableCount(String info) {
  try {
    final text = info.trim().replaceAll(',', '');
    final count = int.tryParse(text);
    if (count == null) return info;
    bool isZh = Get.locale?.languageCode == 'zh';

    if (isZh) {
      if (count >= 10000) {
        final wan = count / 10000;
        return '${wan >= 100 ? wan.toStringAsFixed(0) : wan.toStringAsFixed(1)}${i18n("count_wan")}';
      }
    } else {
      if (count >= 1000) {
        return '${(count / 1000).toStringAsFixed(1)}${i18n("count_k")}';
      }
    }
  } catch (_) {}
  return info;
}
