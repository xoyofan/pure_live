/// 「平台」组的就地展开内容(2026-10 任务D 全面扁平化)。
///
/// - [ZishuPlatformOrderContent]:平台顺序与可见的紧凑版。原
///   `PlatformOrderSettingsPage` 的竖排 ReorderableListView 换皮肤为
///   **紧凑横排 Wrap**(单条目 = 平台图标 + 名称 + 可见迷你开关 + 拖拽把手),
///   拖拽把手拖到另一条目上即插入其前;逻辑仍复用
///   `AppSettingsController.normalizePlatformIds` / `togglePlatformVisibility`
///   与 `savedPlatformIds` 唯一真源(改动即时生效,外壳顶栏/侧栏 Obx 同步)。
/// - [ZishuPlatformDisplayContent]:平台显示与授权(`platform_settings`)的
///   紧凑版:偏好平台改为就地 chips 单选;第三方授权 / 标签管理两个重管理页
///   保留入口行、改为对话框宿主弹出(任务D 允许「更多设置」类 dialog 入口),
///   绑定经 [Get.lazyPut] 复刻各自路由 Binding(单控制器 lazyPut)。
library;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/app_settings_controller.dart';
import 'package:pure_live/modules/account/account_controller.dart';
import 'package:pure_live/modules/account/account_page.dart';
import 'package:pure_live/modules/tags/tag_management_controller.dart';
import 'package:pure_live/modules/tags/tag_management_page.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/compact_switch.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

import 'zishu_credentials_dialog.dart';
import 'zishu_settings_rows.dart';

/// 「平台凭证」入口行文案(缺失 i18n key,中文常量兜底,先例见
/// `zishu_settings_view.dart` 顶部常量;建议补 `platform_credentials` /
/// `platform_credentials_desc`)。真源锚点 5990d1c:凭证收编为弹框。
const String _kCredentialsTitle = '平台凭证';
const String _kCredentialsDesc = '凭证仅存本机，集中编辑各平台登录态 Cookie';

/// 平台顺序与可见:紧凑横排 Wrap + 拖拽排序 + 可见迷你开关。
class ZishuPlatformOrderContent extends StatelessWidget {
  const ZishuPlatformOrderContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final app = SettingsService.to.app;
      final savedOrder = AppSettingsController.normalizePlatformIds(app.savedPlatformIds.v);
      // 保存顺序优先;新增站点(未入保存表)按 availableSites 原序追加在后。
      final sortedSites = List<Site>.from(Sites().availableSites());
      sortedSites.sort((a, b) {
        final indexA = savedOrder.indexOf(a.id);
        final indexB = savedOrder.indexOf(b.id);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return 0;
      });

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xs, bottom: AppSpacing.xs),
            child: Text(i18n('platform_order_settings_desc'), style: context.textCaption),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final site in sortedSites) _PlatformSortChip(site: site, savedOrder: savedOrder)],
          ),
        ],
      );
    });
  }
}

/// 单个平台条目:图标 + 名称 + 可见迷你开关 + 拖拽把手(仅可见且可排序时)。
class _PlatformSortChip extends StatelessWidget {
  const _PlatformSortChip({required this.site, required this.savedOrder});

  final Site site;
  final List<String> savedOrder;

  bool get _visible => savedOrder.contains(site.id);

  bool get _canDrag => _visible && savedOrder.length > 1;

  /// 开关 = 是否可见;仅剩一个可见平台时禁止隐藏(与原页同口径)。
  void _toggleVisibility(bool value) {
    if (!value && savedOrder.length <= 1) {
      ToastUtil.show(i18n('at_least_one_platform_required'));
      return;
    }
    SettingsService.to.app.togglePlatformVisibility(site.id, value);
  }

  /// 被拖条目拖到本条目上:插入到本条目之前(写回 savedPlatformIds)。
  void _acceptDrop(String draggedId) {
    if (draggedId == site.id) return;
    final app = SettingsService.to.app;
    final order = List<String>.from(AppSettingsController.normalizePlatformIds(app.savedPlatformIds.v));
    if (!order.contains(draggedId) || !order.contains(site.id)) return;
    order.remove(draggedId);
    order.insert(order.indexOf(site.id), draggedId);
    app.savedPlatformIds.v = order;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final chip = Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: AppRadius.allSm,
        border: Border.all(
          color: _visible
              ? tokens.border
              : Color.alphaBlend(tokens.textSecondary.withValues(alpha: 0.18), tokens.surface),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: _visible ? 1 : 0.45,
            child: PlatformIcon(id: site.id, size: 14),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              site.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textBody.copyWith(
                fontSize: AppFontSize.bodySecondary,
                fontWeight: FontWeight.w500,
                color: _visible ? tokens.textPrimary : tokens.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          CompactSwitch(value: _visible, onChanged: _toggleVisibility),
          if (_canDrag) ...[
            const SizedBox(width: 2),
            Tooltip(
              message: i18n('drag_menu_to_sort_tip'),
              child: Icon(Icons.drag_indicator_rounded, size: 14, color: tokens.textSecondary),
            ),
          ],
        ],
      ),
    );
    return ZishuDragChip(data: site.id, draggable: _canDrag, onAccepted: _acceptDrop, child: chip);
  }
}

/// 平台显示与授权紧凑版:偏好平台 chips 单选 + 授权/标签管理入口(对话框宿主)。
class ZishuPlatformDisplayContent extends StatelessWidget {
  const ZishuPlatformDisplayContent({super.key});

  /// 偏好平台候选:与原页选择器同源(hotAreasList 去重 + 仅受支持站点)。
  List<String> _preferCandidates() {
    final seen = <String>{};
    final result = <String>[];
    for (final rawId in SettingsService.to.fav.hotAreasList) {
      final id = rawId.trim().toLowerCase();
      if (!seen.add(id) || !Sites.isSupported(id)) continue;
      result.add(id);
    }
    return result;
  }

  static void _ensureAccountController() {
    if (!Get.isRegistered<AccountController>()) Get.lazyPut(() => AccountController(), fenix: true);
  }

  static void _ensureTagController() {
    if (!Get.isRegistered<TagManagementController>()) Get.lazyPut(() => TagManagementController(), fenix: true);
  }

  @override
  Widget build(BuildContext context) {
    final fav = SettingsService.to.fav;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZishuSectionCaption(i18n('prefer_platform')),
        Obx(
          () => Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final id in _preferCandidates())
                ZishuOptionChip(
                  label: i18nOr('site_$id', id),
                  selected: fav.preferPlatform.value == id,
                  onTap: () => fav.changePreferPlatform(id),
                ),
            ],
          ),
        ),
        // 平台凭证:真源 5990d1c 把凭证收编为弹框(低频配置不占路由页),
        // 旧账号页(第三方授权)原样保留,两个入口并存。
        ZishuSettingLine(
          title: _kCredentialsTitle,
          desc: _kCredentialsDesc,
          trailing: zishuLineChevron(context),
          onTap: () => showZishuCredentialsDialog(context),
        ),
        ZishuSettingLine(
          title: i18n('third_party_auth'),
          desc: i18n('third_party_auth_subtitle'),
          trailing: zishuLineChevron(context),
          onTap: () =>
              ZishuPageHostDialog.show(context, page: const AccountPage(), ensureBinding: _ensureAccountController),
        ),
        ZishuSettingLine(
          title: i18n('tag_management'),
          desc: i18n('tag_management_subtitle'),
          trailing: zishuLineChevron(context),
          onTap: () =>
              ZishuPageHostDialog.show(context, page: const TagManagementPage(), ensureBinding: _ensureTagController),
        ),
      ],
    );
  }
}
