import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:pure_live/common/index.dart';
import 'package:pure_live/core/common/core_log.dart';
import 'package:pure_live/core/site/soop/soop_site.dart';
import 'package:pure_live/core/common/utils/list_util.dart';
import 'package:pure_live/core/common/web_socket_util.dart';
import 'package:pure_live/core/interface/live_danmaku.dart';
import 'package:pure_live/core/utils/yy/yy_web_socket_channel.dart';

class SoopDanmakuArgs {
  String url;
  String chatNo;

  SoopDanmakuArgs({required this.url, required this.chatNo});

  SoopDanmakuArgs.fromJson(Map<String, dynamic> json) : url = json['url'] ?? '', chatNo = json['chatNo'] ?? '';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'url': url, 'chatNo': chatNo};
  }
}

class SoopDanmaku implements LiveDanmaku {
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  void markConnected() {
    _connected = true;
  }

  @override
  void markDisconnected() {
    _connected = false;
  }

  @override
  int heartbeatTime = 20 * 1000;

  @override
  Function(LiveMessage msg)? onMessage;
  @override
  Function(String msg)? onReconnect;
  @override
  Function(String msg)? onClose;
  @override
  Function()? onReady;

  final String f = "\x0c";
  final String esc = "\x1b\x09";

  WebScoketUtils? webScoketUtils;
  late SoopDanmakuArgs danmakuArgs;

  @override
  Future<void> start(dynamic args) async {
    CoreLog.d("SoopDanmaku start");
    if (args == null) {
      onClose?.call("服务器连接失败");
      return;
    }
    danmakuArgs = args as SoopDanmakuArgs;
    final site = Sites.of(Sites.soopSite);
    final liveSite = site.liveSite as SoopSite;
    final mHeaders = liveSite.getHeaders();
    mHeaders.addAll({
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36",
      "Origin": "https://play.sooplive.co.kr",
    });

    CoreLog.d("SoopDanmaku args: ${json.encode(danmakuArgs.toJson())}");
    webScoketUtils = WebScoketUtils(
      url: danmakuArgs.url,
      heartBeatTime: heartbeatTime,
      protocols: const ['chat'],
      headers: mHeaders,
      connector: connectCaseSensitiveWebSocket,
      onMessage: (e) {
        try {
          if (e is String) {
            decodeMessageStr(e);
          } else if (e is Uint8List || e is List<int>) {
            decodeMessage(List<int>.from(e));
          }
        } catch (err) {
          CoreLog.w("SoopDanmaku decode error raw: $e");
          CoreLog.error(err);
        }
      },
      onReady: () {
        markConnected();
        onReady?.call();
        joinRoom(danmakuArgs);
      },
      onHeartBeat: () {
        heartbeat();
      },
      onReconnect: () {
        markDisconnected();
        onReconnect?.call("与服务器断开连接，正在尝试重连");
      },
      onClose: (e) {
        markDisconnected();
        onClose?.call("服务器连接失败 $e");
      },
    );
    webScoketUtils?.connect();
  }

  Future<void> joinRoom(SoopDanmakuArgs joinData) async {
    danmakuArgs = joinData;
    final connectPacket = '${esc}000100000600${f * 3}16$f';
    webScoketUtils?.sendMessage(connectPacket);

    await Future.delayed(const Duration(milliseconds: 200));
    final joinPacket =
        '${esc}0002${_calculateByteSize(danmakuArgs.chatNo).toString().padLeft(6, '0')}00$f${danmakuArgs.chatNo}${f * 5}';
    webScoketUtils?.sendMessage(joinPacket);
  }

  int _calculateByteSize(String string) {
    return utf8.encode(string).length + 6;
  }

  @override
  void heartbeat() {
    final pingPacket = '${esc}000000000100$f';
    webScoketUtils?.sendMessage(pingPacket);
  }

  @override
  Future<void> stop() async {
    markDisconnected();
    onMessage = null;
    onReconnect = null;
    onClose = null;
    onReady = null;
    webScoketUtils?.close();
    webScoketUtils = null;
  }

  void decodeMessageStr(String data) {
    CoreLog.w("SoopDanmaku decodeMessageStr: $data");
  }

  void decodeMessage(List<int> data) {
    const headerLength = 14;
    var offset = 0;
    while (offset + headerLength <= data.length) {
      if (data[offset] != 0x1b || data[offset + 1] != 0x09) {
        CoreLog.w('SOOP chat packet has an invalid prefix at offset $offset');
        return;
      }
      final service = int.tryParse(ascii.decode(data.sublist(offset + 2, offset + 6), allowInvalid: true));
      final bodyLength = int.tryParse(ascii.decode(data.sublist(offset + 6, offset + 12), allowInvalid: true));
      if (service == null || bodyLength == null || bodyLength < 0) {
        CoreLog.w('SOOP chat packet has an invalid header at offset $offset');
        return;
      }
      final packetEnd = offset + headerLength + bodyLength;
      if (packetEnd > data.length) {
        CoreLog.w('SOOP chat packet is truncated at offset $offset');
        return;
      }
      if (service == 5) {
        _decodeChatPacket(data.sublist(offset + headerLength, packetEnd));
      }
      offset = packetEnd;
    }
    if (offset != data.length) {
      CoreLog.w('SOOP chat payload ended with ${data.length - offset} trailing bytes');
    }
  }

  void _decodeChatPacket(List<int> body) {
    const separatorByte = 0x0c;
    final parts = ListUtil.splitList(body, separatorByte);
    final fields = parts.map((part) => utf8.decode(part, allowMalformed: true)).toList(growable: false);
    CoreLog.d("SOOP chat fields: $fields");

    if (fields.length <= 6) return;
    final comment = fields[1].trim();
    final userName = fields[6].trim();
    if (comment.isEmpty || userName.isEmpty || ['-1', '1'].contains(comment) || comment.contains('|')) return;
    // 徽章(对齐真源 live_parser soop/danmaku.dart _soopBadges):flag1
    // (fields[7],'|' 取首段)位域 + 订阅月数(fields[8]);订阅(位 268435456)
    // 或 months>0 时牌名为月数,管理员 256/铁粉 32768/粉丝团 32 为单字母牌。
    // 协议单色 → start/end/border 同值;无用户等级字段 → userLevel 留默认空串。
    String? badgeName;
    String? badgeLevel;
    String? badgeColor;
    if (fields.length > 7) {
      final flag = int.tryParse(fields[7].split('|').first.trim()) ?? 0;
      final months = fields.length > 8 ? (int.tryParse(fields[8].trim()) ?? 0) : 0;
      const int subscriber = 268435456, manager = 256, topfan = 32768, fanclub = 32;
      if ((flag & subscriber) != 0 || months > 0) {
        final lv = months > 0 ? months : 1;
        badgeName = '$lv';
        badgeLevel = '$lv';
        badgeColor = '#EF565F';
      } else if ((flag & manager) != 0) {
        badgeName = 'M';
        badgeLevel = '1';
        badgeColor = '#53B1AE';
      } else if ((flag & topfan) != 0) {
        badgeName = 'T';
        badgeLevel = '1';
        badgeColor = '#D65B8F';
      } else if ((flag & fanclub) != 0) {
        badgeName = 'F';
        badgeLevel = '1';
        badgeColor = '#75AA5C';
      }
    }
    onMessage?.call(
      LiveMessage(
        type: LiveMessageType.chat,
        color: LiveMessageColor.white,
        message: comment,
        userName: userName,
        badgeName: badgeName,
        badgeLevel: badgeLevel,
        badgeColorStart: badgeColor,
        badgeColorEnd: badgeColor,
        badgeColorBorder: badgeColor,
      ),
    );
  }
}
