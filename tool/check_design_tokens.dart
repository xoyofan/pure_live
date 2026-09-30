// design token 基线对照 —— 校验本仓 lib/zishu/presentation/design_tokens.dart 与
// zishu 真源仓库同名 token 的取值是否漂移。
//
// 移植自 zishu 真源仓库的 tool/check_design_tokens.dart(零依赖、纯 Dart、退出码
// 约定与输出风格沿用之);但对照语义按本仓任务书重写:真源脚本扫 lib/src 的裸值
// 并与基线 JSON 对账,本脚本解析两仓 design_tokens.dart 的常量值逐名对照。
//
// 纯 Dart 实现(只 import dart:io + dart:convert),不 import Flutter、不加依赖:
//   dart run tool/check_design_tokens.dart
//   dart run tool/check_design_tokens.dart --help
//
// ⚠️ 真源路径 [_sourceTokenPath] 写死为本机绝对路径(F:\project\zishu_flutter),
// 仅供本机对照用途;换机器/换盘符时改这一个常量即可。本脚本只读两份被对照文件,
// 不做网络访问,也不修改它们 —— 发现漂移时输出清单交主会话裁决。
// 对照范围只有 design_tokens.dart;主题 token(zishu_tokens.dart)不在本次范围。
//
// 退出码: 0 = 无同名 token 漂移; 1 = 发现同名漂移; 2 = 脚本自身异常/用法错误。
//
// 对照口径(比「值」,不比「格式」):
//   1. 解析: 只取类内 `static` 字段声明(const/final/可变均可)。声明头里带 `(` 的
//      是方法/函数(参数表),跳过 —— 块体(`{...}`)跳到配平的 `}` 收口,表达式体
//      (`=>`)跳到 `;`。多行声明累积到「括号配平且在引号外遇到 `;`」为止,行内
//      `//` 注释剥离;一条声明只支持一个 `名字 = 值`(两份文件均如此)。
//   2. 值归一: 去掉值内独立的 `const` 修饰字 → 去掉全部空白 → 去掉紧贴 `]`/`)`
//      的尾逗号(多行格式化下尾逗号可出现在任意层闭括号前,故全局剥离)。
//      归一后逐字相等才算「一致」—— 换行/缩进/参数换行/尾逗号等格式差异不算
//      漂移,数值/字面量/参数差异才算。
//   3. 状态: 同名同值=一致;同名不同值=漂移(退出码 1);仅我方有=我方扩展
//      (不算漂移);仅真源有=真源独有(不算漂移,仅提示)。

import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------------------
// 配置
// ---------------------------------------------------------------------------

/// 本仓被对照文件(相对仓库根;仓库根由脚本位置推导,退化到当前工作目录)。
const String _ourTokenRelativePath = 'lib/zishu/presentation/design_tokens.dart';

/// zishu 真源仓库的对照文件 —— 写死为本机绝对路径,仅供本机对照用途
/// (见文件头注释;换机器/换盘符只需改这里)。
const String _sourceTokenPath = r'F:\project\zishu_flutter\lib\src\shared\presentation\design_tokens.dart';

/// 表格/摘要里单个值的最大展示宽度(超出截断加省略号;漂移明细始终给全量)。
const int _valueDisplayWidth = 44;

// ---------------------------------------------------------------------------
// 数据结构
// ---------------------------------------------------------------------------

/// 一条解析出的 token:类内 `static` 字段。
class _Token {
  _Token(this.key, this.kind, this.value, this.line);

  /// 全名:`类名.字段名`(无类上下文时为裸字段名)。
  final String key;

  /// const / final / var(可变 static)。仅展示用,不参与对照。
  final String kind;

  /// `=` 与收尾之间的原始值文本(已剥离行内注释,保留原始换行)。
  final String value;

  /// 声明起始行(1-based,仅用于异常定位与漂移明细)。
  final int line;

  /// 对照用归一值(去 const 字 / 去空白 / 去尾逗号),口径见文件头注释。
  String get normalized => _normalizeValue(value);
}

/// 一份 token 文件的解析结果。
class _TokenFile {
  _TokenFile(this.path, this.tokens);

  final String path;
  final Map<String, _Token> tokens;
}

/// 对照表里的一行。
class _Row {
  _Row(this.key, this.status, this.ours, this.source);

  final String key;
  final String status; // 一致 / 漂移 / 我方扩展 / 真源独有
  final _Token? ours;
  final _Token? source;
}

class _UsageException implements Exception {
  _UsageException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ---------------------------------------------------------------------------
// 入口
// ---------------------------------------------------------------------------

void main(List<String> args) {
  try {
    exit(_run(args));
  } on _UsageException catch (error) {
    stderr.writeln('[design-token-baseline] ${error.message}');
    exit(2);
  } catch (error, stackTrace) {
    stderr.writeln('[design-token-baseline] 脚本异常: $error');
    stderr.writeln(stackTrace.toString());
    exit(2);
  }
}

int _run(List<String> args) {
  for (final String arg in args) {
    switch (arg) {
      case '-h':
      case '--help':
        stdout.writeln(_usageText());
        return 0;
      default:
        throw _UsageException('未知参数: $arg\n\n${_usageText()}');
    }
  }

  final Directory repoRoot = _resolveRepoRoot();
  final _TokenFile ours = _parseTokenFile(path: '${repoRoot.path}/$_ourTokenRelativePath', label: '我方');
  final _TokenFile source = _parseTokenFile(path: _sourceTokenPath, label: '真源');

  // ---- 逐名对照 ----
  final List<String> keys = <String>{...ours.tokens.keys, ...source.tokens.keys}.toList()..sort();

  final List<_Row> rows = <_Row>[];
  int same = 0;
  int drift = 0;
  int oursOnly = 0;
  int sourceOnly = 0;
  for (final String key in keys) {
    final _Token? o = ours.tokens[key];
    final _Token? s = source.tokens[key];
    final String status;
    if (o != null && s != null) {
      if (o.normalized == s.normalized) {
        status = '一致';
        same++;
      } else {
        status = '漂移';
        drift++;
      }
    } else if (o != null) {
      status = '我方扩展';
      oursOnly++;
    } else {
      status = '真源独有';
      sourceOnly++;
    }
    rows.add(_Row(key, status, o, s));
  }

  // ---- 输出 ----
  final int keyWidth = keys.fold<int>(12, (int w, String k) => k.length > w ? k.length : w);
  int ourWidth = 6;
  int sourceWidth = 6;
  for (final _Row row in rows) {
    final int o = _display(row.ours?.value).length;
    final int s = _display(row.source?.value).length;
    if (o > ourWidth) {
      ourWidth = o;
    }
    if (s > sourceWidth) {
      sourceWidth = s;
    }
  }
  final int tableWidth = keyWidth + ourWidth + sourceWidth + 9; // 3 组 " | "

  stdout.writeln('== design token 基线对照 ==');
  stdout.writeln('我方: $_ourTokenRelativePath (${ours.tokens.length} 个 token)');
  stdout.writeln('真源: $_sourceTokenPath (${source.tokens.length} 个 token)');
  stdout.writeln('对照口径: 归一(去空白/去 const 字/去尾逗号)后逐字比对,格式差异不算漂移');
  stdout.writeln('-' * tableWidth);
  stdout.writeln(
    '${'token'.padRight(keyWidth)} | '
    '${'我方值'.padRight(ourWidth)} | '
    '${'真源值'.padRight(sourceWidth)} | 结论',
  );
  for (final _Row row in rows) {
    stdout.writeln(
      '${row.key.padRight(keyWidth)} | '
      '${_display(row.ours?.value).padRight(ourWidth)} | '
      '${_display(row.source?.value).padRight(sourceWidth)} | ${row.status}',
    );
  }

  final List<_Row> drifted = rows.where((_Row row) => row.status == '漂移').toList();
  if (drifted.isNotEmpty) {
    stdout.writeln('-' * tableWidth);
    stdout.writeln('漂移明细(全量值;本脚本不改 design_tokens.dart,交主会话裁决):');
    for (final _Row row in drifted) {
      stdout.writeln('  ${row.key}:');
      stdout.writeln(
        '    我方(${row.ours!.kind}, 第 ${row.ours!.line} 行): '
        '${_oneLine(row.ours!.value)}',
      );
      stdout.writeln(
        '    真源(${row.source!.kind}, 第 ${row.source!.line} 行): '
        '${_oneLine(row.source!.value)}',
      );
    }
  }

  stdout.writeln('');
  stdout.writeln(
    '汇总: 一致 $same / 漂移 $drift / 我方扩展 $oursOnly / 真源独有 $sourceOnly'
    ' (共 ${keys.length} 个 token 名)',
  );
  if (drift == 0) {
    stdout.writeln('design token 基线: OK');
    return 0;
  }
  stdout.writeln('design token 基线: FAILED (同名 token 漂移 $drift 处, 见漂移明细)');
  return 1;
}

// ---------------------------------------------------------------------------
// 解析
// ---------------------------------------------------------------------------

final RegExp _classPattern = RegExp(r'^\s*(?:abstract\s+)?(?:final\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)');
final RegExp _staticPattern = RegExp(r'^\s*static\b');
final RegExp _trailingNamePattern = RegExp(r'([A-Za-z_$][A-Za-z0-9_$]*)\s*$');

_TokenFile _parseTokenFile({required String path, required String label}) {
  final File file = File(path);
  if (!file.existsSync()) {
    throw _UsageException('找不到$label文件: $path');
  }
  final List<String> lines = const LineSplitter().convert(file.readAsStringSync());

  final Map<String, _Token> tokens = <String, _Token>{};
  String? currentClass;

  int i = 0;
  while (i < lines.length) {
    final RegExpMatch? classMatch = _classPattern.firstMatch(lines[i]);
    if (classMatch != null) {
      currentClass = classMatch.group(1);
      i++;
      continue;
    }
    if (!_staticPattern.hasMatch(lines[i])) {
      i++;
      continue;
    }

    // ---- 累积一条 static 成员:到「括号配平且引号外遇 `;`」或块体 `}` 收口 ----
    final StringBuffer buffer = StringBuffer();
    final int startLine = i + 1;
    int depth = 0;
    String? quote; // 当前未闭合字符串的引号字符
    bool sawEquals = false; // 已在括号深度 0 处见过 `=`(字段 / `=>` 表达式体)
    bool blockOpened = false; // 在 `=` 之前开过 `{`(方法/函数的块体)
    bool done = false;
    while (i < lines.length && !done) {
      final String code = _stripLineComment(lines[i]).trim();
      for (int c = 0; c < code.length; c++) {
        final String ch = code[c];
        if (quote != null) {
          if (ch == '\\') {
            c++; // 跳过字符串内的转义字符
          } else if (ch == quote) {
            quote = null;
          }
          continue;
        }
        if (ch == "'" || ch == '"') {
          quote = ch;
        } else if (ch == '(' || ch == '[' || ch == '{') {
          depth++;
          if (ch == '{' && depth == 1 && !sawEquals) {
            blockOpened = true; // 参数表之后的块体开始
          }
        } else if (ch == ')' || ch == ']' || ch == '}') {
          if (depth > 0) {
            depth--;
          }
          if (depth == 0 && blockOpened && !sawEquals) {
            done = true; // 块体收口,成员结束(无需 `;`)
            break;
          }
        } else if (ch == '=' && depth == 0) {
          sawEquals = true; // `=` 与 `=>` 都算
        } else if (ch == ';' && depth == 0) {
          buffer.write(code.substring(0, c));
          done = true;
          break;
        }
      }
      if (!done) {
        buffer
          ..write(code)
          ..write(' ');
        i++;
      }
    }
    if (!done) {
      throw _UsageException('$label 第 $startLine 行的 static 成员在文件结束前没有收口');
    }

    // ---- 从语句里取 字段名 / 值 / 修饰(方法与函数在此被排除) ----
    final String statement = buffer.toString().trim();
    final int eq = statement.indexOf('=');
    if (eq > 0) {
      final String head = statement.substring(0, eq);
      // 声明头带 `(` 的是方法/函数(参数表),不是字段。
      if (!head.contains('(')) {
        final RegExpMatch? name = _trailingNamePattern.firstMatch(head);
        if (name != null) {
          final String fieldName = name.group(1)!;
          final String kind = statement.startsWith('static const')
              ? 'const'
              : statement.startsWith('static final')
              ? 'final'
              : 'var';
          final String key = currentClass == null ? fieldName : '$currentClass.$fieldName';
          tokens[key] = _Token(key, kind, statement.substring(eq + 1).trim(), startLine);
        }
      }
    }
    i++; // 越过收口行(`;` 行或块体 `}` 行)
  }

  if (tokens.isEmpty) {
    throw _UsageException('$label未解析到任何 static token: $path(解析器与文件结构不匹配?)');
  }
  return _TokenFile(path, tokens);
}

// ---------------------------------------------------------------------------
// 归一与展示
// ---------------------------------------------------------------------------

final RegExp _constKeyword = RegExp(r'\bconst\b');
final RegExp _whitespaceRun = RegExp(r'\s+');

/// 归一:去 `const` 修饰字 → 去全部空白 → 去紧贴 `]`/`)` 的尾逗号(循环至稳定)。
///
/// 尾逗号在多行格式化里可以出现在**任意层**闭括号前(如 `BoxShadow(\n...color: c,\n)`)。
/// 合法 Dart 里 `,]`/`,)` 只可能是尾逗号,故全局剥离不影响值语义。
String _normalizeValue(String raw) {
  String v = raw.replaceAll(_constKeyword, '');
  v = v.replaceAll(_whitespaceRun, '');
  String prev;
  do {
    prev = v;
    v = v.replaceAll(',]', ']').replaceAll(',)', ')');
  } while (v != prev);
  return v;
}

/// 单行展示文本(换行折成空格)。
String _oneLine(String value) => value.replaceAll(_whitespaceRun, ' ').trim();

/// 表格单元格:超宽截断加省略号;缺侧(token 只在一方存在)显示 `—`。
String _display(String? value) {
  if (value == null) {
    return '—';
  }
  final String oneLine = _oneLine(value);
  if (oneLine.length <= _valueDisplayWidth) {
    return oneLine;
  }
  return '${oneLine.substring(0, _valueDisplayWidth - 1)}…';
}

// ---------------------------------------------------------------------------
// 其他
// ---------------------------------------------------------------------------

String _usageText() =>
    '用法:\n'
    '  dart run tool/check_design_tokens.dart    # 本仓 design_tokens vs zishu 真源对照\n'
    '  dart run tool/check_design_tokens.dart --help';

/// 去掉行内 `//` 注释(引号内的 `//` 不算,如 URL 字符串)。
String _stripLineComment(String line) {
  String? quote;
  for (int c = 0; c < line.length; c++) {
    final String ch = line[c];
    if (quote != null) {
      if (ch == '\\') {
        c++;
      } else if (ch == quote) {
        quote = null;
      }
      continue;
    }
    if (ch == "'" || ch == '"') {
      quote = ch;
      continue;
    }
    if (ch == '/' && c + 1 < line.length && line[c + 1] == '/') {
      return line.substring(0, c);
    }
  }
  return line;
}

/// 仓库根: 优先由脚本自身位置推导(tool/ 的上一级), 退化到当前工作目录。
Directory _resolveRepoRoot() {
  final List<Directory> candidates = <Directory>[];
  try {
    final File script = File.fromUri(Platform.script);
    if (script.existsSync()) {
      candidates.add(script.parent.parent);
    }
  } on Object {
    // Platform.script 在快照/特殊执行方式下可能不可用, 忽略。
  }
  candidates.add(Directory.current);
  for (final Directory candidate in candidates) {
    if (File('${candidate.path}/$_ourTokenRelativePath').existsSync() &&
        Directory('${candidate.path}/tool').existsSync()) {
      return candidate.absolute;
    }
  }
  throw _UsageException(
    '找不到仓库根(需要同时存在 $_ourTokenRelativePath 与 tool/), 请在仓库根执行; '
    '已尝试: ${candidates.map((Directory d) => d.path).join(', ')}',
  );
}
