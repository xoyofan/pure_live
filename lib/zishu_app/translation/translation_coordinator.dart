/// 直播标题中文化翻译协调器(海外平台标题 → 简体中文)。
///
/// 纯 Dart,不依赖 Flutter;HTTP 由注入的 [TranslationFetcher] 完成
/// (生产用 dart:io HttpClient,见 [_httpClientFetcher]),不引入任何新
/// pub 依赖。
///
/// 自 zishu `lib/src/shared/application/translation/translation_coordinator.dart`
/// 逐字移植(GetX 宿主无 riverpod,provider 层收敛为 [_titleTranslationCoordinator]
/// 懒加载单例);差异仅两处:
/// - 裁掉 `translateBody`(依赖 live_parser 的 DanmakuSegment,本仓只做标题);
/// - HTTP fetcher 就近改用 dart:io HttpClient(与 zishu 生产实现同款),
///   并支持环境变量代理与 no_proxy 排除:见 [_resolveTranslationProxy] 与
///   [_httpClientFetcher] 的文档注释(变量、优先级、值格式、失败降级)。
///
/// ### 环境变量代理(标题翻译专用)
///
/// 支持的变量与优先级(同名变量小写优先,与 dart:io
/// `HttpClient.findProxyFromEnvironment` 的约定一致):
///
///     https_proxy / HTTPS_PROXY  >  http_proxy / HTTP_PROXY  >  all_proxy / ALL_PROXY
///
/// - 值格式 `[scheme://][user:password@]host[:port]`(缺省端口 1080,
///   同 curl 与 dart:io;scheme 仅用于识别,http/https/无 scheme 一律按
///   HTTP CONNECT 代理使用;dart:io 代理不支持 SOCKS,`socks*://` 值忽略)。
/// - 变量全缺省或值全部无效 → 不设 findProxy,与改动前完全一致(直连)。
/// - `no_proxy / NO_PROXY`(小写优先,取第一个非空值)→ 排除列表:命中
///   请求 host 则该次直连(不设 findProxy,与无代理一致)。逗号分隔,条目
///   三种形态:精确 host(`example.com` 仅匹配自身)、点前缀域
///   (`.example.com` 匹配自身与任意子域)、单个 `*`(全部直连)。简化
///   口径:端口不敏感,条目里 `:port` 后缀直接剥掉(三个引擎端点全为
///   https 域名,按 host 粒度判断足够);IPv6 字面量去方括号后精确匹配。
/// - 代理连不通 → 走既有失败降级链(连接超时 → 引擎返回 null → 负缓存
///   2 分钟内回原文),不抛出、不阻塞启动与 UI。
///
/// 设计要点(公共翻译实例是志愿者维护的免费服务,必须克制使用):
/// - **缓存去重**:LRU(text → 译文)。标题重复率不高但列表页滚动重建多,
///   缓存避免重复请求;失败记短 TTL 负缓存,避免实例宕机时请求死循环堆积。
/// - **节流队列**:串行小并发 + 最小请求间隔 + 队列上限(溢出丢最旧、
///   回退原文)—— 宁可原文也不无限堆积延迟。
/// - **失败即回退**:任何失败都返回原文,UI 永不因翻译阻塞或报错。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'dart:io';

/// 是否需要把文本翻译为中文(已经是中文/纯符号数字 emoji 的跳过)。
///
/// 规则:
/// - 含日文假名 → 翻(日语标题常夹汉字,不能按汉字占比误判为中文);
/// - 含韩文 → 翻(soop);
/// - 无任何字母 → 不翻(纯数字/标点/emoji);
/// - 其余按「表意文字占字母比例」判定:≥ 0.3 视为中文跳过,否则翻。
///   阈值取得宽松(宁可少翻、不错翻):中文标题/弹幕夹游戏名、品牌词
///   十分常见,句子里有一两个汉字通常就是中文,翻回去反而错。
bool needsChineseTranslation(String raw) {
  var hasKana = false;
  var hasHangul = false;
  var cjk = 0;
  var letters = 0;
  for (final rune in raw.runes) {
    if ((rune >= 0x3040 && rune <= 0x30FF) ||
        (rune >= 0x31F0 && rune <= 0x31FF) ||
        (rune >= 0xFF66 && rune <= 0xFF9D)) {
      hasKana = true;
      letters++;
    } else if ((rune >= 0xAC00 && rune <= 0xD7AF) ||
        (rune >= 0x1100 && rune <= 0x11FF) ||
        (rune >= 0x3130 && rune <= 0x318F)) {
      hasHangul = true;
      letters++;
    } else if ((rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF) ||
        (rune >= 0xF900 && rune <= 0xFAFF)) {
      cjk++;
      letters++;
    } else if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune >= 0xC0 && rune <= 0x24F) ||
        (rune >= 0x0400 && rune <= 0x04FF)) {
      letters++;
    }
  }
  if (hasKana || hasHangul) return true;
  if (letters == 0) return false;
  return cjk / letters < 0.3;
}

/// 翻译引擎:把一段文本译为简体中文;失败返回 null(内部吞掉异常,不抛出)。
abstract interface class TranslationEngine {
  Future<String?> translate(String text);
}

/// 可选批量能力:一次请求翻译多条文本(批量几个一起请求再拆分对应,
/// 显著降低请求数)。返回与 [texts] 等长的结果列表,元素 null = 该条
/// 失败;返回 null 本身 = 引擎不支持/本批失败,调用方回退逐条。
abstract interface class TranslationBatchEngine implements TranslationEngine {
  Future<List<String?>?> translateBatch(List<String> texts);
}

/// 单次批量请求的最大条数(多行合并一次 gtx 请求)。
const int kTranslationBatchSize = 12;

/// 引擎取数函数:GET [uri] 并解析 JSON 响应体(注入便于单测)。
typedef TranslationFetcher = Future<Object?> Function(Uri uri);

/// 引擎单请求正文上限:CJK 文本经公共实例约 1250 字符就到编码上限,
/// 标题远用不满;超长直接放弃(回原文)。
const int kTranslationMaxChars = 1200;

/// 实例基地址归一:去尾斜杠,拼路径时统一单斜杠。
String _normalizeBase(String base) {
  var trimmed = base.trim();
  while (trimmed.endsWith('/')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

/// 宽容取字段:引擎只关心顶层字符串值,响应 Map 的具体类型不敏感。
String? _stringField(Object? data, String key) {
  if (data is! Map) return null;
  final value = data[key];
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

/// Google 浏览器字典公开端点(client=dict-chrome-ex):无需 key,经上游代理
/// 可达。
///
/// 端点演变(zishu 2026-09-22 实测):原 `translate_a/single?client=gtx` 已被
/// Google 判定为自动查询,直连与经代理**一律返回 HTTP 429 拦截页**;同期
/// 志愿者实例(lingva 被 Cloudflare 盾 403、lunar.icu 500、simplytranslate
/// 400/jae.fi 不可达)集体失效 —— 中文化链路因此全部回退原文。同一主机换用
/// Chrome 扩展端点的 `client=dict-chrome-ex` 恢复 200(直连/代理均可),故作为
/// 首选引擎;志愿者实例降级为后备。
///
/// 响应形如 `[["译文","检测语言"], ...]`,按查询顺序一一对应;一次查询
/// (即使多句)只产生一项。
class GoogleWebEngine implements TranslationEngine, TranslationBatchEngine {
  GoogleWebEngine({required this.fetcher});

  final TranslationFetcher fetcher;

  static const _base = 'https://translate.googleapis.com';

  /// 查询 URL:重复 `q` 参数即批量(响应按序对应)。
  Uri _queryUri(Iterable<String> texts) {
    final query = [
      'client=dict-chrome-ex',
      'sl=auto',
      'tl=zh-CN',
      for (final text in texts) 'q=${Uri.encodeComponent(text)}',
    ].join('&');
    return Uri.parse('$_base/translate_a/t?$query');
  }

  /// 解析 `[[译文, 检测语言], ...]`。
  ///
  /// 形态不符或条数与查询不齐一律返回 null(调用方回退);译文为空白视为
  /// 该条失败(null),与批量里的「空行」语义一致。
  List<String?>? _parsePairs(Object? data, int expected) {
    if (data is! List || data.length != expected) return null;
    final out = <String?>[];
    for (final item in data) {
      if (item is! List || item.isEmpty || item.first is! String) return null;
      final translated = (item.first as String).trim();
      out.add(translated.isEmpty ? null : translated);
    }
    return out;
  }

  @override
  Future<String?> translate(String text) async {
    if (text.length > kTranslationMaxChars) return null;
    final parsed = _parsePairs(await fetcher(_queryUri([text])), 1);
    return parsed?.first;
  }

  /// 批量:重复 `q` 参数一次请求。
  ///
  /// 不能用「多行合并 + 按行拆分」:该端点会把换行吞掉合成一段(实测
  /// `hello\nworld` → `["你好世界"]`),条数对不上。合并体超长同样返回
  /// null,由协调器回退逐条(串行小并发,不会放大整体延迟)。
  @override
  Future<List<String?>?> translateBatch(List<String> texts) async {
    if (texts.isEmpty) return const [];
    if (texts.any((t) => t.length > kTranslationMaxChars)) return null;
    if (texts.fold<int>(0, (sum, t) => sum + t.length) > kTranslationMaxChars) {
      return null;
    }
    return _parsePairs(await fetcher(_queryUri(texts)), texts.length);
  }
}

/// Lingva 引擎:`GET {base}/api/v1/auto/zh/{text}` → `{"translation": ...}`。
class LingvaEngine implements TranslationEngine {
  LingvaEngine({required this.bases, required this.fetcher});

  /// 实例基地址(按序 failover)。
  final List<String> bases;
  final TranslationFetcher fetcher;

  @override
  Future<String?> translate(String text) async {
    if (text.length > kTranslationMaxChars || bases.isEmpty) return null;
    for (final rawBase in bases) {
      final base = _normalizeBase(rawBase);
      if (base.isEmpty) continue;
      try {
        final uri = Uri.parse('$base/api/v1/auto/zh/${Uri.encodeComponent(text)}');
        final value = _stringField(await fetcher(uri), 'translation');
        if (value != null) return value;
      } catch (_) {
        // 实例失败试下一个;全部失败返回 null(上层回退原文/下一引擎)。
      }
    }
    return null;
  }
}

/// SimplyTranslate 引擎:
/// `GET {base}/api?engine=google&lang=auto&tl=zh-CN&text=...`
/// → `{"translated-text": ...}`。
class SimplyTranslateEngine implements TranslationEngine {
  SimplyTranslateEngine({required this.bases, required this.fetcher});

  final List<String> bases;
  final TranslationFetcher fetcher;

  @override
  Future<String?> translate(String text) async {
    if (text.length > kTranslationMaxChars || bases.isEmpty) return null;
    for (final rawBase in bases) {
      final base = _normalizeBase(rawBase);
      if (base.isEmpty) continue;
      try {
        final root = Uri.parse(base);
        final apiPath = '${root.path}/api'.replaceFirst(RegExp(r'^//'), '/');
        final uri = root.replace(
          path: apiPath,
          queryParameters: {'engine': 'google', 'lang': 'auto', 'tl': 'zh-CN', 'text': text},
        );
        final value = _stringField(await fetcher(uri), 'translated-text');
        if (value != null) return value;
      } catch (_) {
        // 同 Lingva:逐实例 failover。
      }
    }
    return null;
  }
}

/// 队列中的待翻译任务。
class _PendingTranslation {
  _PendingTranslation({required this.key, required this.display, required this.completer});

  /// 缓存/请求键(trim 后文本)。
  final String key;

  /// 失败回退展示文本(未 trim 原文)。
  final String display;
  final Completer<String> completer;
}

/// 翻译协调器:缓存 + 节流队列 + 引擎 failover 的应用级单例。
///
/// 生命周期由 [_titleTranslationCoordinator] 懒加载单例管理([dispose] 供
/// 宿主按需调用,本仓标题场景随进程存活,不主动销毁)。
class TranslationCoordinator {
  TranslationCoordinator({
    required this.engines,
    this.maxConcurrent = 2,
    this.minInterval = const Duration(milliseconds: 300),
    this.requestTimeout = const Duration(seconds: 6),
    // 批量翻译(12 条/请求)后吞吐提升,队列上限同步放大:洪峰少丢一轮
    // (超过仍丢最旧回原文,保延迟)。
    this.maxQueue = 256,
    this.cacheCapacity = 1024,
    this.failureTtl = const Duration(minutes: 2),
  });

  /// 引擎按序 failover;公开为只读字段便于测试断言注入。
  final List<TranslationEngine> engines;
  final int maxConcurrent;
  final Duration minInterval;
  final Duration requestTimeout;
  final int maxQueue;
  final int cacheCapacity;
  final Duration failureTtl;

  /// LRU 译文缓存(LinkedHashMap:尾=最近使用,头=最旧可淘汰)。
  final LinkedHashMap<String, String> _cache = LinkedHashMap();

  /// 失败负缓存:text → 可重试时刻。
  final Map<String, DateTime> _failures = {};

  /// 在途去重:同一文本并发请求合并为一个 Future。
  final Map<String, Future<String>> _inflight = {};

  final List<_PendingTranslation> _queue = [];
  int _active = 0;
  DateTime _nextSlot = DateTime.now();

  /// 节流槽排程 Timer(一次性):到点续跑 [_pump];dispose 时取消,
  /// 避免残留 pending Timer。
  Timer? _slotTimer;
  bool _disposed = false;

  /// 翻译一段文本;失败/无需翻译时原样返回,Future 永不抛错。
  Future<String> translate(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !needsChineseTranslation(trimmed)) {
      return Future.value(text);
    }
    final cached = _lookup(trimmed);
    if (cached != null) return Future.value(cached);
    final inflight = _inflight[trimmed];
    if (inflight != null) return inflight;
    if (_disposed) return Future.value(text);

    // 队列满:丢最旧(高峰期宁可早到的回原文,不放大整体延迟)。
    while (_queue.length >= maxQueue) {
      _queue.removeAt(0).completer.complete(text);
    }
    final completer = Completer<String>();
    final future = completer.future;
    _inflight[trimmed] = future;
    unawaited(future.whenComplete(() => _inflight.remove(trimmed)));
    _queue.add(_PendingTranslation(key: trimmed, display: text, completer: completer));
    // 聚合同一事件循环内的入队(批量翻译):零延迟 Timer 让同批标题攒成
    // 一个批量请求;已有排程时不重复。
    _schedulePump();
    return future;
  }

  /// 单例销毁:未出队任务全部回退原文,防泄漏。
  void dispose() {
    _disposed = true;
    _slotTimer?.cancel();
    _slotTimer = null;
    for (final job in _queue) {
      if (!job.completer.isCompleted) job.completer.complete(job.display);
    }
    _queue.clear();
    _inflight.clear();
  }

  /// 命中返回译文;负缓存期内返回原文(调用方直接回退,不入队);
  /// 都没有返回 null。
  String? _lookup(String key) {
    final retryAt = _failures[key];
    if (retryAt != null) {
      if (DateTime.now().isBefore(retryAt)) return key;
      _failures.remove(key);
    }
    final hit = _cache[key];
    if (hit != null) {
      // LRU touch:重插到尾部。
      _cache.remove(key);
      _cache[key] = hit;
    }
    return hit;
  }

  /// 聚合排程:零延迟 Timer 聚合同批入队后一次批量派发;已有排程不重复。
  /// dispose 时随 _slotTimer 一并取消,无残留。
  void _schedulePump() {
    if (_slotTimer != null || _disposed) return;
    _slotTimer = Timer(Duration.zero, () {
      _slotTimer = null;
      _pump();
    });
  }

  /// 派发循环:能立即派发的当场发;未到节流槽则排一次性 Timer 到点续跑。
  ///
  /// 不用「循环内 await delay」——那种长挂 await 会留下 pending Timer;
  /// 一次性 Timer 随 [dispose] 取消,无残留。
  void _pump() {
    if (_disposed || _slotTimer != null) return;
    while (!_disposed && _queue.isNotEmpty && _active < maxConcurrent) {
      final now = DateTime.now();
      final wait = _nextSlot.difference(now);
      if (wait <= Duration.zero) {
        // 批量派发:一次请求翻译多条再拆分对应,显著降低请求数。
        // 一个批占用一个节流槽/一个并发名额。
        final batch = <_PendingTranslation>[];
        while (_queue.isNotEmpty && batch.length < kTranslationBatchSize) {
          batch.add(_queue.removeAt(0));
        }
        _active++;
        _nextSlot = now.add(minInterval);
        unawaited(_runBatch(batch));
        continue;
      }
      _slotTimer = Timer(wait, () {
        _slotTimer = null;
        _pump();
      });
      return;
    }
  }

  Future<void> _run(_PendingTranslation job) async {
    var result = job.display;
    try {
      final translated = await _translateViaEngines(job.key).timeout(requestTimeout);
      if (translated != null) {
        result = translated;
        _cachePut(job.key, translated);
      } else {
        _failures[job.key] = DateTime.now().add(failureTtl);
      }
    } catch (_) {
      _failures[job.key] = DateTime.now().add(failureTtl);
    } finally {
      _active--;
      if (!job.completer.isCompleted) job.completer.complete(result);
      _pump();
    }
  }

  /// 批量执行:优先走引擎批量能力(GoogleWeb 多行合并一次请求);
  /// 引擎不支持/整批失败 → 逐条回退([_run]);个别条目失败记负缓存。
  /// 每条独立缓存,completer 逐条完成。
  Future<void> _runBatch(List<_PendingTranslation> batch) async {
    if (batch.length == 1) {
      _active--;
      await _run(batch.single);
      _pump();
      return;
    }
    final results = List<String?>.filled(batch.length, null);
    try {
      for (final engine in engines) {
        if (engine is! TranslationBatchEngine) continue;
        final out = await engine.translateBatch(batch.map((job) => job.key).toList()).timeout(requestTimeout);
        if (out != null && out.length == batch.length) {
          for (var i = 0; i < out.length; i++) {
            results[i] = out[i];
          }
          break;
        }
      }
    } catch (_) {
      // 批量失败:保持 null,下方逐条回退。
    }
    for (var i = 0; i < batch.length; i++) {
      final job = batch[i];
      final translated = results[i];
      var result = job.display;
      if (translated != null && translated.trim().isNotEmpty) {
        result = translated;
        _cachePut(job.key, translated);
      } else {
        // 该条批量失败:逐条重试一次(与旧行为等价),仍失败记负缓存。
        try {
          final single = await _translateViaEngines(job.key).timeout(requestTimeout);
          if (single != null) {
            result = single;
            _cachePut(job.key, single);
          } else {
            _failures[job.key] = DateTime.now().add(failureTtl);
          }
        } catch (_) {
          _failures[job.key] = DateTime.now().add(failureTtl);
        }
      }
      if (!job.completer.isCompleted) job.completer.complete(result);
    }
    _active--;
    _pump();
  }

  Future<String?> _translateViaEngines(String text) async {
    for (final engine in engines) {
      final out = await engine.translate(text);
      if (out != null && out.trim().isNotEmpty) return out;
    }
    return null;
  }

  void _cachePut(String key, String value) {
    _cache.remove(key);
    _cache[key] = value;
    while (_cache.length > cacheCapacity) {
      _cache.remove(_cache.keys.first);
    }
  }
}

/// 内置公共实例(zishu 同款,志愿者维护,可能失效):
/// - Lingva:Garuda Linux 与 lunar.icu 社区实例(底层 Google 引擎);
/// - SimplyTranslate:官方实例。
const List<String> kDefaultLingvaBases = ['https://lingva.garudalinux.org', 'https://lingva.lunar.icu'];
const List<String> kDefaultSimplyTranslateBases = ['https://simplytranslate.org', 'https://translate.jae.fi'];

/// 解析后的翻译代理配置(null = 无代理,直连)。
class _TranslationProxy {
  const _TranslationProxy({required this.host, required this.port, required this.findProxy, this.user, this.password});

  /// 代理主机(IPv6 不含方括号)/端口(注册代理认证凭据用)。
  final String host;
  final int port;

  /// [HttpClient.findProxy] 的返回值(`PROXY host:port`,IPv6 补方括号)。
  final String findProxy;

  /// 代理 URI 里的 `user:password@`(可选;password 为空串表示只有用户名)。
  final String? user;
  final String? password;
}

/// 环境变量 → 标题翻译代理配置;变量与优先级见文件头注释。
///
/// 同语义变量小写优先;变量缺省或值解析失败顺延取下一个变量,全部无效
/// 返回 null(直连,行为与无代理完全一致)——单个坏值不至于让代理失效。
/// [environment] 便于单测注入,缺省读进程环境。
_TranslationProxy? _resolveTranslationProxy({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  const names = <String>[
    'https_proxy', 'HTTPS_PROXY', // 优先:三个端点全为 https
    'http_proxy', 'HTTP_PROXY', // 国内常见只设 HTTP_PROXY 的场景
    'all_proxy', 'ALL_PROXY', // 兜底
  ];
  for (final name in names) {
    final raw = env[name]?.trim();
    if (raw == null || raw.isEmpty) continue;
    final proxy = _parseProxyValue(raw);
    if (proxy != null) return proxy;
  }
  return null;
}

/// 单个代理变量值 → [_TranslationProxy];值不可解析返回 null。
_TranslationProxy? _parseProxyValue(String value) {
  // 代理地址不含空白;Dart 的 Uri 解析会把空格静默编码进 host('x y z' →
  // 'x%20y%20z'),不拦会产出必然连不通的伪代理,按坏值跳过更干净。
  if (RegExp(r'\s').hasMatch(value)) return null;
  // 裸 `host[:port]` 按 http scheme 解析,与带 scheme 的值走同一路径。
  final uri = Uri.tryParse(value.contains('://') ? value : 'http://$value');
  if (uri == null || uri.host.isEmpty) return null;
  if (uri.scheme.startsWith('socks')) return null; // dart:io PAC 无 SOCKS 形式
  final host = uri.host;
  final port = uri.hasPort ? uri.port : 1080;
  // IPv6 在 PAC 串里必须带方括号,否则 PROXY 串按最后一个冒号切分会错位。
  final hostToken = host.contains(':') ? '[$host]' : host;
  String? user;
  String? password;
  if (uri.userInfo.isNotEmpty) {
    final pair = uri.userInfo.split(':');
    user = _tryDecodePercent(pair.first);
    if (pair.length > 1) password = _tryDecodePercent(pair.sublist(1).join(':'));
  }
  if (user != null) password ??= ''; // 只有用户名:密码记空串,取用方不再判空
  return _TranslationProxy(host: host, port: port, findProxy: 'PROXY $hostToken:$port', user: user, password: password);
}

/// 百分号解码;`%zz` 这类非法序列原样返回(环境变量是用户手写的,
/// 宁可凭据原样也绝不让坏值在代理配置初始化时抛异常)。
String _tryDecodePercent(String raw) {
  try {
    return Uri.decodeComponent(raw);
  } catch (_) {
    return raw;
  }
}

/// no_proxy / NO_PROXY → 排除条目列表(条目已归一,语义见文件头注释)。
///
/// 同名变量小写优先,取第一个非空值(与代理变量的顺延约定一致);两个
/// 变量都缺省或为空返回空列表(无排除,不改变既有直连/代理行为)。
/// [environment] 便于单测注入,缺省读进程环境。
List<String> _resolveNoProxyEntries({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  for (final name in const <String>['no_proxy', 'NO_PROXY']) {
    final raw = env[name]?.trim();
    if (raw == null || raw.isEmpty) continue;
    final entries = <String>[];
    for (final part in raw.split(',')) {
      final entry = _normalizeNoProxyEntry(part);
      if (entry.isNotEmpty) entries.add(entry);
    }
    return entries;
  }
  return const <String>[];
}

/// 单个 no_proxy 条目归一:小写、剥 `:port` 后缀、IPv6 去方括号;空串
/// 表示空条目(调用方丢弃)。
///
/// 简化口径(见文件头注释):条目只按 host 匹配,`example.com:8443` 与
/// `example.com` 等价 —— 三个引擎端点全为 https 域名,端口粒度没有实际
/// 意义;带端口的 IPv6(`[::1]:8443`)取方括号内字面量。
String _normalizeNoProxyEntry(String raw) {
  var entry = raw.trim().toLowerCase();
  if (entry.isEmpty || entry == '*') return entry;
  if (entry.startsWith('[')) {
    // `[::1]` / `[::1]:8443` → `::1`;缺右括号的坏值原样保留,永不匹配。
    final closeBracket = entry.indexOf(']');
    if (closeBracket != -1) entry = entry.substring(1, closeBracket);
  } else {
    // 裸条目:单个 `:` 视为 host:port 分隔剥掉;多个 `:` 视为未加方括号
    // 的 IPv6 字面量整体保留(IPv6 至少两个冒号,不会误伤 host:port)。
    final colon = entry.indexOf(':');
    if (colon != -1 && colon == entry.lastIndexOf(':')) {
      entry = entry.substring(0, colon);
    }
  }
  return entry;
}

/// 请求 host 是否被 no_proxy 排除(命中 → 该次请求直连,不设 findProxy)。
///
/// [host] 取自 [Uri.host](IPv6 已去方括号),条目已按
/// [_normalizeNoProxyEntry] 归一,两边统一小写后比较:`*` 命中一切;
/// 点前缀域命中自身与任意子域;其余精确相等。
bool _isNoProxyExcluded(String host, List<String> entries) {
  if (host.isEmpty || entries.isEmpty) return false;
  final target = host.toLowerCase();
  for (final entry in entries) {
    if (entry == '*') return true;
    if (entry.startsWith('.')) {
      if (target == entry.substring(1) || target.endsWith(entry)) return true;
    } else if (target == entry) {
      return true;
    }
  }
  return false;
}

/// 进程内解析一次:top-level final 首次被 [_httpClientFetcher] 读取时
/// 才读环境变量(懒初始化),之后缓存,不再反复查表。
final _TranslationProxy? _translationProxy = _resolveTranslationProxy();

/// no_proxy 排除条目,与代理配置同步懒解析一次(条目形态见
/// [_resolveNoProxyEntries]);短路求值下无代理时不会被读取,零额外开销。
final List<String> _noProxyEntries = _resolveNoProxyEntries();

/// 翻译专用 fetcher:每次请求独立 HttpClient(低频调用,简单可靠)。
///
/// 自 zishu `translation_provider.dart` 的 `_dioFetcher` 就近移植——其实现
/// 本就是 dart:io HttpClient(注释里的 dio 与实现不符,以实现为准)。
/// 在此之上支持环境变量代理(变量与优先级见文件头注释):仅当解析出
/// 代理且请求 host 未被 no_proxy 命中时才设 [HttpClient.findProxy]/认证
/// 回调;代理连不通与直连不通一样,走既有失败链(超时 → 引擎 null →
/// 负缓存 2 分钟内回原文),不影响启动与 UI。
Future<Object?> _httpClientFetcher(Uri uri) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
  final proxy = _translationProxy;
  // no_proxy 命中:该次请求直连,不设 findProxy,与无代理完全一致。
  if (proxy != null && !_isNoProxyExcluded(uri.host, _noProxyEntries)) {
    client.findProxy = (_) => proxy.findProxy;
    final user = proxy.user;
    if (user != null) {
      // 代理返回 407 时按 env URI 里的 user:password@ 重试一次
      // (dart:io 文档的标准配方:authenticateProxy 返回 true 前注册凭据;
      // realm 用质询原值,保证重试能匹配上)。
      final password = proxy.password ?? '';
      client.authenticateProxy = (host, port, scheme, realm) {
        client.addProxyCredentials(host, port, realm ?? scheme, HttpClientBasicCredentials(user, password));
        return Future.value(true);
      };
    }
  }
  try {
    final request = await client.getUrl(uri);
    final response = await request.close().timeout(const Duration(seconds: 6));
    if (response.statusCode != 200) return null;
    final body = await response.transform(utf8.decoder).join();
    return jsonDecode(body) as Object?;
  } finally {
    client.close(force: true);
  }
}

/// 引擎组(zishu 同款次序,无自定义实例地址设置项):Google 网页端点首选,
/// Lingva 次之(响应快)、SimplyTranslate 兜底。
List<TranslationEngine> buildTranslationEngines() {
  return [
    GoogleWebEngine(fetcher: _httpClientFetcher),
    LingvaEngine(bases: kDefaultLingvaBases, fetcher: _httpClientFetcher),
    SimplyTranslateEngine(bases: kDefaultSimplyTranslateBases, fetcher: _httpClientFetcher),
  ];
}

TranslationCoordinator? _coordinatorSingleton;

/// 标题翻译协调器懒加载单例(zishu 的 riverpod `translationCoordinatorProvider`
/// 在本仓无 riverpod,收敛为惰性 getter;缓存随进程存活)。
TranslationCoordinator get titleTranslationCoordinator =>
    _coordinatorSingleton ??= TranslationCoordinator(engines: buildTranslationEngines());

/// 侧栏聊天流「按文本翻译」公开入口(对齐 zishu chat_tab.dart:337-377
/// `_translateForDisplay` 的显示出口:所有放行路径先过翻译,译文就绪才
/// 放行;本仓聊天正文保持纯文本,不需要 zishu 的富文本段翻译)。
///
/// - 文本无需翻译/已命中缓存时同步返回 [text],零网络开销;
/// - 否则入协调器批量队列(缓存/在途去重/节流),超 [waitLimit] 未就绪以
///   原文放行 —— 协调器自身请求超时 6s 且按 300ms 节流,放行口径再卡
///   2.5s 上限(与 zishu `_kTranslateWaitLimit` 同值):宁可原文,不拖住
///   整条聊天流;
/// - Future 永不抛错([TranslationCoordinator.translate] 失败原样返回,
///   timeout 命中 onTimeout)。
Future<String> translateChatText(String text, {Duration waitLimit = const Duration(milliseconds: 2500)}) {
  return titleTranslationCoordinator.translate(text).timeout(waitLimit, onTimeout: () => text);
}
