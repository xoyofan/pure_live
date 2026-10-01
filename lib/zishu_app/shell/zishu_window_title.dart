import 'package:window_manager/window_manager.dart';

/// 桌面窗口标题工具(真源 `app/app_router.dart` 的 `_WindowTitle` +
/// `app/app_version.dart` 的 `formatWindowTitle` 语义移植)。
///
/// 真源口径:壳层页面标题 = 「页面名 · 应用名(版本)」,播放页用房间
/// 标题覆盖(web 播放页 `displayTitle` 覆盖 document.title 的桌面等价物)。
/// 本仓无 app_version 管线(真源 `loadAppVersion`/`currentAppVersion` 未
/// 移植),版本号不加 —— 妥协记录:标题恒为「页面名 · Pure Live」。

/// 应用名(窗口标题后缀;真源 `_kAppTitle` 同位,本仓品牌名 Pure Live,
/// 与顶栏品牌字一致,见 zishu_shell_top_bar.dart _TopNavBrand)。
const String kZishuWindowTitleAppName = 'Pure Live';

/// 上次发往窗口的完整标题:播放页挂钩在 build 阶段(_buildZishuLayout
/// 的标题计算处),重建频繁且多数算出同一标题;去重后才发平台通道,
/// 语义同真源 `_WindowTitle.didUpdateWidget` 的 `old != new` 守卫。
String? _lastAppliedTitle;

/// 页面名 → 完整窗口标题(真源 `formatWindowTitle` 语义;版本段省略,
/// 见文件头妥协记录):空名(含 null/纯空白)回退应用名本身,非空为
/// 「页面名 · 应用名」。
String formatWindowTitle(String? pageTitle) {
  final title = pageTitle?.trim() ?? '';
  if (title.isEmpty) return kZishuWindowTitleAppName;
  return '$title · $kZishuWindowTitleAppName';
}

/// 设桌面窗口标题(真源 `_applyWindowTitle` 同语义):非桌面平台/
/// 单测环境 `window_manager` 无原生实现,调用抛错一律静默吞掉 ——
/// 标题是增强项,失败绝不冒泡到 UI;同值重入不发通道(见
/// [_lastAppliedTitle]),供壳层与播放页随意重复接线。
Future<void> setZishuWindowTitle(String? pageTitle) async {
  final title = formatWindowTitle(pageTitle);
  if (title == _lastAppliedTitle) return;
  _lastAppliedTitle = title;
  try {
    await windowManager.setTitle(title);
  } catch (_) {
    // Web/Android/单测无 window_manager 原生实现:忽略。
  }
}
