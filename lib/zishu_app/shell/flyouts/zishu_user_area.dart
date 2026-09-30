import 'package:remixicon/remixicon.dart';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

/// 顶栏右侧账号区占位(移植 zishu 真源
/// `lib/src/app/shell/user_area.dart` 的 `_UserAvatar` 容器形态:
/// 圆形头像钮 + `PopupMenuButton` 菜单)。
///
/// 本轮为本地占位(无 data-server 账号体系):菜单三项 ——
/// 历史记录(`RoutePath.kHistory`)/ 设置(壳层既有设置页入口)/
/// 关于(`RoutePath.kAbout`)。
class ZishuUserArea extends StatelessWidget {
  const ZishuUserArea({super.key, required this.onOpenSettings});

  /// 打开 zishu 设置页(与顶栏设置钮同一入口,由壳层注入)。
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return PopupMenuButton<String>(
      key: const Key('zishu-nav-user'),
      tooltip: i18n('account'),
      offset: const Offset(0, 30),
      color: tokens.surface,
      onSelected: (action) {
        switch (action) {
          case 'history':
            Get.toNamed(RoutePath.kHistory);
          case 'settings':
            onOpenSettings();
          case 'about':
            Get.toNamed(RoutePath.kAbout);
        }
      },
      itemBuilder: (menuContext) => [
        _item(menuContext, 'history', Icons.history_rounded, i18n('history')),
        _item(menuContext, 'settings', Remix.settings_5_line, i18n('settings_title')),
        _item(menuContext, 'about', Remix.information_line, i18n('about')),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: tokens.accent,
          child: Icon(Icons.person_outline_rounded, size: 16, color: AppOnBright.white),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(BuildContext context, String value, IconData icon, String label) {
    final tokens = context.tokens;
    return PopupMenuItem(
      value: value,
      height: 34,
      child: Row(
        children: [
          Icon(icon, size: 15, color: tokens.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(fontSize: AppFontSize.bodySecondary, color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }
}
