/**
 * BiliBili ResolverBackend — port of lib/core/site/bilibili/bilibili_site.dart
 * (room detail, WBI signing, buvid cookies, qualities, play URLs) and the
 * bilibili branch of lib/core/common/playback_header_resolver.dart.
 */
import { createHash } from 'node:crypto';
import { getJson } from '../http.js';
import { badRequest, roomClosed, roomNotFound, upstreamError } from '../errors.js';
import type {
  LiveRoomInfo,
  LiveStatusValue,
  PlayUrlsResult,
  QualityInfo,
  ResolverBackend,
  StreamProtocol,
} from './types.js';

export const BILIBILI_USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36';
const BILIBILI_REFERER = 'https://live.bilibili.com/';

/* ------------------------------- buvid cookies ------------------------------ */

let buvid3 = '';
let buvid4 = '';
let buvidRequest: Promise<void> | null = null;

async function fetchBuvid(): Promise<void> {
  try {
    const result = await getJson<{ code?: number; data?: { b_3?: string; b_4?: string } }>(
      'https://api.bilibili.com/x/frontend/finger/spi',
      { headers: baseHeaders() },
    );
    buvid3 = result?.data?.b_3 ?? '';
    buvid4 = result?.data?.b_4 ?? '';
  } catch {
    // Anonymous device cookies are best-effort; requests still work without them.
    buvid3 = '';
    buvid4 = '';
  }
}

function ensureBuvid(): Promise<void> {
  if (!buvid3 && !buvidRequest) {
    buvidRequest = fetchBuvid().finally(() => {
      buvidRequest = null;
    });
  }
  return buvidRequest ?? Promise.resolve();
}

/* ---------------------------------- headers --------------------------------- */

function baseHeaders(): Record<string, string> {
  return { 'user-agent': BILIBILI_USER_AGENT, referer: BILIBILI_REFERER };
}

function cookieHeader(): string {
  return buvid3 ? `buvid3=${buvid3};buvid4=${buvid4};` : '';
}

/** Headers for upstream API requests (mirrors BiliBiliSite.getHeader). */
async function apiHeaders(): Promise<Record<string, string>> {
  await ensureBuvid();
  const cookie = cookieHeader();
  return cookie ? { ...baseHeaders(), cookie } : baseHeaders();
}

/** Playback headers (mirrors PlaybackHeaderResolver.resolve for bilibili). */
function playbackHeaders(roomId: string): Record<string, string> {
  const cookie = cookieHeader();
  return {
    'user-agent': BILIBILI_USER_AGENT,
    origin: 'https://live.bilibili.com',
    referer: roomId ? `https://live.bilibili.com/${roomId}` : BILIBILI_REFERER,
    ...(cookie ? { cookie } : {}),
  };
}

/* --------------------------------- WBI signing ------------------------------- */

const MIXIN_KEY_ENC_TAB = [
  46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49, 33, 9, 42, 19, 29, 28,
  14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40, 61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54,
  21, 56, 59, 6, 63, 57, 62, 11, 36, 20, 34, 44, 52,
];

let wbiImgKey = '';
let wbiSubKey = '';
let wbiKeysUpdatedAt = 0;
let wbiKeysRequest: Promise<void> | null = null;

async function fetchWbiKeys(forceRefresh: boolean): Promise<void> {
  const age = Date.now() - wbiKeysUpdatedAt;
  if (!forceRefresh && wbiImgKey && wbiSubKey && age < 6 * 3600 * 1000) return;
  if (wbiKeysRequest) return wbiKeysRequest;

  const op = (async () => {
    const resp = await getJson<{ data?: { wbi_img?: { img_url?: string; sub_url?: string } } }>(
      'https://api.bilibili.com/x/web-interface/nav',
      { headers: await apiHeaders() },
    );
    const img = resp?.data?.wbi_img?.img_url ?? '';
    const sub = resp?.data?.wbi_img?.sub_url ?? '';
    const imgKey = img.slice(img.lastIndexOf('/') + 1).split('.')[0] ?? '';
    const subKey = sub.slice(sub.lastIndexOf('/') + 1).split('.')[0] ?? '';
    if (!imgKey || !subKey) throw upstreamError('bilibili WBI keys payload is incomplete');
    wbiImgKey = imgKey;
    wbiSubKey = subKey;
    wbiKeysUpdatedAt = Date.now();
  })().finally(() => {
    wbiKeysRequest = null;
  });
  wbiKeysRequest = op;
  return op;
}

function mixinKey(origin: string): string {
  return MIXIN_KEY_ENC_TAB.map((i) => origin[i] ?? '').join('').slice(0, 32);
}

/** Dart Uri.encodeQueryComponent: space -> '+', !'()* percent-encoded. */
function encodeQueryComponent(value: string): string {
  return encodeURIComponent(value)
    .replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`)
    .replace(/%20/g, '+');
}

/** WBI-signs request params (port of BiliBiliSite.getWbiSign). */
async function wbiSign(params: Record<string, string | number>, forceRefresh = false): Promise<Record<string, string>> {
  await fetchWbiKeys(forceRefresh);
  const mixin = mixinKey(wbiImgKey + wbiSubKey);
  const withTs: Record<string, string> = {};
  for (const [k, v] of Object.entries(params)) withTs[k] = String(v);
  withTs.wts = String(Math.floor(Date.now() / 1000));

  const sorted: Record<string, string> = {};
  for (const key of Object.keys(withTs).sort()) {
    sorted[key] = [...(withTs[key] ?? '')].filter((c) => !"!'()*".includes(c)).join('');
  }
  const query = Object.entries(sorted)
    .map(([k, v]) => `${k}=${encodeQueryComponent(v)}`)
    .join('&');
  const wRid = createHash('md5').update(query + mixin, 'utf8').digest('hex');
  return { ...sorted, w_rid: wRid };
}

/** Shared WBI signer for the danmaku module. */
export const exportedWbiSign = wbiSign;

/** Shared anonymous-device cookie state for the danmaku module. */
export async function buvidState(): Promise<{ buvid3: string; buvid4: string; cookie: string }> {
  await ensureBuvid();
  return { buvid3, buvid4, cookie: cookieHeader() };
}

/* --------------------------------- room info --------------------------------- */

interface BilibiliRoomResponse {
  code?: number;
  message?: string;
  data?: {
    room_info?: {
      room_id?: number | string;
      title?: string;
      cover?: string;
      online?: number | string;
      live_status?: number | string;
      area_name?: string;
      description?: string;
    };
    anchor_info?: { base_info?: { uname?: string; face?: string } };
  };
}

async function requestRoomInfo(roomId: string): Promise<NonNullable<BilibiliRoomResponse['data']>> {
  let lastError: unknown = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    try {
      const signed = await wbiSign({ room_id: roomId }, attempt > 0);
      const resp = await getJson<BilibiliRoomResponse>(
        'https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom',
        { params: signed, headers: await apiHeaders() },
      );
      if (typeof resp?.code !== 'number') throw upstreamError('bilibili room response is not an object');
      if (resp.code !== 0) {
        const message = resp.message ?? '';
        // 19002000 = room does not exist (distinguishable from other failures).
        if (message.includes('不存在') || resp.code === 19002000) {
          throw roomNotFound(`bilibili room ${roomId} does not exist`);
        }
        throw upstreamError(`bilibili room request rejected: code=${resp.code} ${message}`);
      }
      const data = resp.data;
      if (!data?.room_info || !data.anchor_info) throw upstreamError('bilibili room metadata is incomplete');
      return data;
    } catch (error) {
      lastError = error;
      if (attempt === 0) await new Promise((r) => setTimeout(r, 180));
    }
  }
  throw lastError instanceof Error ? lastError : upstreamError('bilibili room info failed');
}

function mapLiveStatus(liveStatus: number | string | undefined): { status: boolean; liveStatus: LiveStatusValue } {
  const value = Number(liveStatus ?? 0);
  if (value === 1) return { status: true, liveStatus: 'live' };
  if (value === 2) return { status: false, liveStatus: 'replay' };
  return { status: false, liveStatus: 'offline' };
}

/* ------------------------------- play info API ------------------------------- */

interface PlayInfoResponse {
  code?: number;
  message?: string;
  data?: {
    playurl_info?: {
      playurl?: {
        g_qn_desc?: Array<{ qn?: number | string; desc?: string }>;
        stream?: Array<{
          protocol_name?: string;
          format?: Array<{
            format_name?: string;
            codec?: Array<{
              current_qn?: number | string;
              accept_qn?: Array<number | string>;
              base_url?: string;
              codec_name?: string;
              url_info?: Array<{ host?: string; extra?: string }>;
            }>;
          }>;
        }>;
      };
    };
  };
}

interface BilibiliCodec {
  current_qn?: number | string;
  accept_qn?: Array<number | string>;
  base_url?: string;
  codec_name?: string;
  url_info?: Array<{ host?: string; extra?: string }>;
}

type PlayUrlPayload = NonNullable<NonNullable<NonNullable<PlayInfoResponse['data']>['playurl_info']>['playurl']>;

interface CodecPayload {
  codec: BilibiliCodec;
  format: string;
  protocol: string;
}

async function requestPlayInfo(roomId: string, qn: number): Promise<PlayInfoResponse> {
  const headers = await apiHeaders();
  return getJson<PlayInfoResponse>(
    'https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo',
    {
      params: {
        room_id: roomId,
        protocol: '0,1',
        format: '0,1,2',
        codec: '0',
        qn: String(qn),
        platform: 'web',
        ptype: '8',
        dolby: '5',
        panorama: '1',
        mask: '0',
        no_playurl: '0',
      },
      headers,
    },
  );
}

function playUrlPayload(response: PlayInfoResponse): PlayUrlPayload {
  if (typeof response?.code !== 'number') throw upstreamError('bilibili play response is not an object');
  if (response.code !== 0) {
    throw upstreamError(`bilibili play API code=${response.code}: ${response.message ?? ''}`);
  }
  const playurl = response.data?.playurl_info?.playurl;
  if (!playurl || typeof playurl !== 'object') throw upstreamError('bilibili playurl payload is missing');
  return playurl;
}

function* codecPayloads(playUrl: PlayUrlPayload): Generator<CodecPayload> {
  for (const rawStream of playUrl.stream ?? []) {
    const protocol = rawStream?.protocol_name ?? '';
    for (const rawFormat of rawStream?.format ?? []) {
      const format = rawFormat?.format_name ?? '';
      for (const codec of rawFormat?.codec ?? []) {
        if (codec) yield { codec, format, protocol };
      }
    }
  }
}

/* ------------------------------ quality labels ------------------------------- */

function containsCjk(text: string): boolean {
  return /[\u4e00-\u9fff\u3400-\u4dbf]/.test(text);
}

const BILIBILI_QN_LABELS: Record<number, string> = {
  30000: '杜比',
  20000: '4K',
  10000: '原画',
  400: '蓝光',
  250: '超清',
  150: '高清',
  80: '流畅',
};

/** Port of LiveQualityLabel.normalize for bilibili. */
function normalizeQualityLabel(rawLabel: string, qn: number): string {
  const raw = rawLabel.trim().replace(/\s+/g, ' ');
  if (containsCjk(raw)) return raw;
  const mapped = BILIBILI_QN_LABELS[qn];
  if (mapped) return mapped;
  if (raw) return raw;
  return `清晰度 ${qn}`;
}

/* ----------------------------- play URL resolution ---------------------------- */

interface StreamCandidate {
  url: string;
  currentQn: number;
  protocol: string;
  format: string;
  codec: string;
}

const protocolRank = (value: string): number => (value === 'http_stream' ? 0 : 1);
const formatRank = (value: string): number => (value === 'flv' ? 0 : value === 'ts' ? 1 : value === 'fmp4' ? 2 : 3);
const codecRank = (value: string): number => (value === 'avc' ? 0 : 1);

/**
 * Port of BiliBiliSite.parsePlayUrlResolution: keeps the server-acknowledged
 * current_qn and prefers the requested qn, http_stream/flv/avc, non-mcdn CDNs.
 */
function parsePlayUrlResolution(
  response: PlayInfoResponse,
  requestedQn: number,
): { urls: string[]; appliedQn: number; format: string } {
  const playUrl = playUrlPayload(response);
  const candidates: StreamCandidate[] = [];

  for (const payload of codecPayloads(playUrl)) {
    const codec = payload.codec;
    const currentQn = Number(codec?.current_qn ?? 0);
    const baseUrl = codec?.base_url ?? '';
    if (!Number.isFinite(currentQn) || currentQn <= 0 || !baseUrl) continue;
    for (const rawUrl of codec?.url_info ?? []) {
      const url = `${rawUrl?.host ?? ''}${baseUrl}${rawUrl?.extra ?? ''}`.trim();
      if (!url.startsWith('http')) continue;
      candidates.push({
        url,
        currentQn,
        protocol: payload.protocol,
        format: payload.format,
        codec: codec?.codec_name ?? '',
      });
    }
  }

  candidates.sort((a, b) => {
    const requestedOrder =
      ((b.currentQn === requestedQn ? 1 : 0) as number) - ((a.currentQn === requestedQn ? 1 : 0) as number);
    if (requestedOrder !== 0) return requestedOrder;
    const protocolOrder = protocolRank(a.protocol) - protocolRank(b.protocol);
    if (protocolOrder !== 0) return protocolOrder;
    const formatOrder = formatRank(a.format) - formatRank(b.format);
    if (formatOrder !== 0) return formatOrder;
    const codecOrder = codecRank(a.codec) - codecRank(b.codec);
    if (codecOrder !== 0) return codecOrder;
    const cdnOrder = (a.url.includes('mcdn') ? 1 : 0) - (b.url.includes('mcdn') ? 1 : 0);
    if (cdnOrder !== 0) return cdnOrder;
    return a.url.localeCompare(b.url);
  });

  if (candidates.length === 0) return { urls: [], appliedQn: requestedQn, format: '' };

  const appliedQn = candidates[0]!.currentQn;
  const seen = new Set<string>();
  const urls: string[] = [];
  for (const candidate of candidates) {
    if (candidate.currentQn !== appliedQn || seen.has(candidate.url)) continue;
    seen.add(candidate.url);
    urls.push(candidate.url);
  }
  return { urls, appliedQn, format: candidates[0]!.format };
}

function parseQualities(response: PlayInfoResponse): Array<{ qn: number; label: string }> {
  const playUrl = playUrlPayload(response);
  const descriptions = new Map<number, string>();
  for (const raw of playUrl.g_qn_desc ?? []) {
    const qn = Number(raw?.qn ?? 0);
    if (!Number.isFinite(qn) || qn <= 0) continue;
    const desc = (raw?.desc ?? '').trim();
    descriptions.set(qn, desc || '未知清晰度');
  }

  const accepted = new Set<number>();
  for (const payload of codecPayloads(playUrl)) {
    for (const rawQn of payload.codec?.accept_qn ?? []) {
      const qn = Number(rawQn);
      if (Number.isFinite(qn) && qn > 0) accepted.add(qn);
    }
    const current = Number(payload.codec?.current_qn ?? 0);
    if (Number.isFinite(current) && current > 0) accepted.add(current);
  }

  return [...accepted]
    .sort((a, b) => b - a)
    .map((qn) => ({ qn, label: normalizeQualityLabel(descriptions.get(qn) ?? '', qn) }));
}

function formatToProtocol(format: string): StreamProtocol {
  if (format === 'flv') return 'flv';
  if (format === 'ts' || format === 'fmp4') return 'hls';
  return 'unknown';
}

function computeExpireAt(urls: string[]): string {
  try {
    if (!urls[0]) throw new Error('no url');
    const query = new URL(urls[0]).searchParams;
    const expires = Number(query.get('expires') ?? query.get('expire') ?? 0);
    if (Number.isFinite(expires) && expires > 0) {
      // Large values are absolute unix seconds; small values are a relative TTL.
      if (expires > 1_000_000_000) return new Date(expires * 1000).toISOString();
      return new Date(Date.now() + expires * 1000).toISOString();
    }
  } catch {
    // fall through to the default window
  }
  return new Date(Date.now() + 30 * 60 * 1000).toISOString();
}

/* ---------------------------------- backend ---------------------------------- */

export class BilibiliBackend implements ResolverBackend {
  readonly id = 'bilibili';
  readonly name = 'BiliBili';
  readonly capabilities = ['resolve', 'play-urls', 'qualities', 'danmaku'] as const;

  async resolveRoom(roomId: string): Promise<LiveRoomInfo> {
    const info = await requestRoomInfo(roomId);
    const roomInfo = info.room_info!;
    const baseInfo = info.anchor_info!.base_info ?? {};
    const { status, liveStatus } = mapLiveStatus(roomInfo.live_status);
    return {
      platform: this.id,
      roomId,
      title: String(roomInfo.title ?? ''),
      nick: String(baseInfo.uname ?? ''),
      avatar: `${String(baseInfo.face ?? '')}@100w.jpg`,
      cover: String(roomInfo.cover ?? ''),
      watching: String(roomInfo.online ?? ''),
      link: `https://live.bilibili.com/${roomId}`,
      status,
      liveStatus,
    };
  }

  async getQualities(roomId: string): Promise<QualityInfo[]> {
    // Offline rooms return no playurl payload at all; per the contract an
    // offline room is not an error, so advertise an empty quality list.
    try {
      const parsed = parseQualities(await requestPlayInfo(roomId, 0));
      return parsed.map((entry) => ({ selectionId: String(entry.qn), label: entry.label }));
    } catch (error) {
      if (error instanceof Error && error.message.includes('playurl payload is missing')) return [];
      throw error;
    }
  }

  async getPlayUrls(roomId: string, quality?: string): Promise<PlayUrlsResult> {
    let requestedQn = 0;
    if (quality !== undefined && quality !== '') {
      const asQn = Number(quality);
      if (Number.isInteger(asQn) && asQn > 0) {
        requestedQn = asQn;
      } else {
        const qualities = parseQualities(await requestPlayInfo(roomId, 0));
        const match = qualities.find((entry) => entry.label === quality);
        if (!match) {
          throw badRequest(
            `unknown quality "${quality}"; available: ${qualities.map((q) => q.label).join(', ')}`,
          );
        }
        requestedQn = match.qn;
      }
    }

    const response = await requestPlayInfo(roomId, requestedQn);
    const { urls, appliedQn, format } = parsePlayUrlResolution(response, requestedQn);

    if (urls.length === 0) {
      const info = await requestRoomInfo(roomId);
      const liveStatus = mapLiveStatus(info.room_info?.live_status).liveStatus;
      if (liveStatus !== 'live') throw roomClosed(`bilibili room ${roomId} is not live (${liveStatus})`);
      throw upstreamError('bilibili returned no playable stream candidates');
    }

    const parsed = parseQualities(response);
    const applied = parsed.find((entry) => entry.qn === appliedQn);

    return {
      platform: this.id,
      roomId,
      quality: applied ? applied.label : normalizeQualityLabel('', appliedQn),
      protocol: formatToProtocol(format),
      urls,
      headers: playbackHeaders(roomId),
      expireAt: computeExpireAt(urls),
      sourceQueryPolicies: {},
    };
  }

  cdnHostSuffixes(): readonly string[] {
    // Bilibili live streams are served by its own CDN plus third parties the
    // play URLs (and their redirects) commonly land on. smtcdns.net is
    // Tencent's HTTPDNS CNAME that bilivideo hosts frequently resolve to.
    return [
      'bilivideo.com',
      'bilivideo.cn',
      'akamaized.net',
      'hdslb.com',
      'smtcdns.net',
      'mwplaycdn.com',
      'qinghuacdn.com',
    ];
  }
}
