/// 自动中文化文本组件:标题类单行文本的统一翻译挂接点。
///
/// 自 zishu `lib/src/shared/presentation/widgets/translated_text.dart`
/// 移植;宿主无 riverpod,改为 StatefulWidget + GetX `ever` 侦听开关:
/// - 原文先渲染,译文到达后原位替换;
/// - 开关关(默认)/文本已是中文/翻译失败时恒显示原文,组件与调用方都
///   无需关心状态;
/// - 运行中切换开关:关 → 立即回退原文;开 → 重新请求(协调器缓存去重)。
library;

import 'package:pure_live/common/index.dart';
import 'package:pure_live/zishu_app/translation/translation_coordinator.dart';

class TranslatedText extends StatefulWidget {
  const TranslatedText({
    super.key,
    required this.text,
    this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;

  final TextStyle? style;
  final int? maxLines;
  final TextOverflow overflow;

  @override
  State<TranslatedText> createState() => _TranslatedTextState();
}

class _TranslatedTextState extends State<TranslatedText> {
  /// 请求代际:widget.text 换文后丢弃旧请求的迟到结果,防串文。
  int _seq = 0;

  String? _translated;

  /// 开关的 Rx(设置未就绪时为 null,视同关闭,只显原文)。
  RxBool? _switchRx;
  Worker? _worker;

  @override
  void initState() {
    super.initState();
    _switchRx = _tryFindSwitch();
    final rx = _switchRx;
    if (rx != null) {
      _worker = ever<bool>(rx, (_) => _syncTranslation());
    }
    _syncTranslation();
  }

  @override
  void didUpdateWidget(covariant TranslatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _syncTranslation();
  }

  @override
  void dispose() {
    _worker?.dispose();
    _worker = null;
    super.dispose();
  }

  /// 读开关;SettingsService 尚未注册等异常一律视同「关」,行为与现状
  /// (纯 Text 显原文)完全一致。
  RxBool? _tryFindSwitch() {
    try {
      return SettingsService.to.app.enableTitleTranslation;
    } catch (_) {
      return null;
    }
  }

  /// 触发翻译:开关关/无需翻译直接回原文;否则走协调器(内部缓存去重,
  /// 失败原样返回,Future 永不抛错)。
  void _syncTranslation() {
    final text = widget.text;
    final seq = ++_seq;
    final enabled = _switchRx?.v ?? false;
    if (!enabled || !needsChineseTranslation(text)) {
      _apply(null);
      return;
    }
    titleTranslationCoordinator.translate(text).then((result) {
      if (!mounted || seq != _seq) return;
      // 协调器失败/无需翻译时原样返回 → 不替换。
      _apply(result == text ? null : result);
    });
  }

  void _apply(String? value) {
    if (_translated == value) return;
    setState(() => _translated = value);
  }

  @override
  Widget build(BuildContext context) {
    return Text(_translated ?? widget.text, style: widget.style, maxLines: widget.maxLines, overflow: widget.overflow);
  }
}
