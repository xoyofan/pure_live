import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/services.dart' show rootBundle;

/// pure_live 打包的 zh 文案表(zh.json)。zishu UI(lib/src)不包
/// EasyLocalization,`tr()` 恒返回 key 本身——pure_live 适配器里 111 处
/// `i18n()` 字段(分类名/画质名/公告)会以原始 key 漏到界面上。启动时把
/// zh.json 载入作回落:文案真源仍是 pure_live 自己的翻译文件,不建第二份
/// 映射(用户口径 2026-10-02:字段映射完全用 purelive 的,不要 zishu 的)。
Map<String, String>? _zhTextFallback;

/// 首帧前调用一次(rootBundle 读打包资产);失败置空表,行为退回原样。
Future<void> ensureZhTextFallback() async {
  if (_zhTextFallback != null) return;
  try {
    final raw = await rootBundle.loadString('assets/translations/zh.json');
    final decoded = json.decode(raw);
    _zhTextFallback = decoded is Map
        ? {
            for (final entry in decoded.entries)
              if (entry.value is String) entry.key.toString(): entry.value as String,
          }
        : const <String, String>{};
  } catch (_) {
    _zhTextFallback = const <String, String>{};
  }
}

String i18n(String key, {Map<String, String>? args}) {
  final translated = tr(key, namedArgs: args);
  if (translated != key) return translated;
  // 旧 UI(easy_localization 已初始化)按 locale 命中或缺失返回 key;
  // zishu UI 未初始化也返回 key —— 两种情形都用 zh.json 回落直出中文。
  final fallback = _zhTextFallback?[key];
  if (fallback == null) return translated;
  if (args == null || args.isEmpty) return fallback;
  return fallback.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) => args[match.group(1)] ?? match.group(0)!);
}

/// Returns a stable label while EasyLocalization is still loading its first
/// asset bundle. Calling [tr] before that point logs a false missing-key
/// warning and briefly renders the raw key in desktop chrome.
String i18nOr(String key, String fallback, {Map<String, String>? args}) {
  if (!trExists(key)) return fallback;
  return i18n(key, args: args);
}

bool i18nExists(String key) => trExists(key);
