import 'dart:convert';
import 'dart:typed_data';

import 'package:fixnum/fixnum.dart' as $fix;
import 'package:flutter_test/flutter_test.dart';
import 'package:pure_live/core/models/live_message.dart';
import 'package:pure_live/shared/platforms/acfun/acfun_danmaku.dart';
import 'package:pure_live/shared/platforms/acfun/proto/acfun.pb.dart' as pb;

void main() {
  group('AcFunDanmaku 封帧与加密', () {
    test('buildPacket/parsePacket 往返', () {
      final header = pb.PacketHeader()
        ..appId = 13
        ..uid = $fix.Int64(123456)
        ..seqId = $fix.Int64(7)
        ..kpn = 'ACFUN_APP';
      final encrypted = Uint8List.fromList(List.generate(48, (i) => i % 256));
      final packet = AcFunDanmaku.buildPacket(header, encrypted, plainLen: 32);
      final parsed = AcFunDanmaku.parsePacket(packet);
      expect(parsed, isNotNull);
      expect(parsed!.header.appId, 13);
      expect(parsed.header.uid.toInt(), 123456);
      expect(parsed.header.seqId.toInt(), 7);
      expect(parsed.header.decodedPayloadLen, 32);
      expect(parsed.body, encrypted);
    });

    test('parsePacket 拒绝坏魔数与截断帧', () {
      final header = pb.PacketHeader()..appId = 13;
      final packet = AcFunDanmaku.buildPacket(header, Uint8List(16), plainLen: 16);
      expect(AcFunDanmaku.parsePacket(Uint8List.fromList([1, 2, 3])), isNull);
      final truncated = Uint8List.sublistView(packet, 0, packet.length - 8);
      expect(AcFunDanmaku.parsePacket(truncated), isNull);
    });

    test('AES-CBC(+IV) 加解密往返', () {
      final key = Uint8List.fromList(List.generate(16, (i) => i + 1));
      final plain = Uint8List.fromList(utf8.encode('acfun-danmaku-packet-body'));
      final encrypted = AcFunDanmaku.aesCbcPkcs7(plain, key, forEncryption: true);
      expect(encrypted.length, greaterThan(plain.length));
      final decrypted = AcFunDanmaku.aesCbcPkcs7(encrypted, key, forEncryption: false);
      expect(decrypted, plain);
    });
  });

  group('AcFunDanmaku.parseActionSignal(评论信号)', () {
    test('评论条目解析为聊天消息, 其他信号忽略', () {
      final signal = pb.ZtLiveScActionSignal()
        ..item.add(
          pb.ZtLiveScActionSignal_ZtLiveActionSignalItem()
            ..signalType = 'CommonActionSignalComment'
            ..payload.add(
              (pb.CommonActionSignalComment()
                    ..content = '主播牛逼'
                    ..userInfo = (pb.ZtLiveUserInfo()..nickname = '测试观众'))
                  .writeToBuffer(),
            ),
        )
        ..item.add(
          pb.ZtLiveScActionSignal_ZtLiveActionSignalItem()
            ..signalType = 'CommonActionSignalLike'
            ..payload.add((pb.CommonActionSignalLike()..sendTimeMs = $fix.Int64(1)).writeToBuffer()),
        );
      final messages = AcFunDanmaku.parseActionSignal(signal.writeToBuffer());
      expect(messages, hasLength(1));
      expect(messages.single.type, LiveMessageType.chat);
      expect(messages.single.userName, '测试观众');
      expect(messages.single.message, '主播牛逼');
    });

    test('空评论内容跳过', () {
      final signal = pb.ZtLiveScActionSignal()
        ..item.add(
          pb.ZtLiveScActionSignal_ZtLiveActionSignalItem()
            ..signalType = 'CommonActionSignalComment'
            ..payload.add((pb.CommonActionSignalComment()..content = '   ').writeToBuffer()),
        );
      expect(AcFunDanmaku.parseActionSignal(signal.writeToBuffer()), isEmpty);
    });
  });
}
