// zishu 聊天 tab(真源:zishu_flutter `side_panel/chat_tab.dart` `_ChatTab`
// 的纯聊天流子集,替换原 DanmakuTabView 四子页签)。
//
// 对齐口径:
// - 数据 watch `LivePlayController.danmakuMessages`(RxList,500 上限由
//   controller 维护、换房自动清空),只渲染 `LiveMessageType.chat`;
// - 正向 ListView.builder:最新在底(**非 reverse**),默认贴底跟随
//   (离底容差 24px + postFrame jumpTo);离底时累计新消息,「N 条新消息」
//   accent 胶囊浮层(Positioned bottom:8 居中)点击 220ms 动画滚底;
// - 行 = 单个 Text.rich 内联流(对齐真源 chat_row):等级牌 → 粉丝牌 →
//   用户名(协议色非白时用之,w600)→「：」→ 正文,行高 1.48;徽章复用
//   chat_badges.dart 的 zishuInlineBadge/ZishuChatUserLevelBadge/
//   ZishuChatFanBadge,按 room.platform 分站取真源同名分支的文字态规格
//   (斗鱼/虎牙/抖音/其余),粉丝牌显隐走 zishuFanBadgeVisible 闸门;
// - 顶部状态条:连接态圆点/文案 + 「刷新」重连钮(真源还带播放状态指示,
//   pure_live 无对应数据源,省);
// - 无输入框(对齐真源)。
//
// 与真源的差异(报告口径):
// - 正文保持纯文本:zishu 的表情图富文本段与翻译管线不迁;
// - 系统消息(`addSystemMessage` 来源,type 仍是 chat,userName ==
//   i18n('system_message'))走次级样式单渲。

import 'dart:async';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/danmaku/empty_danmaku.dart';
import 'package:pure_live/modules/live_play/controllers/live_play_controller.dart';
import 'package:pure_live/zishu/presentation/design_tokens.dart';
import 'package:pure_live/zishu/presentation/zishu_tokens.dart';

import 'chat_badges.dart';

/// 贴底判定容差(px,对齐真源)。
const double _kBottomTolerance = 24;

/// 行高(对齐真源 `_kChatLineHeight` = 1.48)与行字号(zishu 出厂
/// defaultChatFontSize = 14 → AppFontSize.subtitle)。
const double _kChatLineHeight = 1.48;
const double _kChatFontSize = AppFontSize.subtitle;

/// zishu 播放页侧栏「聊天」tab:纯聊天流(对齐 zishu `_ChatTab`)。
class ZishuChatTab extends StatefulWidget {
  const ZishuChatTab({super.key, required this.room});

  /// 当前房间快照:切房(didUpdateWidget 房间标识变化)时重置贴底/未读。
  final LiveRoom room;

  @override
  State<ZishuChatTab> createState() => _ZishuChatTabState();
}

class _ZishuChatTabState extends State<ZishuChatTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();

  /// 上一次 danmakuMessages 快照:controller 侧 `_flushDanmakuMessages`
  /// 复用旧元素引用后 `assignAll`(只追加 + 裁头),按对象身份 diff 出
  /// 本次真正新增的批次(每条只 ingest 一次,天然去重)。
  List<LiveMessage>? _lastSnapshot;

  /// 用户是否贴底:贴底时新消息自动跟随滚底;离底时累计「N 条新消息」。
  bool _pinnedToBottom = true;

  /// 离底期间累计的新消息条数(按钮文案)。
  int _unseenCount = 0;

  /// TabBarView 只挂载当前页,切 tab 会 dispose 离屏子页;keepAlive 保住
  /// 滚动位置与贴底状态(数据本体在 controller 的 RxList,无丢失风险)。
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // 用户上滑/下滑时维护贴底状态与「N 条新消息」显隐。
    _scrollController.addListener(_onScrollChanged);
  }

  @override
  void didUpdateWidget(covariant ZishuChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切房(State 复用,如同一树内换房):未读归零、恢复贴底 —— 新房间
    // 首批内容出现即默认滚到底部(对齐真源 didUpdateWidget 口径)。
    if (oldWidget.room.platform != widget.room.platform || oldWidget.room.roomId != widget.room.roomId) {
      _lastSnapshot = null;
      _unseenCount = 0;
      _pinnedToBottom = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollToBottom(animate: false);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  /// 与播放路由同实例(对齐 DanmakuTabView 的 `GetView<LivePlayController>`)。
  LivePlayController get _controller => Get.find<LivePlayController>();

  /// 弹幕引擎快照:EmptyDanmaku = 站点未接入(空态文案与状态条据此分叉)。
  bool _isSupported(LivePlayController controller) => controller.danmakuController.liveDanmaku is! EmptyDanmaku;

  bool _isConnected(LivePlayController controller) => controller.danmakuController.liveDanmaku.isConnected;

  /// 刷新 = 强制重建弹幕会话(connectRoom force,对齐真源「重新连接」语义;
  /// DanmakuController 内部有序列化与 epoch 保护,重复点击安全)。
  void _reconnect(LivePlayController controller) {
    unawaited(controller.danmakuController.connectRoom(controller.room, force: true));
  }

  // ---- 快照 diff(对齐真源 _diffSnapshot)----

  /// 返回相对上次快照真正新增的消息。controller 侧 assignAll 复用旧元素
  /// 引用,按「上次末条的对象身份」在新快照中定位新增后缀(覆盖纯追加与
  /// 「追加 + 裁头」两种形态);找不到身份链(中途整表替换/按谓词删行,
  /// 如屏蔽用户)时退化为全量重放。
  List<LiveMessage> _diffSnapshot(List<LiveMessage> snapshot) {
    final prev = _lastSnapshot;
    _lastSnapshot = snapshot;
    if (identical(prev, snapshot)) return const [];
    if (prev == null || prev.isEmpty || snapshot.isEmpty) return snapshot;
    final last = prev.last;
    for (var i = snapshot.length - 1; i >= 0; i -= 1) {
      if (identical(snapshot[i], last)) return snapshot.sublist(i + 1);
    }
    return snapshot;
  }

  /// 用户当前是否停在底部(容差 24px,避免像素误差导致误判)。
  bool get _isAtBottom {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    return position.pixels >= position.maxScrollExtent - _kBottomTolerance;
  }

  void _onScrollChanged() {
    if (!mounted) return;
    final atBottom = _isAtBottom;
    final changed = atBottom != _pinnedToBottom || (atBottom && _unseenCount > 0);
    _pinnedToBottom = atBottom;
    if (atBottom) _unseenCount = 0;
    if (changed) setState(() {});
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (!animate) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut).then((_) {
      // ListView.builder 惰性构建:尾部行未 realize 时 maxScrollExtent 可能
      // 滞后(只统计已构建行),落定后按最新 extent 校正一次(对齐真源)。
      if (!mounted || !_scrollController.hasClients || !_pinnedToBottom) {
        return;
      }
      final position = _scrollController.position;
      if (position.pixels < position.maxScrollExtent - 0.5) {
        _scrollController.jumpTo(position.maxScrollExtent);
      }
    });
  }

  /// 新消息到达后:贴底时自动跟随滚底(滚动放 post-frame:首帧 ListView
  /// 尚未挂载时也能在挂载后跳到底部);离底时仅累计未读。
  void _onNewRows(int added) {
    if (added <= 0) return;
    if (!_pinnedToBottom) {
      _unseenCount += added;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollToBottom(animate: false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 要求
    final tokens = context.tokens;
    // 控制器未注册(直接热预览等边缘,与 ZishuPlayView 同口径的占位等待)。
    if (!Get.isRegistered<LivePlayController>()) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text('聊天暂不可用', textAlign: TextAlign.center, style: context.textCaption),
        ),
      );
    }
    final controller = _controller;
    return Obx(() {
      final messages = controller.danmakuMessages.toList(growable: false);
      final added = _diffSnapshot(messages);
      _onNewRows(added.where((message) => message.type == LiveMessageType.chat).length);
      // 连接态是引擎上的普通 bool(非 Rx):放在 Obx 内读取,消息流(含
      // DanmakuController 的连接状态系统消息)触发重建时即刷新快照。
      final supported = _isSupported(controller);
      final connected = _isConnected(controller);
      // 纯聊天流:只保留 chat 类型(online 是人数更新、superChat 走醒目留言、
      // gift 不支持,均不进聊天列表)。
      final rows = [
        for (final message in messages)
          if (message.type == LiveMessageType.chat) message,
      ];
      final newCount = _pinnedToBottom ? 0 : _unseenCount;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildStatusBar(context, tokens, supported: supported, connected: connected, controller: controller),
          Expanded(
            child: Stack(
              children: [
                if (rows.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        // 空态两文案(无既有 i18n key,中文常量,对齐 zishu 同文案)。
                        supported ? '暂无弹幕，等待水友发言…' : '当前站点暂不支持弹幕',
                        textAlign: TextAlign.center,
                        style: context.textCaption,
                      ),
                    ),
                  )
                else
                  // 正向列表:最新在底(非 reverse),默认贴底跟随。
                  ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm),
                    itemCount: rows.length,
                    itemBuilder: (context, index) =>
                        _ZishuChatRow(message: rows[index], site: widget.room.platform ?? ''),
                  ),
                if (newCount > 0)
                  // 对齐真源 .chat-new-bar:底部水平居中,距底 8。
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 8,
                    child: Center(
                      child: _NewMessagesButton(
                        count: newCount,
                        onTap: () {
                          setState(() => _unseenCount = 0);
                          _scrollToBottom();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  /// 顶部状态条(高 31,对齐真源):连接态圆点 + 文案 + 「刷新」重连钮。
  Widget _buildStatusBar(
    BuildContext context,
    ZishuTokens tokens, {
    required bool supported,
    required bool connected,
    required LivePlayController controller,
  }) {
    // 连接态短文案无既有 i18n key,中文常量(对齐 zishu 同文案)。
    final String label;
    final Color dotColor;
    if (!supported) {
      label = '弹幕不支持';
      dotColor = tokens.textSecondary;
    } else if (connected) {
      label = '弹幕已连接';
      dotColor = tokens.liveBadge;
    } else {
      label = '弹幕未连接';
      dotColor = tokens.textSecondary;
    }
    return Container(
      height: MediaQuery.textScalerOf(context).scale(31),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: tokens.surfaceSoft,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 7, color: dotColor),
          const SizedBox(width: 5),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.textCaption),
          ),
          const Spacer(),
          // 对齐真源:图标 + 「刷新」文字的小按钮(高 24)。文案用既有
          // i18n key `refresh`;tooltip 无对应 key,中文常量。
          Tooltip(
            message: '重新连接弹幕',
            child: TextButton(
              onPressed: supported ? () => _reconnect(controller) : null,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 24),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: tokens.textSecondary,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, size: 13),
                  const SizedBox(width: 2),
                  Text(i18n('refresh'), style: const TextStyle(fontSize: AppFontSize.caption, height: 1)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 聊天消息行:单个 Text.rich 内联流(对齐真源 chat_row `_ChatRow` 的单段落
/// 结构 —— 徽章/昵称/正文同处一个段落,正文折行时第二行从段落最左顶格起排)。
class _ZishuChatRow extends StatelessWidget {
  const _ZishuChatRow({required this.message, required this.site});

  final LiveMessage message;

  /// 站点 id(LiveRoom.platform:'douyu'/'huya'/'douyin'/'bilibili'…),
  /// 徽章分站渲染依据(对齐真源 `_ChatRowData.site`)。
  final String site;

  /// 系统消息:`addSystemMessage` 固定以 i18n('system_message')(zh
  /// 「系统消息」)作 userName、type 仍是 chat,模型上无独立 type 可分,
  /// 按用户名判定后整行走次级样式(无徽章/用户名前缀)。
  bool get _isSystem => message.userName == i18n('system_message');

  /// 用户名颜色:协议色非白(平台给了弹幕色)才用之,白色 = 默认 → 次级色
  /// (engines 侧 `color == 0` 统一映射为 `LiveMessageColor.white`)。
  Color _userColor(BuildContext context) {
    final color = message.color;
    if (color.r == 255 && color.g == 255 && color.b == 255) return context.tokens.textSecondary;
    return Color.fromARGB(255, color.r, color.g, color.b);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    if (_isSystem) {
      return Text(
        message.message,
        style: TextStyle(fontSize: _kChatFontSize, height: _kChatLineHeight, color: tokens.textSecondary),
      );
    }
    // 单段落内联流(对齐真源:固定行高 strut,徽章 middle 对齐 + 行尾 2px)。
    return Text.rich(
      strutStyle: StrutStyle(fontSize: _kChatFontSize, height: _kChatLineHeight, forceStrutHeight: true),
      TextSpan(
        children: [
          // 徽章顺序对齐真源:平台用户等级 pill 在前、粉丝牌在后
          // (真源 chat_row.dart:107-119;真源 userLevel gate 是 >0,我们
          // 是字符串非空白,引擎侧只在 >0 时填,语义一致)。
          if (message.userLevel.trim().isNotEmpty)
            zishuInlineBadge(ZishuChatUserLevelBadge(site: site, level: message.userLevel)),
          // 粉丝牌缺字段不渲染(现口径;zishuFanBadgeVisible 另对抖音要求
          // 等级非空 —— 圆盘只承载数字,空等级会画出空心红圆)。
          if (zishuFanBadgeVisible(site: site, name: message.badgeName, level: message.badgeLevel))
            zishuInlineBadge(
              ZishuChatFanBadge(
                site: site,
                name: message.badgeName!,
                level: message.badgeLevel,
                colorStart: message.badgeColorStart,
                colorEnd: message.badgeColorEnd,
                colorBorder: message.badgeColorBorder,
              ),
            ),
          TextSpan(
            text: message.userName,
            style: TextStyle(
              fontSize: _kChatFontSize,
              height: _kChatLineHeight,
              fontWeight: FontWeight.w600,
              color: _userColor(context),
            ),
          ),
          TextSpan(
            text: '：',
            style: TextStyle(fontSize: _kChatFontSize, height: _kChatLineHeight, color: tokens.textSecondary),
          ),
          // 正文保持纯文本(表情图富文本段不迁,见文件头注释)。
          TextSpan(
            text: message.message,
            style: TextStyle(fontSize: _kChatFontSize, height: _kChatLineHeight, color: tokens.textPrimary),
          ),
        ],
      ),
    );
  }
}

/// 「N 条新消息」跳底按钮:用户离开底部且有新消息时浮在列表底部居中
/// (对齐真源 `_NewMessagesButton`:accent 实底胶囊,亮底白字)。
class _NewMessagesButton extends StatelessWidget {
  const _NewMessagesButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.tokens.accent,
      borderRadius: AppRadius.allMd,
      child: InkWell(
        borderRadius: AppRadius.allMd,
        onTap: onTap,
        // accent 实底上用白低 alpha 提亮(不引入新色相,不改尺寸)。
        hoverColor: AppOnBright.white.withValues(alpha: 0.12),
        splashColor: AppStateLayer.splashOf(AppOnBright.white),
        highlightColor: AppStateLayer.pressedOf(AppOnBright.white),
        focusColor: AppStateLayer.focusOf(AppOnBright.white),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            // 无既有 i18n key,中文常量(对齐 zishu 同文案)。
            '$count 条新消息',
            style: const TextStyle(
              fontSize: AppFontSize.bodySecondary,
              height: 1.1,
              color: AppOnBright.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
