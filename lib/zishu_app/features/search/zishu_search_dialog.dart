/// zishu 风格全局搜索弹窗:对齐真源 zishu_flutter
/// `features/search/views/search_view.dart` + `widgets/search_dialog.dart` 的
/// 对话框形态 —— 宽 min(92vw, 520) / 高 min(82vh, 640)、surface 底、
/// 12px(allLg)圆角;标题行下为「主播 / 房间」档位 tab(_SearchTabBar
/// 同构:左对齐、短下划线、按平台能力位增减档)。
///
/// 数据层复用 pure_live 既有 `SearchController`(关键词 → 各站房间/主播,
/// 多站并发 + Rx 状态),档位经 `setType` 分流;房间号/斗鱼链接直达为输入
/// 实时解析([SearchController.onQueryChanged]),命中时结果区顶部渲染
/// accent 高亮 tile;Enter 优先级(直达 → 首个结果 → 空词 toast)逐字照
/// 真源 search_view.dart:81-90。
///
/// 与真源的已记录差异:真源输入行尾部有「Esc 关闭」徽标 —— 本仓以
/// 「关闭」tooltip 承担同等可发现性,徽标不再复刻;搜索仍由回车/按钮驱动
/// (真源为输入防抖实时搜索),直达解析除外。主播结果点击进房而非主播页
/// (本仓无主播页路由,妥协已记录)。
///
/// 生命周期:控制器按 `zishu-search-dialog` tag 挂到 GetX,弹窗卸载即
/// `Get.delete`,不与 kSearch 路由的 SearchBinding 实例(无 tag)互扰。
library;

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/search/search_controller.dart' as pure_live;
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/platform_brands.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';
import 'package:pure_live/zishu_app/features/search/zishu_search_anchor_tile.dart';
import 'package:pure_live/zishu_app/features/search/zishu_search_results.dart';

/// 对话框宽度上限:对齐真源 `width="min(92vw, 520px)"`。
const double _kDialogWidth = 520;

/// 对话框高度上限(同真源 search_dialog 常量)。
const double _kDialogMaxHeight = 640;

/// 无 i18n key 的中文文案常量(记录):
/// - 档位 tab 与 hint:真源 _SearchTabBar/search_view.dart:237 同文案;
/// - 清空钮:真源 search_view.dart:250 tooltip 同文案(i18n 现有
///   `clear` key 为「清除」,与真源「清空」不同字,故用常量)。
const String _kAnchorTabLabel = '主播';
const String _kRoomTabLabel = '房间';
const String _kHintAnchor = '搜索主播';
const String _kHintRoom = '搜索房间';
const String _kClearTooltip = '清空';

/// 弹窗私有 SearchController 的 GetX tag(与 SearchBinding 的无 tag 实例隔离)。
const String _kSearchControllerTag = 'zishu-search-dialog';

/// 打开 zishu 风格搜索弹窗(顶栏搜索入口共用)。
///
/// 只负责弹窗本身:结果点击 / 直达进房在弹窗内先 pop 再导航,
/// 避免「新页面被弹窗压在下面」的真源原注释陷阱。
Future<void> showZishuSearchDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: context.tokens.barrier,
    builder: (_) => const _ZishuSearchDialogFrame(),
  );
}

/// 对话框外框:标题行(搜索 + 关闭)+ 档位 tab + 输入行 + 平台 chips +
/// 结果区;持有控制器生命周期,并承担 Esc 关闭与 Enter 提交优先级。
class _ZishuSearchDialogFrame extends StatefulWidget {
  const _ZishuSearchDialogFrame();

  @override
  State<_ZishuSearchDialogFrame> createState() => _ZishuSearchDialogFrameState();
}

class _ZishuSearchDialogFrameState extends State<_ZishuSearchDialogFrame> {
  late final pure_live.SearchController _controller;

  /// 只有真正 put 进去的那份实例才由本弹窗负责 delete(叠开两个弹窗时,
  /// 后者 find 复用前者实例,避免前者的 onClose 被跳过导致控制器泄漏)。
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = !Get.isRegistered<pure_live.SearchController>(tag: _kSearchControllerTag);
    _controller = _ownsController
        // 与 SearchBinding 同参:全量可用站点。tag 隔离,弹窗关闭即销毁。
        ? Get.put(pure_live.SearchController(), tag: _kSearchControllerTag)
        : Get.find<pure_live.SearchController>(tag: _kSearchControllerTag);
  }

  @override
  void dispose() {
    if (_ownsController) {
      Get.delete<pure_live.SearchController>(tag: _kSearchControllerTag);
    }
    super.dispose();
  }

  /// Enter 优先级逐字照真源 search_view.dart:81-90:直达项 → 首个结果 →
  /// 空词 toast(走既有 doSearch 的 please_input_keyword)。
  ///
  /// 「首个结果」只在结果与当前输入同代时生效(hasFresh*Results 防陈旧
  /// 误导航);否则回退为发起搜索 —— 这是与真源(输入实时搜索)的口径差,
  /// 见文件头差异记录。
  void _submit() {
    final target = _controller.direct.v;
    if (target != null) {
      _openDirect(target);
      return;
    }
    if (_controller.searchType.v == pure_live.SearchType.rooms && _controller.hasFreshRoomResults) {
      _openRoom(_controller.results.first);
      return;
    }
    if (_controller.searchType.v == pure_live.SearchType.anchors && _controller.hasFreshAnchorResults) {
      _openAnchorRoom(_controller.anchors.first);
      return;
    }
    _controller.doSearch();
  }

  /// 关弹窗后进房(直播中/未开播判断沿用结果区同口径)。
  void _openRoom(LiveRoom room) {
    Navigator.of(context).pop();
    AppNavigator.toLiveRoomDetail(liveRoom: room);
  }

  /// 主播首个结果进房:未开播拦截提示(真源 _openRoom 未开播提示同口径)。
  void _openAnchorRoom(pure_live.SearchAnchorHit hit) {
    if (!hit.anchor.liveStatus) {
      ToastUtil.show(zishuAnchorOfflineMessage(hit.anchor.userName));
      return;
    }
    _openRoom(LiveRoom(platform: hit.site.id, roomId: hit.anchor.roomId));
  }

  /// 直达进房:链接直达固定斗鱼(真源 search_view.dart:116-119);纯数字
  /// 跟随当前选中平台构造 LiveRoom ——「全平台」无法推断归属,沿用既有
  /// select_platform_for_web_search 提示(原 _DirectRoomRow 同口径)。
  void _openDirect(pure_live.DirectTarget target) {
    String platformId;
    if (target.kind == pure_live.DirectKind.link) {
      platformId = Sites.douyuSite;
    } else {
      final index = _controller.index.v;
      if (index <= 0 || index > _controller.sites.length) {
        ToastUtil.show(i18n('select_platform_for_web_search'));
        return;
      }
      platformId = _controller.sites[index - 1].id;
    }
    Navigator.of(context).pop();
    AppNavigator.toLiveRoomDetail(
      liveRoom: LiveRoom(platform: platformId, roomId: target.roomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final viewport = MediaQuery.sizeOf(context);
    final width = math.min(viewport.width * 0.92, _kDialogWidth);
    final height = math.min(viewport.height * 0.82, _kDialogMaxHeight);
    return Dialog(
      key: const Key('zishu-search-dialog'),
      backgroundColor: tokens.surface,
      insetPadding: const EdgeInsets.all(AppSpacing.lg),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.allLg),
      clipBehavior: Clip.antiAlias,
      child: CallbackShortcuts(
        // Esc 关闭弹窗(真源 search_view.dart:159-163 同口径;真源的 Esc
        // 徽标为视觉提示,本仓以「关闭」tooltip 承担同等可发现性,徽标不加)。
        bindings: {const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(context).pop()},
        child: SizedBox(
          width: width,
          height: height,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.sm, 0),
                child: Row(
                  children: [
                    Text(
                      i18n('search_live'),
                      style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle, color: tokens.textPrimary),
                    ),
                    const Spacer(),
                    IconButton(
                      key: const Key('zishu-search-dialog-close'),
                      // 真源 search_dialog.dart:110 tooltip 同文案「关闭」。
                      tooltip: i18n('close'),
                      onPressed: () => Navigator.of(context).pop(),
                      iconSize: 18,
                      color: tokens.textSecondary,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Obx(() {
                    // 主播档按当前选中平台的能力位显隐:全平台任一站可用即显,
                    // 单站以 searchAnchors 真实实现为准(见控制器 anchorSearchSites)。
                    final anchorEnabled = _controller.supportsAnchorSearchAt(_controller.index.v);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SearchTabBar(
                          type: _controller.searchType.v,
                          anchorEnabled: anchorEnabled,
                          onChanged: _controller.setType,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _SearchInputRow(controller: _controller, onSubmit: _submit),
                        const SizedBox(height: AppSpacing.sm),
                        _PlatformChips(controller: _controller),
                        const SizedBox(height: AppSpacing.sm),
                        Expanded(
                          child: ZishuSearchResultArea(controller: _controller, onOpenDirect: _openDirect),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 搜索档位切换条(主播 / 房间),对齐真源 zishu search_view.dart:378-447
/// 的 _SearchTabBar:左对齐、短下划线、按能力位增减档 —— 刻意不引
/// Material `TabBar`(需要 TabController 且下划线铺满整行)。
class _SearchTabBar extends StatelessWidget {
  const _SearchTabBar({required this.type, required this.anchorEnabled, required this.onChanged});

  final pure_live.SearchType type;
  final bool anchorEnabled;
  final ValueChanged<pure_live.SearchType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (anchorEnabled)
          _tab(context, pure_live.SearchType.anchors, _kAnchorTabLabel, const Key('zishu-search-tab-anchor')),
        _tab(context, pure_live.SearchType.rooms, _kRoomTabLabel, const Key('zishu-search-tab-room')),
      ],
    );
  }

  Widget _tab(BuildContext context, pure_live.SearchType value, String label, Key key) {
    final tokens = context.tokens;
    final active = value == type;
    return InkWell(
      key: key,
      onTap: () => onChanged(value),
      // 档位 tab:底为透明(靠选中下划线表达),hover 抬亮;键盘焦点/按压
      // 用 accent 低 alpha。真源 :411-419 同口径。
      hoverColor: tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.lg, top: AppSpacing.xs, bottom: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.textBody.copyWith(
                color: active ? tokens.accent : tokens.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(height: 2, width: AppSpacing.xl, color: active ? tokens.accent : const Color(0x00000000)),
          ],
        ),
      ),
    );
  }
}

/// 搜索输入行:回车/搜索钮触发宿主 `_submit`;输入实时解析直达项
/// (onQueryChanged);suffix =「有文字时清空钮 + 搜索钮」,hint 随档位切换
/// (真源 search_view.dart:236-263;清空钮行为 = clearDraft 回空态 +
/// 重新聚焦,真源 :256-260 同口径)。
class _SearchInputRow extends StatefulWidget {
  const _SearchInputRow({required this.controller, required this.onSubmit});

  final pure_live.SearchController controller;
  final VoidCallback onSubmit;

  @override
  State<_SearchInputRow> createState() => _SearchInputRowState();
}

class _SearchInputRowState extends State<_SearchInputRow> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final controller = widget.controller;
    return Obx(() {
      final isRoomTab = controller.searchType.v == pure_live.SearchType.rooms;
      return TextField(
        controller: controller.searchController,
        focusNode: _focus,
        autofocus: true,
        cursorColor: tokens.accent,
        style: context.textBody,
        onChanged: controller.onQueryChanged,
        onSubmitted: (_) => widget.onSubmit(),
        decoration: InputDecoration(
          isDense: true,
          // hint 随档位切换(真源 :237;无 i18n key,中文常量,见文件头记录)。
          hintText: isRoomTab ? _kHintRoom : _kHintAnchor,
          hintStyle: context.textBody.copyWith(color: tokens.textSecondary),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
          filled: true,
          fillColor: tokens.surfaceRaised,
          border: OutlineInputBorder(
            borderRadius: AppRadius.allSm,
            borderSide: BorderSide(color: tokens.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.allSm,
            borderSide: BorderSide(color: tokens.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.allSm,
            borderSide: BorderSide(color: tokens.accent),
          ),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: tokens.textSecondary),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller.searchController,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasText)
                    IconButton(
                      tooltip: _kClearTooltip,
                      onPressed: () {
                        controller.clearDraft();
                        _focus.requestFocus();
                      },
                      iconSize: 18,
                      color: tokens.textSecondary,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  IconButton(
                    tooltip: i18n('search_live'),
                    onPressed: widget.onSubmit,
                    iconSize: 18,
                    color: tokens.textSecondary,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              );
            },
          ),
        ),
      );
    });
  }
}

/// 平台筛选 chips:「全部」+ 各站;选中色取平台品牌色(真源
/// search_platform_chips.dart 同构,沿用本仓浅淡底可读性口径)。
class _PlatformChips extends StatelessWidget {
  const _PlatformChips({required this.controller});

  final pure_live.SearchController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = controller.index.v;
      return SizedBox(
        height: AppSpacing.topNavHeight - 8,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          clipBehavior: Clip.none,
          children: [
            _PlatformChip(
              label: i18n('site_all'),
              color: PlatformBrandCatalog.all.color,
              selected: selected == 0,
              onTap: () => controller.selectPlatform(0),
            ),
            for (var i = 0; i < controller.sites.length; i++)
              _PlatformChip(
                label: controller.sites[i].name,
                color: PlatformBrandCatalog.byId(controller.sites[i].id)?.color ?? context.tokens.accent,
                selected: selected == i + 1,
                onTap: () => controller.selectPlatform(i + 1),
              ),
          ],
        ),
      );
    });
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({required this.label, required this.color, required this.selected, required this.onTap});

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: InkWell(
        borderRadius: AppRadius.allSm,
        onTap: onTap,
        hoverColor: selected ? color.withValues(alpha: 0.12) : tokens.surfaceRaised,
        splashColor: AppStateLayer.splashOf(color),
        highlightColor: AppStateLayer.pressedOf(color),
        focusColor: AppStateLayer.focusOf(color),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.18) : tokens.surface,
            borderRadius: AppRadius.allSm,
            border: Border.all(color: selected ? color : tokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: context.textSecondary.copyWith(
                  // 选中文字走主题文字色:平台品牌色文字在浅色淡底上不可读。
                  color: selected ? tokens.textPrimary : tokens.textSecondary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
