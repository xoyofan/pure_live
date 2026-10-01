/// 虎牙贵宾/超粉 wup 查询(Tars TUP v3 二进制协议),供播放侧栏统计行消费。
///
/// 口径对齐 zishu 真源 `packages/live_parser/.../huya/huya_wup.dart`(web 侧
/// `huya-wup.ts` 的等价移植;字段编号/请求体结构逐条照抄):
/// - POST `https://cdnws.api.huya.com/?baseinfo=default`,body = 4 字节大端包长
///   (含自身)+ RequestPacket;贵宾走 servant `liveui`/`getVipBarList`,
///   超粉走 `wupui`/`getSuperFansInfo` 与 `wupui`/`getSuperFansRankPanel`。
/// - sBuffer 为 `map<string, vector<byte>>`:`{"tReq": <req struct 编码>}`,
///   响应同构取 `tRsp`。
/// - 封包/解包复用仓库既有 TUP 管线(pkg/tars 的 UniPacket/RequestPacket):
///   其 tag1..tag10 与 sBuffer map 编码和真源 `buildTupPacket`/`writeBytesMap`
///   字节同构,cdns 网关与 wup.huya.com 同属一套 Tars 框架(仓库 getCdnTokenEx
///   /getHeadLineMessageBoard 已在同管线实测可用)。
/// - 数据诚实性:任何失败(网络/超时/结构不符)返回 null,调用方留空不伪造;
///   超粉置信度校验同真源 `isPlausibleHuyaSuperFanCount`(>0、≠presenterUid、
///   ≤500 万)。
library;

import 'package:pure_live/pkg/tars/codec/tars_displayer.dart';
import 'package:pure_live/pkg/tars/codec/tars_input_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_output_stream.dart';
import 'package:pure_live/pkg/tars/codec/tars_struct.dart';
import 'package:pure_live/pkg/tars/net/base_tars_http.dart';

/// wup 网关(web huya-wup.ts 的 WUP_URL)。
const String kHuyaWupGateway = 'https://cdnws.api.huya.com';

/// Content-Type 用二进制流(真源 kHuyaWupHeaders 注明必须是二进制流);
/// UA 与 Origin/Referer 同真源 kHuyaWupHeaders。
const Map<String, String> kHuyaWupHeaders = {
  'content-type': 'application/octet-stream',
  'user-agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  'origin': 'https://www.huya.com',
  'referer': 'https://www.huya.com/',
};

/// 匿名观众身份(webh5&0.0.0&official,真源 _kUserToken)。
const String kHuyaWupUserToken = 'webh5&0.0.0&official';

/// 只写 tag3(sHuyaUserId)的最小身份结构,字节对齐真源
/// `userId.writeString(_kUserToken, 3)`;仓库通用 HuyaUserId(core/tars/types.dart)
/// 会多写 0/空值字段,服务端虽兼容,这里按真源最小化。
class WupUserToken extends TarsStruct {
  String sHuyaUserId = '';

  @override
  void readFrom(TarsInputStream inputStream) {
    sHuyaUserId = inputStream.read(sHuyaUserId, 3, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(sHuyaUserId, 3);
  }

  @override
  Object deepCopy() => WupUserToken()..sHuyaUserId = sHuyaUserId;

  @override
  void displayAsString(StringBuffer sb, int level) {
    TarsDisplayer(sb, level: level).DisplayString(sHuyaUserId, 'sHuyaUserId');
  }
}

/// liveui/getVipBarList 请求(VipListReq,真源 huya_wup.dart:73-95):
/// tag0 tUserId、tag1 lTid=channelId、tag2 lSid=channelId、tag3 iStart=0、
/// tag4 iCount=1、tag5 lPid=presenterUid、tag6 iUidNum=0。
class HuyaVipListReq extends TarsStruct {
  WupUserToken tUserId = WupUserToken()..sHuyaUserId = kHuyaWupUserToken;
  int lTid = 0;
  int lSid = 0;
  int iStart = 0;
  int iCount = 1;
  int lPid = 0;
  int iUidNum = 0;

  @override
  void readFrom(TarsInputStream inputStream) {
    tUserId = inputStream.read(tUserId, 0, false);
    lTid = inputStream.read(lTid, 1, false);
    lSid = inputStream.read(lSid, 2, false);
    iStart = inputStream.read(iStart, 3, false);
    iCount = inputStream.read(iCount, 4, false);
    lPid = inputStream.read(lPid, 5, false);
    iUidNum = inputStream.read(iUidNum, 6, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(tUserId, 0);
    outputStream.write(lTid, 1);
    outputStream.write(lSid, 2);
    outputStream.write(iStart, 3);
    outputStream.write(iCount, 4);
    outputStream.write(lPid, 5);
    outputStream.write(iUidNum, 6);
  }

  @override
  Object deepCopy() => HuyaVipListReq()
    ..tUserId = (tUserId.deepCopy() as WupUserToken)
    ..lTid = lTid
    ..lSid = lSid
    ..iStart = iStart
    ..iCount = iCount
    ..lPid = lPid
    ..iUidNum = iUidNum;

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayTarsStruct(tUserId, 'tUserId');
    ds.DisplayInt(lTid, 'lTid');
    ds.DisplayInt(lSid, 'lSid');
    ds.DisplayInt(iStart, 'iStart');
    ds.DisplayInt(iCount, 'iCount');
    ds.DisplayInt(lPid, 'lPid');
    ds.DisplayInt(iUidNum, 'iUidNum');
  }
}

/// getVipBarList 响应(VipBarListRsp):tag3 iTotal(当前条目数)、
/// tag10 iTotalNum(贵宾总数,侧栏「贵宾」行口径)。
class HuyaVipBarListRsp extends TarsStruct {
  int iTotal = 0;
  int iTotalNum = 0;

  @override
  void readFrom(TarsInputStream inputStream) {
    iTotal = inputStream.read(iTotal, 3, false);
    iTotalNum = inputStream.read(iTotalNum, 10, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(iTotal, 3);
    outputStream.write(iTotalNum, 10);
  }

  @override
  Object deepCopy() => HuyaVipBarListRsp()
    ..iTotal = iTotal
    ..iTotalNum = iTotalNum;

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayInt(iTotal, 'iTotal');
    ds.DisplayInt(iTotalNum, 'iTotalNum');
  }
}

/// wupui/getSuperFansInfo 请求(GetSuperFansInfoReq,真源 huya_wup.dart:142-161):
/// tag0 tUserId、tag1 lPid=presenterUid、tag2 lTid=channelId、tag3 lSid=channelId
/// (注意与 VipListReq 的字段编号不同)。
class HuyaSuperFansInfoReq extends TarsStruct {
  WupUserToken tUserId = WupUserToken()..sHuyaUserId = kHuyaWupUserToken;
  int lPid = 0;
  int lTid = 0;
  int lSid = 0;

  @override
  void readFrom(TarsInputStream inputStream) {
    tUserId = inputStream.read(tUserId, 0, false);
    lPid = inputStream.read(lPid, 1, false);
    lTid = inputStream.read(lTid, 2, false);
    lSid = inputStream.read(lSid, 3, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(tUserId, 0);
    outputStream.write(lPid, 1);
    outputStream.write(lTid, 2);
    outputStream.write(lSid, 3);
  }

  @override
  Object deepCopy() => HuyaSuperFansInfoReq()
    ..tUserId = (tUserId.deepCopy() as WupUserToken)
    ..lPid = lPid
    ..lTid = lTid
    ..lSid = lSid;

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayTarsStruct(tUserId, 'tUserId');
    ds.DisplayInt(lPid, 'lPid');
    ds.DisplayInt(lTid, 'lTid');
    ds.DisplayInt(lSid, 'lSid');
  }
}

/// getSuperFansInfo 响应(GetSuperFansInfoRsp):tag1 iSuperFansNum、
/// tag2 iYearSuperFansNum;web 口径取两者之和。
class HuyaSuperFansInfoRsp extends TarsStruct {
  int iSuperFansNum = 0;
  int iYearSuperFansNum = 0;

  int get total => iSuperFansNum + iYearSuperFansNum;

  @override
  void readFrom(TarsInputStream inputStream) {
    iSuperFansNum = inputStream.read(iSuperFansNum, 1, false);
    iYearSuperFansNum = inputStream.read(iYearSuperFansNum, 2, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(iSuperFansNum, 1);
    outputStream.write(iYearSuperFansNum, 2);
  }

  @override
  Object deepCopy() => HuyaSuperFansInfoRsp()
    ..iSuperFansNum = iSuperFansNum
    ..iYearSuperFansNum = iYearSuperFansNum;

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayInt(iSuperFansNum, 'iSuperFansNum');
    ds.DisplayInt(iYearSuperFansNum, 'iYearSuperFansNum');
  }
}

/// wupui/getSuperFansRankPanel 请求(GetSuperFansRankPanelReq,真源
/// huya_wup.dart:168-188):tag0 tUserId、tag1 lPid、tag2 iPage=0、tag3 iCount=1
/// (web 真源只填 lPid,不发 channelId)。
class HuyaSuperFansRankPanelReq extends TarsStruct {
  WupUserToken tUserId = WupUserToken()..sHuyaUserId = kHuyaWupUserToken;
  int lPid = 0;
  int iPage = 0;
  int iCount = 1;

  @override
  void readFrom(TarsInputStream inputStream) {
    tUserId = inputStream.read(tUserId, 0, false);
    lPid = inputStream.read(lPid, 1, false);
    iPage = inputStream.read(iPage, 2, false);
    iCount = inputStream.read(iCount, 3, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(tUserId, 0);
    outputStream.write(lPid, 1);
    outputStream.write(iPage, 2);
    outputStream.write(iCount, 3);
  }

  @override
  Object deepCopy() => HuyaSuperFansRankPanelReq()
    ..tUserId = (tUserId.deepCopy() as WupUserToken)
    ..lPid = lPid
    ..iPage = iPage
    ..iCount = iCount;

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayTarsStruct(tUserId, 'tUserId');
    ds.DisplayInt(lPid, 'lPid');
    ds.DisplayInt(iPage, 'iPage');
    ds.DisplayInt(iCount, 'iCount');
  }
}

/// getSuperFansRankPanel 响应(GetSuperFansRankPanelRsp):tag5 iNum、
/// tag10 iPlusNum;web 口径取两者之和。
class HuyaSuperFansRankPanelRsp extends TarsStruct {
  int iNum = 0;
  int iPlusNum = 0;

  int get total => iNum + iPlusNum;

  @override
  void readFrom(TarsInputStream inputStream) {
    iNum = inputStream.read(iNum, 5, false);
    iPlusNum = inputStream.read(iPlusNum, 10, false);
  }

  @override
  void writeTo(TarsOutputStream outputStream) {
    outputStream.write(iNum, 5);
    outputStream.write(iPlusNum, 10);
  }

  @override
  Object deepCopy() => HuyaSuperFansRankPanelRsp()
    ..iNum = iNum
    ..iPlusNum = iPlusNum;

  @override
  void displayAsString(StringBuffer sb, int level) {
    final ds = TarsDisplayer(sb, level: level);
    ds.DisplayInt(iNum, 'iNum');
    ds.DisplayInt(iPlusNum, 'iPlusNum');
  }
}

/// web `isPlausibleHuyaSuperFanCount`:>0、不等于 presenterUid(uid 原样回显
/// 视为脏值)、且 ≤ 5_000_000;不满足即视为不可信,不得展示。
bool isPlausibleHuyaSuperFanCount(int total, int presenterUid) {
  if (total <= 0) return false;
  if (total == presenterUid) return false;
  if (total > 5000000) return false;
  return true;
}

/// 每次调用自建自关的 wup 客户端(与 huya_utils 的消息板/取 token 客户端同一
/// 生命周期习惯:不与播放链路共享连接,失败不互相拖累)。超时对齐同文件
/// 既有 wup 调用的 6s 档。
BaseTarsHttp createHuyaVipWupClient(String servantName) {
  final client = BaseTarsHttp(
    kHuyaWupGateway,
    servantName,
    path: '/?baseinfo=default',
    timeOut: 6,
    headers: kHuyaWupHeaders,
  );
  client.dio.options.sendTimeout = const Duration(seconds: 6);
  client.dio.options.receiveTimeout = const Duration(seconds: 6);
  return client;
}

/// liveui/getVipBarList → 贵宾总数(iTotalNum);presenterUid 无效/任何失败
/// 返回 null,调用方留空不伪造(与真源 fetchVipBarCount 的 catch→null 同语义)。
Future<int?> fetchHuyaVipBarCount({required int presenterUid, required int channelId}) async {
  if (presenterUid <= 0) return null;
  final effectiveChannelId = channelId <= 0 ? presenterUid : channelId;
  final client = createHuyaVipWupClient('liveui');
  try {
    final req = HuyaVipListReq()
      ..lTid = effectiveChannelId
      ..lSid = effectiveChannelId
      ..lPid = presenterUid;
    final rsp = await client.tupRequest('getVipBarList', req, HuyaVipBarListRsp()).timeout(const Duration(seconds: 8));
    return rsp.iTotalNum;
  } catch (_) {
    return null;
  } finally {
    client.dio.close(force: true);
  }
}

/// 超粉人数(真源 fetchHuyaSuperFanCount 口径):getSuperFansInfo
/// (iSuperFansNum + iYearSuperFansNum)与 getSuperFansRankPanel(iNum + iPlusNum)
/// **并发**发出,取第一个通过 [isPlausibleHuyaSuperFanCount] 的结果;
/// 都不可信(或请求失败)返回 null,调用方留空,不回填 0。
Future<int?> fetchHuyaSuperFanCount({required int presenterUid, required int channelId}) async {
  if (presenterUid <= 0) return null;
  final totals = await Future.wait<int?>([
    _fetchSuperFansInfoTotal(presenterUid: presenterUid, channelId: channelId),
    _fetchSuperFansPanelTotal(presenterUid: presenterUid),
  ]);
  for (final total in totals) {
    final value = total ?? 0;
    if (isPlausibleHuyaSuperFanCount(value, presenterUid)) return value;
  }
  return null;
}

Future<int?> _fetchSuperFansInfoTotal({required int presenterUid, required int channelId}) async {
  final effectiveChannelId = channelId <= 0 ? presenterUid : channelId;
  final client = createHuyaVipWupClient('wupui');
  try {
    final req = HuyaSuperFansInfoReq()
      ..lPid = presenterUid
      ..lTid = effectiveChannelId
      ..lSid = effectiveChannelId;
    final rsp = await client
        .tupRequest('getSuperFansInfo', req, HuyaSuperFansInfoRsp())
        .timeout(const Duration(seconds: 8));
    return rsp.total;
  } catch (_) {
    return null;
  } finally {
    client.dio.close(force: true);
  }
}

Future<int?> _fetchSuperFansPanelTotal({required int presenterUid}) async {
  final client = createHuyaVipWupClient('wupui');
  try {
    final req = HuyaSuperFansRankPanelReq()..lPid = presenterUid;
    final rsp = await client
        .tupRequest('getSuperFansRankPanel', req, HuyaSuperFansRankPanelRsp())
        .timeout(const Duration(seconds: 8));
    return rsp.total;
  } catch (_) {
    return null;
  } finally {
    client.dio.close(force: true);
  }
}

// 注:kHuyaWupHeaders 的 'content-type' 键用小写,与 BaseTarsHttp 默认写入的
// HttpHeaders.contentTypeHeader('content-type')同名同键,字面量展开时精确覆盖
// 其默认的 application/x-wup。
