import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/areas/areas_list_controller.dart';

/// 分类目录启动预热:首屏就绪后异步逐站物化各可见平台的分区(分类)目录,
/// 让 hover 平台分类浮层时立即命中内存,不再等网络。
///
/// 口径对齐 zishu 真源 `features/browse/application/category_warmup.dart`
/// 的 `warmupBrowseCategories`:
/// - **串行逐站**:避免启动期并发请求风暴挤占首页首屏数据;
/// - **失败静默**:单站预热失败只记日志,不重试不外抛 —— 用户 hover 时
///   该站控制器会自然重试拉取,预热只是加速命中而非唯一路径;
/// - 调用方保证延迟到首屏之后(如启动 2s 后),不与本页数据抢带宽。
///
/// 数据层不用 zishu 的 `browseCategoriesProvider`(Riverpod),改 pure_live
/// 既有 `AreasListController(tag=siteId)`:
/// - 未注册时按 `AreasController._registerListController` 同参
///   (tag=site.id / fenix)lazyPut —— AreasController 之后初始化会直接
///   复用这一份,不产生双实例(与 `ZishuPhoneCategorySheet` 同款);
/// - `categories`(`RxList<AppLiveCategory>`)为空才 `loadData()`,
///   已有目录的站(如分区页当前 tab)不重复请求。
///
/// 入口:本轨道不接 main/壳层(禁止改其他文件),由合并轮在首屏就绪后
/// 的合适入口调用 [CategoryWarmup.schedule](幂等,已跑过直接返回)。
abstract final class CategoryWarmup {
  static bool _scheduled = false;

  /// 幂等入口:已调度过直接返回,不重复预热。
  static void schedule() {
    if (_scheduled) return;
    _scheduled = true;
    unawaited(warmupVisibleSites());
  }

  /// 串行逐站预热可见平台的分类目录。
  ///
  /// 可见站点口径与外壳 `_visibleSites()` 同源:严格按
  /// `SettingsService.to.app.savedPlatformIds.v` 的顺序,过滤
  /// `PopularController.sites`(`Get.isRegistered` 守卫,壳层未挂时不预热);
  /// 站间顺序执行,单站内容错(注册/加载抛错)静默记日志后继续下一站。
  static Future<void> warmupVisibleSites() async {
    if (!Get.isRegistered<SettingsService>() || !Get.isRegistered<PopularController>()) return;
    final saved = SettingsService.to.app.savedPlatformIds.v;
    final all = Get.find<PopularController>().sites.toList();
    for (final id in saved) {
      Site? site;
      for (final candidate in all) {
        if (candidate.id == id) {
          site = candidate;
          break;
        }
      }
      final current = site;
      if (current == null) continue;
      try {
        final tag = current.id;
        if (!Get.isRegistered<AreasListController>(tag: tag)) {
          Get.lazyPut(() => AreasListController(current), tag: tag, fenix: true);
        }
        final controller = Get.find<AreasListController>(tag: tag);
        if (controller.categories.isEmpty) {
          await controller.loadData();
        }
      } catch (error) {
        // 预热失败静默:hover 时该站控制器会自然重试拉取。
        debugPrint('[CategoryWarmup] ${current.id} categories warmup failed: $error');
      }
    }
  }
}
