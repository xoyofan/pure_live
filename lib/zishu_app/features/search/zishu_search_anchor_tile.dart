/// zishu 搜索弹窗「主播档」结果行 tile:逐字移植真源 zishu
/// `features/search/widgets/search_result_tile.dart` 的行形态 ——
/// 40×40 方形头像 + 平台角标 + 昵称 + 直播状态点 + 行尾「进入直播间」描边钮,
/// 行底部 1px border 分隔,hover 抬亮 surfaceRaised、按压/焦点走 accent 状态层。
///
/// 与真源的口径差异(数据诚实,均已确认):
/// - 真源行中部还有标题/分类 chip 与粉丝数/在线人数元信息;本仓
///   `LiveAnchorItem`(lib/model/live_anchor_item.dart)只有
///   roomId/avatar/userName/liveStatus 四个字段,无此数据 —— 按
///   「有则显,无则省」原则整段省略,不造占位数据;
/// - 真源头像/昵称点击进主播主页(`/{site}/anchor/{id}`),本仓无主播页路由,
///   行点击与「进入直播间」钮同为按 roomId 构造 LiveRoom 进房(妥协已记录),
///   因此头像不再单独作为嵌套点击区,tooltip 一并省去。
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pure_live/model/live_anchor_item.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_badge.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 无 i18n key 的中文文案常量(真源 search_result_tile.dart:41-42 同文案,记录)。
const String _kStateLiveLabel = '直播中';
const String _kStateOfflineLabel = '未开播';
const String _kEnterRoomLabel = '进入直播间';

/// 未开播进房拦截文案(无 i18n key,记录;真源 search_view.dart:97 同文案)。
/// 主播档弹窗与结果区共用,故挂在 tile 库对外导出。
String zishuAnchorOfflineMessage(String name) => '「$name」当前未开播';

/// 主播档单条命中行。
class ZishuSearchAnchorTile extends StatelessWidget {
  const ZishuSearchAnchorTile({
    super.key,
    required this.site,
    required this.anchor,
    required this.onRowTap,
    this.onEnterTap,
  });

  /// 平台 id(角标与进房参数用)。
  final String site;
  final LiveAnchorItem anchor;

  /// 行主体点击(进直播间 / 未开播提示,由宿主决定)。
  final VoidCallback onRowTap;

  /// 行尾「进入直播间」钮点击;缺省与 [onRowTap] 同(真源钮/行同义)。
  final VoidCallback? onEnterTap;

  bool get _isLive => anchor.liveStatus;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final stateColor = _isLive ? tokens.liveBadge : tokens.textSecondary;
    final stateLabel = _isLive ? _kStateLiveLabel : _kStateOfflineLabel;
    return InkWell(
      onTap: onRowTap,
      // 状态反馈(全部走 token):hover 抬亮;焦点/按压用 accent 低 alpha,
      // 与真源 search_result_tile.dart:46-49 同口径。
      hoverColor: tokens.surfaceRaised,
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Row(
          children: [
            _AnchorAvatar(anchor: anchor),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PlatformBadge(site: site),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          anchor.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle, color: tokens.textPrimary),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: stateColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(stateLabel, style: context.textCaption.copyWith(color: stateColor)),
                    ],
                  ),
                  // 粉丝数 / 在线人数元信息行:LiveAnchorItem 无对应字段,
                  // 按「有则显,无则省」省略(不造数据,见文件头口径说明)。
                ],
              ),
            ),
            if (_isLive) ...[const SizedBox(width: AppSpacing.sm), _AnchorEnterButton(onTap: onEnterTap ?? onRowTap)],
          ],
        ),
      ),
    );
  }
}

/// 方形头像:CachedNetworkImage,失败/为空时以昵称首字占位
/// (真源 search_result_tile.dart:179-231 同构,尺寸 40×40、allSm 圆角)。
class _AnchorAvatar extends StatelessWidget {
  const _AnchorAvatar({required this.anchor});

  final LiveAnchorItem anchor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return ClipRRect(
      borderRadius: AppRadius.allSm,
      child: Container(
        width: 40,
        height: 40,
        color: tokens.surfaceRaised,
        child: anchor.avatar.isEmpty
            ? _fallback(context)
            : CachedNetworkImage(
                imageUrl: anchor.avatar,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: tokens.surfaceRaised),
                errorWidget: (_, _, _) => _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final tokens = context.tokens;
    return ColoredBox(
      color: tokens.surfaceRaised,
      child: Center(
        child: Text(
          anchor.userName.isEmpty ? '?' : anchor.userName.characters.first,
          style: context.textBody.copyWith(color: tokens.textSecondary),
        ),
      ),
    );
  }
}

/// 「进入直播间」描边按钮:accent 文字 + accent 描边
/// (真源 search_result_tile.dart:234-269 同构;真源仅直播中显示,同口径)。
class _AnchorEnterButton extends StatelessWidget {
  const _AnchorEnterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allSm,
      // 描边按钮:状态层取自身强调色(不盖掉描边语义),焦点可见。
      hoverColor: tokens.accent.withValues(alpha: 0.10),
      splashColor: AppStateLayer.splashOf(tokens.accent),
      highlightColor: AppStateLayer.pressedOf(tokens.accent),
      focusColor: AppStateLayer.focusOf(tokens.accent),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: AppRadius.allSm,
          border: Border.all(color: tokens.accent),
        ),
        child: Text(
          _kEnterRoomLabel,
          style: context.textCaption.copyWith(color: tokens.accent, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
