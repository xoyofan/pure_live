/// zishu 风格全局搜索弹窗:对齐 zishu_flutter
/// `features/search/widgets/search_dialog.dart` 的对话框形态 —— 宽
/// min(92vw, 520) / 高 min(82vh, 640)、surface 底、12px(allLg)圆角。
///
/// 数据层完全复用 pure_live 既有 `SearchController`(关键词 → 各站房间,
/// 多站并发 + Rx 状态),不重写任何解析;结果区见 `zishu_search_results.dart`,
/// 结果卡片复用 [ZishuRoomCard],房间号直达走 `AppNavigator.toLiveRoomDetail`
/// (构造纯 platform+roomId 的 LiveRoom,详情页自行完成房间信息解析)。
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
import 'package:pure_live/zishu_app/features/search/zishu_search_results.dart';

/// 对话框宽度上限:对齐 zishu `width="min(92vw, 520px)"`。
const double _kDialogWidth = 520;

/// 对话框高度上限(同 zishu search_dialog 常量)。
const double _kDialogMaxHeight = 640;

/// 房间号直达的最少位数(交付口径:纯数字 ≥3 位 = 房间号直达)。
const int _kDirectRoomMinDigits = 3;

/// 弹窗私有 SearchController 的 GetX tag(与 SearchBinding 的无 tag 实例隔离)。
const String _kSearchControllerTag = 'zishu-search-dialog';

/// 缺失的 i18n key(见交付报告),以中文常量兜底。
const String _kDirectEntryLabel = '直达';
const String _kDirectEntryHint = '输入房间号,纯数字≥3位';

/// 打开 zishu 风格搜索弹窗(顶栏搜索入口共用)。
///
/// 只负责弹窗本身:结果点击 / 房间直达在弹窗内先 pop 再导航,
/// 避免「新页面被弹窗压在下面」的 zishu 原注释陷阱。
Future<void> showZishuSearchDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: context.tokens.barrier,
    builder: (_) => const _ZishuSearchDialogFrame(),
  );
}

/// 对话框外框:标题行(搜索 + 关闭)+ 搜索主体;持有控制器生命周期。
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
                    tooltip: i18n('cancel'),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _SearchInputRow(controller: _controller),
                    const SizedBox(height: AppSpacing.sm),
                    _PlatformChips(controller: _controller),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(child: ZishuSearchResultArea(controller: _controller)),
                    const SizedBox(height: AppSpacing.sm),
                    _DirectRoomRow(controller: _controller),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 搜索输入行:回车/箭头均触发既有 `doSearch()`(含空词 toast)。
class _SearchInputRow extends StatelessWidget {
  const _SearchInputRow({required this.controller});

  final pure_live.SearchController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return TextField(
      controller: controller.searchController,
      autofocus: true,
      style: context.textBody,
      decoration: InputDecoration(
        isDense: true,
        hintText: i18n('search_input_hint'),
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
        prefixIcon: const Icon(Icons.search_rounded, size: 18),
        suffixIcon: IconButton(
          tooltip: i18n('search_live'),
          onPressed: controller.doSearch,
          iconSize: 18,
          color: tokens.textSecondary,
          icon: const Icon(Icons.arrow_forward_rounded),
        ),
      ),
      onSubmitted: (_) => controller.doSearch(),
    );
  }
}

/// 平台筛选 chips:「全部」+ 各站;选中色取平台品牌色(zishu 同构)。
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
                  color: selected ? color : tokens.textSecondary,
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

/// 房间号直达行:纯数字 ≥3 位启用「直达」,取当前选中平台构造 LiveRoom。
class _DirectRoomRow extends StatefulWidget {
  const _DirectRoomRow({required this.controller});

  final pure_live.SearchController controller;

  @override
  State<_DirectRoomRow> createState() => _DirectRoomRowState();
}

class _DirectRoomRowState extends State<_DirectRoomRow> {
  final TextEditingController _roomId = TextEditingController();

  @override
  void dispose() {
    _roomId.dispose();
    super.dispose();
  }

  /// 纯数字且 ≥3 位;成立时直达按钮可用。
  bool get _isRoomId => RegExp(r'^\d{3,}$').hasMatch(_roomId.text.trim());

  /// 平台筛选 =「全部」时无法推断房间归属,提示先选平台(既有 key)。
  void _goDirectRoom() {
    final roomId = _roomId.text.trim();
    if (roomId.length < _kDirectRoomMinDigits) return;
    final index = widget.controller.index.v;
    final sites = widget.controller.sites;
    if (index <= 0 || index > sites.length) {
      ToastUtil.show(i18n('select_platform_for_web_search'));
      return;
    }
    final site = sites[index - 1];
    Navigator.of(context).pop();
    AppNavigator.toLiveRoomDetail(
      liveRoom: LiveRoom(platform: site.id, roomId: roomId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Row(
      children: [
        Icon(Icons.tag_rounded, size: 16, color: tokens.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: TextField(
            controller: _roomId,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: context.textBody,
            decoration: InputDecoration(
              isDense: true,
              hintText: _kDirectEntryHint,
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
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
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _goDirectRoom(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // 直达可用性 = 纯数字≥3位 && 已选具体平台;index 是 Rx,用 Obx 订阅。
        Obx(() {
          final directEnabled = _isRoomId && widget.controller.index.v > 0;
          return TextButton(
            onPressed: directEnabled ? _goDirectRoom : null,
            style: TextButton.styleFrom(foregroundColor: tokens.accent),
            child: Text(_kDirectEntryLabel),
          );
        }),
      ],
    );
  }
}
