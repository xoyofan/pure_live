/// 平台凭证弹框(2026-10 任务:真源锚点 `zishu_flutter@5990d1c` 形态照抄)。
///
/// 真源把凭证从独立 `/user` 页收编为弹框(`UserCredentialsDialog`):凭证是
/// 低频配置项,不值得占一个路由页;弹框宽 640 / 内容区上限高 560,平台条目
/// 折叠态看状态徽标 + 脱敏摘要,展开后多行粘贴 + 保存 / 清除。
///
/// 我方适配(架构不同,形态不变):
/// - 平台清单 = [CookieSettingsController] 的**全部** cookie 字段
///   (bilibili/huya/douyu/douyin/kuaishou/twitch/soop/yy,共 8 个);真源的
///   小红书在我方**没有存储位**(全仓 grep 无 xhs cookie 字段),故不收录,
///   真源唯一的键名文本模板(`a1=; web_session=`)无处落——键名骨架改走
///   条目说明行与输入框 hint(见 [_kSiteTable] 各键注释)。
/// - 读写走 `SettingsService.to.cookieManager`(即 [CookieSettingsController])
///   的 hiveString 字段,**不直接碰 box**;旧账号页(`AccountPage` → 各平台
///   cookie 页)原样保留,本弹框只收编 zishu 设置内的入口。
/// - 斗鱼的多段键(`dy_auth` 登录 + `LTP0`/`dy_did` 续期凭据)沿用旧页
///   `douyu_cookie_controller.dart` 的口径:粘贴 passport Cookie 时只取走
///   LTP0/dy_did、不顶替已存登录 Cookie,保存时记录 `douyuCookieSavedAt`。
///
/// 文案优先复用现有 i18n key;缺失的(标题/徽标/校验提示等)按
/// `zishu_settings_view.dart` 先例用中文常量兜底并注明建议补的 key。
library;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/common/services/settings/cookie_settings_controller.dart';
import 'package:pure_live/common/services/settings/cookie_value.dart';
import 'package:pure_live/core/site/douyu/douyu_utils.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/widgets/platform_icon.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

import 'zishu_settings_rows.dart' show zishuDenseInput;

// ---------------------------------------------------------------------------
// 缺失 i18n key 的中文常量兜底(建议补 key,见各注释)
// ---------------------------------------------------------------------------

/// 弹框标题(真源同文案;建议补 `platform_credentials`)。
const String _kDialogTitle = '平台凭证';

/// 弹框顶部说明(真源同文案;建议补 `platform_credentials_desc`)。
const String _kDialogDesc = '凭证仅存本机，用于解析需要登录态的站点；保存后仅显示脱敏摘要。';

/// 哔哩哔哩粘贴提示(解析侧按 `DedeUserID` 取 uid,见
/// `bilibili_site.dart`;无现成 key,建议补 `bilibili_cookie_hint`)。
const String _kBilibiliHint = '粘贴完整 Cookie（含 DedeUserID）';

/// 状态徽标两态(真源同文案;建议补 `credential_configured` / `credential_unconfigured`)。
const String _kConfiguredLabel = '已配置';
const String _kUnconfiguredLabel = '未配置';

/// 条目展开/收起按钮(真源同文案;建议补 `credential_configure` / `collapse`)。
const String _kConfigureLabel = '配置';
const String _kCollapseLabel = '收起';

/// 保存 / 清除成功的提示(建议补 `credential_cleared`)。
const String _kSavedToast = '已保存到本机';
const String _kClearedToast = '已清除该平台凭证';

/// 保存校验提示(真源同文案;建议补 `credential_empty_error` / `credential_too_short_error`)。
const String _kEmptyError = '请先粘贴 Cookie 或 Token';
const String _kTooShortError = '内容过短，请粘贴完整的 Cookie 串';

/// 脱敏摘要:过短值整段不给看,只报长度(真源 `maskedPreview` 口径)。
String _maskedPreview(String value) {
  final text = value.trim();
  if (text.length <= 12) return '已保存 ${text.length} 字符';
  return '${text.substring(0, 6)}…${text.substring(text.length - 4)}（${text.length} 字符）';
}

// ---------------------------------------------------------------------------
// 平台清单
// ---------------------------------------------------------------------------

/// 凭证平台表:`(站点 id, 键名骨架说明)`——与
/// [CookieSettingsController] 的 cookie 字段一一对应;键名骨架取自各解析侧
/// **实际消费**的 Cookie 键(折叠态就可见,展开后 hint 再次提示)。
const List<(String, String?)> _kSiteTable = [
  // bilibili_site.dart 按 DedeUserID 正则取 uid。
  ('bilibili', 'DedeUserID=…'),
  // huya_site.dart parseViewerUidFromCookie 按 yyuid 取 uid。
  ('huya', 'yyuid=…'),
  // douyu_utils.dart:dy_auth 是会话,LTP0 / dy_did 是续期凭据(单独字段存)。
  ('douyu', 'dy_auth=… · LTP0 / dy_did 另存'),
  ('douyin', null),
  ('kuaishou', null),
  // twitch_cookie_tip:auth-token 与 login 用于读取聊天。
  ('twitch', 'auth-token=…'),
  ('soop', null),
  ('yy', null),
];

/// 各站点的粘贴提示(hint 空时兜底为条目说明):复用各平台旧 cookie 页的
/// 现成 i18n key,哔哩哔哩缺失走中文常量。
String _hintFor(String id) => switch (id) {
  'bilibili' => _kBilibiliHint,
  'huya' => i18n('huya_cookie_hint'),
  'douyu' => i18n('douyu_cookie_hint'),
  'douyin' => i18n('douyin_cookie_hint'),
  'kuaishou' => i18n('kuaishou_cookie_hint'),
  'twitch' => i18n('twitch_cookie_hint'),
  'soop' => i18n('soop_cookie_hint'),
  'yy' => i18n('cookie_hint', args: {'name': i18n('site_yy')}),
  _ => '',
};

/// 站点 id → cookie 字段(唯一写入口,经 [CookieSettingsController],不碰 box)。
RxString _cookieFieldOf(CookieSettingsController cookie, String id) => switch (id) {
  'bilibili' => cookie.bilibiliCookie,
  'huya' => cookie.huyaCookie,
  'douyu' => cookie.douyuCookie,
  'douyin' => cookie.douyinCookie,
  'kuaishou' => cookie.kuaishouCookie,
  'twitch' => cookie.twitchCookie,
  'soop' => cookie.soopCookie,
  'yy' => cookie.yyCookie,
  _ => throw StateError('未知的凭证平台: $id'),
};

// ---------------------------------------------------------------------------
// 弹框
// ---------------------------------------------------------------------------

/// 打开平台凭证弹框(zishu 设置弹窗「平台」组入口用)。
///
/// 形态对齐真源 `showUserCredentialsDialog`:showDialog + AlertDialog;
/// barrier 色走本仓 tokens(与 `openZishuSettingsDialog` 同一弹窗家族)。
Future<void> showZishuCredentialsDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: context.tokens.barrier,
    builder: (_) => const ZishuCredentialsDialog(),
  );
}

/// 平台凭证对话框:平台条目渲染、粘贴 + 保存 / 清除。
class ZishuCredentialsDialog extends StatelessWidget {
  const ZishuCredentialsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return AlertDialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.allLg),
      title: Text(
        _kDialogTitle,
        key: const Key('zishu-credentials-dialog'),
        style: context.textTitle.copyWith(fontSize: AppFontSize.subtitle, fontWeight: FontWeight.w600),
      ),
      // 弹框内距对齐真源(20/8/12 落到 xl/sm/md 档)。
      contentPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.sm),
      actionsPadding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
      content: SizedBox(
        width: 640,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                  child: Text(_kDialogDesc, style: context.textCaption.copyWith(color: tokens.textSecondary)),
                ),
                for (final site in _kSiteTable)
                  _SiteCredentialTile(key: Key('zishu-credential-${site.$1}'), site: site),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const Key('zishu-credentials-close'),
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: tokens.textSecondary, minimumSize: const Size(0, 30)),
          child: Text(i18n('close')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 单平台条目
// ---------------------------------------------------------------------------

/// 单个平台的凭证条目:折叠态看状态徽标 + 脱敏摘要,展开后粘贴 + 保存 / 清除。
class _SiteCredentialTile extends StatefulWidget {
  const _SiteCredentialTile({super.key, required this.site});

  final (String, String?) site;

  @override
  State<_SiteCredentialTile> createState() => _SiteCredentialTileState();
}

class _SiteCredentialTileState extends State<_SiteCredentialTile> {
  final TextEditingController _controller = TextEditingController();

  /// 折叠态只显示状态与脱敏摘要;展开态才出输入框。
  bool _expanded = false;

  /// 输入校验提示(空串 = 无提示)。
  String _error = '';

  /// 是否已把存储里的当前值灌进输入框(展开时做一次,避免覆盖用户编辑)。
  bool _prefilled = false;

  /// 斗鱼的续期凭据两字段(仅斗鱼条目创建;其余平台为 null)。
  TextEditingController? _ltp0Controller;
  TextEditingController? _didController;

  bool get _isDouyu => widget.site.$1 == 'douyu';

  CookieSettingsController get _cookie => SettingsService.to.cookieManager;

  RxString get _field => _cookieFieldOf(_cookie, widget.site.$1);

  @override
  void initState() {
    super.initState();
    if (_isDouyu) {
      _ltp0Controller = TextEditingController(text: _cookie.douyuLtp0.v);
      _didController = TextEditingController(text: _cookie.douyuDid.v);
      // 与旧页同口径:粘贴内容里带 LTP0 / dy_did 就地填进两字段
      // (只填找得到的,绝不反向清空,见 douyu_cookie_controller.dart)。
      _controller.addListener(_absorbPastedCredentials);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _ltp0Controller?.dispose();
    _didController?.dispose();
    super.dispose();
  }

  /// Copies `LTP0` / `dy_did` out of the pasted cookie into their fields
  /// (douyu_cookie_controller.dart `_absorbPastedCredentials` 的等价实现)。
  void _absorbPastedCredentials() {
    final pasted = _controller.text;
    if (pasted.trim().isEmpty) return;
    final ltp0 = DouyuUtils.cookieField(pasted, DouyuUtils.longTermTokenName);
    if (ltp0 != null && ltp0.isNotEmpty && ltp0 != _ltp0Controller!.text) {
      _ltp0Controller!.text = ltp0;
    }
    final did = DouyuUtils.cookieField(pasted, DouyuUtils.deviceIdName);
    if (did != null && did.isNotEmpty && did != _didController!.text) {
      _didController!.text = did;
    }
  }

  void _toggle(String value) {
    setState(() {
      _expanded = !_expanded;
      _error = '';
      if (_expanded && !_prefilled) {
        // 展开时回显当前值(便于局部修改;凭据只在本机与本弹框内存里)。
        // 真源对未配置的多键平台(xhs)还会预填键名文本模板,我方无对应
        // 存储位,未配置即空串,键名骨架走说明行与 hint。
        _controller.text = value;
        _prefilled = true;
      }
    });
  }

  void _save() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = _kEmptyError);
      return;
    }
    if (text.length < 8) {
      setState(() => _error = _kTooShortError);
      return;
    }
    final normalized = normalizeAccountCookie(text);
    if (_isDouyu) {
      // 斗鱼两段键甄别(旧页 douyu_cookie_controller.setCookie 同口径):
      // passport 请求的 Cookie 只有续期凭据没有 dy_auth,存成登录 Cookie
      // 会被斗鱼风控 403 —— 只取走 LTP0/dy_did,保留已存登录。
      final pastedIsSession = DouyuUtils.sessionToken(normalized) != null;
      if (!pastedIsSession && _hasDouyuCredentialFields(normalized)) {
        _writeDouyuAuxFields();
        ToastUtil.show(i18n('douyu_cookie_credentials_only'));
        return;
      }
      _field.v = normalized;
      _writeDouyuAuxFields();
      // dy_auth 七天过期,过期时点是唯一线索,保存即记录(旧页同口径)。
      _cookie.douyuCookieSavedAt.v = normalized.isEmpty ? 0 : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    } else {
      _field.v = normalized;
    }
    setState(() => _error = '');
    ToastUtil.show(_kSavedToast);
  }

  void _writeDouyuAuxFields() {
    _cookie.douyuLtp0.v = _ltp0Controller!.text.trim();
    _cookie.douyuDid.v = _didController!.text.trim();
  }

  void _clear() {
    // 与旧账号页退出登录同口径:斗鱼只清登录 Cookie,续期凭据(LTP0/dy_did)
    // 保留(它们不是登录态,清了反而丢掉自动续期能力)。
    _field.v = '';
    if (_isDouyu) _cookie.douyuCookieSavedAt.v = 0;
    setState(() {
      _controller.clear();
      _error = '';
    });
    ToastUtil.show(_kClearedToast);
  }

  /// passport 请求特征:续期凭据键在场(旧页 `_hasCredentialFields` 同表)。
  static bool _hasDouyuCredentialFields(String cookie) {
    const credentialFields = <String>['LTP0', 'acf_stk', 'acf_ccn', 'acf_ltkid', 'acf_ssid'];
    return credentialFields.any((name) => DouyuUtils.cookieField(cookie, name) != null);
  }

  /// 名称行下的说明:斗鱼跟会话状态走(过期/游客要警告),其余平台固定展示
  /// 键名骨架(无骨架的退到粘贴提示)。
  String _captionFor(String value) {
    if (_isDouyu) {
      return switch (DouyuUtils.sessionState(value)) {
        DouyuSessionState.none => i18n('set_cookie'),
        DouyuSessionState.valid => i18n('cookie_saved_local'),
        DouyuSessionState.expiredRefreshable => i18n('douyu_session_renewable'),
        DouyuSessionState.guest || DouyuSessionState.expired => i18n('douyu_session_needs_cookie'),
      };
    }
    return widget.site.$2 ?? _hintFor(widget.site.$1);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final id = widget.site.$1;
    return Obx(() {
      final value = _field.v;
      final configured = value.trim().isNotEmpty;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: AppRadius.allMd,
            border: Border.all(color: tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PlatformIcon(id: id, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18nOr('site_$id', id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textBody.copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          _captionFor(value),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.textCaption.copyWith(color: tokens.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  _StatusBadge(key: Key('zishu-credential-status-$id'), configured: configured),
                  const SizedBox(width: AppSpacing.xs),
                  TextButton(
                    key: Key('zishu-credential-toggle-$id'),
                    onPressed: () => _toggle(value),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.accent,
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                    child: Text(_expanded ? _kCollapseLabel : _kConfigureLabel),
                  ),
                ],
              ),
              if (configured && !_expanded)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    _maskedPreview(value),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textCaption.copyWith(color: tokens.textSecondary),
                  ),
                ),
              if (_expanded) ...[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  key: Key('zishu-credential-input-$id'),
                  controller: _controller,
                  minLines: 2,
                  maxLines: 5,
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.multiline,
                  style: context.textBody,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: _hintFor(id),
                    hintMaxLines: 3,
                    hintStyle: context.textCaption.copyWith(color: tokens.textSecondary),
                    filled: true,
                    fillColor: tokens.surfaceRaised,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.allSm,
                      borderSide: BorderSide(color: tokens.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.allSm,
                      borderSide: BorderSide(color: tokens.accent),
                    ),
                  ),
                ),
                if (_isDouyu) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ltp0Controller,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: zishuDenseInput(context, i18n('douyu_ltp0_label'), hint: i18n('douyu_ltp0_hint')),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: TextField(
                          controller: _didController,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: zishuDenseInput(context, i18n('douyu_did_label'), hint: i18n('douyu_did_hint')),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      _error,
                      key: Key('zishu-credential-error-$id'),
                      style: context.textCaption.copyWith(color: tokens.error),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    FilledButton(
                      key: Key('zishu-credential-save-$id'),
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: tokens.accent,
                        minimumSize: const Size(0, 30),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      ),
                      child: Text(i18n('save')),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    TextButton(
                      key: Key('zishu-credential-clear-$id'),
                      onPressed: configured ? _clear : null,
                      style: TextButton.styleFrom(
                        foregroundColor: tokens.textSecondary,
                        minimumSize: const Size(0, 30),
                      ),
                      child: Text(i18n('clear')),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// 状态徽标:已配置 / 未配置(真源 `_StatusBadge` 同款:淡底 + 同色描边)。
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({super.key, required this.configured});

  final bool configured;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = configured ? tokens.success : tokens.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: AppRadius.allSm,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        configured ? _kConfiguredLabel : _kUnconfiguredLabel,
        style: context.textCaption.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
