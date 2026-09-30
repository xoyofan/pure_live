/**
 * Douyin ResolverBackend — port of lib/core/site/douyin/douyin_site.dart,
 * lib/core/utils/douyin/douyin_utils.dart (a_bogus-signed request URLs) and
 * the douyin branch of lib/core/common/playback_header_resolver.dart.
 */
import { getJson, getText, getTextWithCookies, headSetCookies, upstreamStatusOf } from '../http.js';
import { badRequest, roomClosed, roomNotFound, upstreamError } from '../errors.js';
import { generateAbogus } from '../sign/abogus.js';
import type {
  LiveRoomInfo,
  LiveStatusValue,
  PlayUrlsResult,
  QualityInfo,
  ResolverBackend,
  StreamProtocol,
} from './types.js';

/** DouyinRequestParams.kDefaultUserAgent (API requests). */
const DOUYIN_API_USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.36';
/** PlaybackHeaderResolver desktop UA (stream pulls). */
const DOUYIN_PLAY_USER_AGENT =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
const DOUYIN_REFERER = 'https://live.douyin.com';
const AID = '6383';

/* ------------------------------ anonymous cookie ------------------------------ */

let anonymousCookie = '';
let anonymousCookieAt = 0;
let anonymousCookieRequest: Promise<string> | null = null;
const ANONYMOUS_COOKIE_TTL_MS = 6 * 3600 * 1000;

async function fetchAnonymousCookie(): Promise<string> {
  const { setCookie } = await getTextWithCookies('https://live.douyin.com/', {
    params: { from_nav: '1' },
    headers: { referer: DOUYIN_REFERER, 'user-agent': DOUYIN_API_USER_AGENT },
  });
  const pairs: string[] = [];
  for (const value of setCookie) {
    const pair = (value.split(';')[0] ?? '').trim();
    if (pair.startsWith('ttwid=') || pair.startsWith('UIFID_TEMP=')) pairs.push(pair);
  }
  return pairs.join('; ');
}

async function getCookie(): Promise<string> {
  if (anonymousCookie && Date.now() - anonymousCookieAt < ANONYMOUS_COOKIE_TTL_MS) return anonymousCookie;
  if (!anonymousCookieRequest) {
    anonymousCookieRequest = fetchAnonymousCookie()
      .then((cookie) => {
        anonymousCookie = cookie;
        anonymousCookieAt = Date.now();
        return cookie;
      })
      .catch(() => '')
      .finally(() => {
        anonymousCookieRequest = null;
      });
  }
  return anonymousCookieRequest;
}

/** API request headers (mirrors DouyinSite.getRequestHeaders). */
export async function apiHeaders(): Promise<Record<string, string>> {
  const cookie = await getCookie();
  const headers: Record<string, string> = {
    referer: DOUYIN_REFERER,
    'user-agent': DOUYIN_API_USER_AGENT,
    accept: 'application/json, text/plain, */*',
  };
  return cookie ? { ...headers, cookie } : headers;
}

/** Playback headers (mirrors PlaybackHeaderResolver.resolve for douyin). */
function playbackHeaders(roomId: string, cookie: string): Record<string, string> {
  return {
    'user-agent': DOUYIN_PLAY_USER_AGENT,
    origin: 'https://live.douyin.com',
    referer: roomId ? `https://live.douyin.com/${roomId}` : `${DOUYIN_REFERER}/`,
    ...(cookie ? { cookie } : {}),
  };
}

/* ------------------------------ signed request URL ---------------------------- */

function getMSToken(randomLength = 184): string {
  const baseStr = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789=';
  let out = '';
  for (let i = 0; i < randomLength; i++) {
    out += baseStr[Math.floor(Math.random() * baseStr.length)];
  }
  return out;
}

/** Dart Uri.encodeQueryComponent: space -> '+', !'()* percent-encoded. */
function encodeQueryComponent(value: string): string {
  return encodeURIComponent(value)
    .replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`)
    .replace(/%20/g, '+');
}

/** Port of DouyinUtils.buildRequestUrl: merges params and appends a_bogus. */
export function buildSignedUrl(baseUrl: string, params: Record<string, string>): string {
  const parsed = new URL(baseUrl);
  const exParams: Record<string, string> = {};
  parsed.searchParams.forEach((value, key) => {
    exParams[key] = value;
  });
  for (const [key, value] of Object.entries(params)) exParams[key] = value;
  exParams['aid'] = AID;
  exParams['compress'] = 'gzip';
  exParams['device_platform'] = 'web';
  exParams['browser_language'] = 'zh-CN';
  exParams['browser_platform'] = 'Win32';
  exParams['browser_name'] = 'Edge';
  exParams['browser_version'] = '125.0.0.0';
  if (!('msToken' in exParams)) exParams['msToken'] = getMSToken();

  const newQueryStr = Object.entries(exParams)
    .map(([k, v]) => `${encodeQueryComponent(k)}=${encodeQueryComponent(v)}`)
    .join('&');
  const signedQueryStr = generateAbogus(newQueryStr, { userAgent: DOUYIN_API_USER_AGENT });
  return `${parsed.origin}${parsed.pathname}?${signedQueryStr}`;
}

/* --------------------------------- audience ---------------------------------- */

const hasDigits = (text: string): boolean => /[0-9]/.test(text);

function asStringMap(value: unknown): Record<string, unknown> | null {
  return value && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function readText(value: unknown): string {
  const text = value === null || value === undefined ? '' : String(value).trim();
  return text === 'null' ? '' : text;
}

/** Port of douyinOnlineViewers: concurrent audience fields only. */
function douyinOnlineViewers(room: unknown): string {
  const r = asStringMap(room);
  if (!r) return '';
  const viewStats = asStringMap(r['room_view_stats']);
  const roomStats = asStringMap(r['stats']);
  const candidates = [
    r['user_count'],
    r['user_count_str'],
    r['online_user_count'],
    r['online_user_for_anchor'],
    viewStats?.['user_count'],
    viewStats?.['online_user_count'],
    viewStats?.['online_user_for_anchor'],
    roomStats?.['user_count'],
    roomStats?.['online_user_count'],
    roomStats?.['online_user_for_anchor'],
  ];
  for (const value of candidates) {
    const text = readText(value);
    if (text && hasDigits(text)) return text;
  }
  return '';
}

/** Port of douyinTotalViewers: cumulative audience fields only. */
function douyinTotalViewers(room: unknown): string {
  const r = asStringMap(room);
  if (!r) return '';
  const viewStats = asStringMap(r['room_view_stats']);
  const roomStats = asStringMap(r['stats']);
  const candidates = [
    viewStats?.['display_value'],
    viewStats?.['total_user_str'],
    viewStats?.['total_user'],
    roomStats?.['total_user_str'],
    roomStats?.['total_user'],
    r['total_user_str'],
    r['total_user'],
  ];
  for (const value of candidates) {
    const text = readText(value);
    if (!text || !hasDigits(text)) continue;
    const normalized = text.replaceAll(',', '').replaceAll('，', '');
    const number = Number(normalized.match(/[0-9]+(?:\.[0-9]+)?/)?.[0] ?? 0);
    if (number > 0) return text;
  }
  return '';
}

/* ------------------------------ quality helpers ------------------------------- */

function containsCjk(text: string): boolean {
  return /[\u3400-\u9fff]/.test(text);
}

const token = (value: string): string => value.toLowerCase().replaceAll(/[^a-z0-9]+/g, '');

const GENERIC_LABELS: Record<string, string> = {
  original: '原画',
  origin: '原画',
  origion: '原画',
  source: '原画',
  blue: '蓝光',
  bluray: '蓝光',
  uhd: '超清',
  super: '超清',
  superhd: '超清',
  fullhd: '超清',
  fhd: '超清',
  hd: '高清',
  high: '高清',
  sd: '标清',
  standard: '标清',
  medium: '标清',
  low: '流畅',
  ld: '流畅',
  smooth: '流畅',
  fluent: '流畅',
  auto: '自动',
  default: '默认',
};

function resolutionLabel(value: string): string | null {
  const match = value.match(/(\d{3,5})\s*[x×]\s*(\d{3,5})/i);
  if (!match) return null;
  const width = Number(match[1]);
  const height = Number(match[2]);
  const shortSide = Math.min(width, height);
  if (shortSide >= 2160) return '4K';
  if (shortSide >= 1440) return '2K 超清';
  if (shortSide >= 1080) return '1080P 高清';
  if (shortSide >= 720) return '720P 清晰';
  if (shortSide >= 480) return '480P 流畅';
  if (shortSide >= 360) return '360P 极速';
  return `${shortSide}P`;
}

/** Port of LiveQualityLabel.normalize for douyin. */
function normalizeQualityLabel(rawLabel: string, id: string, resolution?: string, bitrate?: number): string {
  const raw = rawLabel.trim().replace(/\s+/g, ' ');
  if (containsCjk(raw)) return raw;

  const tk = token(raw || id);
  const mapped: Record<string, string> = {
    origin: '原画',
    origion: '原画',
    original: '原画',
    source: '原画',
    fullhd: '蓝光',
    fullhd1: '蓝光',
    uhd: '蓝光',
    uhd1: '蓝光',
    blue: '蓝光',
    bluray: '蓝光',
    blueray: '蓝光',
    fhd: '超清',
    hd: '超清',
    hd1: '超清',
    sd: '高清',
    sd2: '高清',
    ld: '标清',
    sd1: '标清',
    md: '流畅',
    auto: '自动',
  };
  const label = mapped[tk] ?? GENERIC_LABELS[tk] ?? null;
  if (label) return label;

  const resLabel = resolution ? resolutionLabel(resolution) : null;
  if (resLabel) return resLabel;
  if (raw) return raw;
  if (bitrate && bitrate > 0) {
    if (bitrate >= 1_000_000) {
      const mbps = bitrate / 1_000_000;
      return `${mbps.toFixed(Number.isInteger(mbps) ? 0 : 1)} Mbps`;
    }
    return `${Math.round(bitrate / 1000)} Kbps`;
  }
  const idText = id.trim();
  return idText ? `清晰度 ${idText}` : '默认';
}

const DOUYIN_QUALITY_RANK: Record<string, number> = {
  ORIGION: 6_000_000,
  ORIGIN: 6_000_000,
  FULL_HD1: 5_000_000,
  UHD: 5_000_000,
  HD1: 4_000_000,
  HD: 4_000_000,
  SD2: 3_000_000,
  SD: 3_000_000,
  SD1: 2_000_000,
  LD: 2_000_000,
  MD: 1_000_000,
};

function caseInsensitiveValue(map: Record<string, unknown>, key: string): unknown {
  const direct = map[key];
  if (direct !== undefined) return direct;
  const normalized = key.toLowerCase();
  for (const [k, v] of Object.entries(map)) {
    if (k.toLowerCase() === normalized) return v;
  }
  return undefined;
}

function addPlayableUrl(urls: string[], value: unknown): void {
  const url = readText(value);
  if (!url) return;
  try {
    const uri = new URL(url);
    if (uri.protocol !== 'http:' && uri.protocol !== 'https:') return;
  } catch {
    return;
  }
  if (!urls.includes(url)) urls.push(url);
}

function isAudioOnlyVariant(key: string, urls: string[]): boolean {
  const tk = key.toLowerCase().replaceAll(/[^a-z0-9]+/g, '');
  if (['ao', 'audio', 'audioonly'].includes(tk)) return true;
  if (urls.length === 0) return false;
  return urls.every((url) => {
    const value = new URL(url).searchParams.get('only_audio')?.toLowerCase();
    return value === '1' || value === 'true';
  });
}

function decodeSdkParams(raw: unknown): Record<string, unknown> {
  if (asStringMap(raw)) return raw as Record<string, unknown>;
  const value = readText(raw);
  if (!value.startsWith('{')) return {};
  try {
    const decoded = JSON.parse(value);
    return asStringMap(decoded) ?? {};
  } catch {
    return {};
  }
}

export interface DouyinQuality {
  /** Lowercased sdk key — the opaque selectionId. */
  id: string;
  label: string;
  sort: number;
  urls: string[];
}

/**
 * Port of DouyinSite.parseStreamQualities: joins option descriptors, the
 * decoded stream_data and the legacy pull-url maps by sdk_key (never by
 * position), drops audio-only variants and de-duplicates identical streams.
 */
export function parseStreamQualities(rawStreamUrl: unknown): DouyinQuality[] {
  const streamUrl = asStringMap(rawStreamUrl);
  if (!streamUrl) return [];

  const liveCore = asStringMap(streamUrl['live_core_sdk_data']);
  const pullData = asStringMap(liveCore?.['pull_data']);
  const options = asStringMap(pullData?.['options']);
  const optionQualities = Array.isArray(options?.['qualities'])
    ? (options['qualities'] as unknown[]).map(asStringMap).filter((m): m is Record<string, unknown> => m !== null)
    : [];

  let decodedStreams: Record<string, unknown> = {};
  const streamDataText = readText(pullData?.['stream_data']);
  if (streamDataText.startsWith('{')) {
    try {
      const decoded = JSON.parse(streamDataText);
      const data = asStringMap(decoded)?.['data'];
      if (asStringMap(data)) decodedStreams = data as Record<string, unknown>;
    } catch {
      // Keep legacy maps only.
    }
  }

  const flvMap = asStringMap(streamUrl['flv_pull_url']) ?? {};
  const hlsMap = asStringMap(streamUrl['hls_pull_url_map']) ?? {};
  const resolutionNames = asStringMap(streamUrl['resolution_name']) ?? {};

  const descriptors = new Map<string, Record<string, unknown>>();
  for (const option of optionQualities) {
    const key = readText(option['sdk_key']);
    if (key && !descriptors.has(key.toLowerCase())) descriptors.set(key.toLowerCase(), option);
  }
  for (const key of [...Object.keys(decodedStreams), ...Object.keys(flvMap), ...Object.keys(hlsMap)]) {
    const text = key.trim();
    if (text && !descriptors.has(text.toLowerCase())) descriptors.set(text.toLowerCase(), { sdk_key: text });
  }

  const qualities: DouyinQuality[] = [];
  for (const [key, descriptor] of descriptors) {
    const urls: string[] = [];
    const stream = asStringMap(caseInsensitiveValue(decodedStreams, key));
    const main = asStringMap(stream?.['main']);
    if (main) {
      addPlayableUrl(urls, main['flv']);
      addPlayableUrl(urls, main['hls']);
    }
    addPlayableUrl(urls, caseInsensitiveValue(flvMap, key));
    addPlayableUrl(urls, caseInsensitiveValue(hlsMap, key));
    if (urls.length === 0) continue;
    if (isAudioOnlyVariant(key, urls)) continue;

    const configuredName = readText(descriptor['name']);
    const rawResolutionName = caseInsensitiveValue(resolutionNames, key);
    const resolutionName = readText(rawResolutionName);
    const sdkParams = decodeSdkParams(main?.['sdk_params']);
    const bitRate = Number(descriptor['v_bit_rate'] ?? NaN) || Number(sdkParams['vbitrate'] ?? NaN) || undefined;
    const resolution = readText(descriptor['resolution']) || readText(sdkParams['resolution']) || undefined;
    const level = Number(descriptor['level'] ?? 0) || 0;
    const knownRank = DOUYIN_QUALITY_RANK[key.toUpperCase()] ?? 0;
    const sort = knownRank > 0 ? knownRank : level > 0 ? level * 1_000_000 : bitRate ?? 0;

    qualities.push({
      id: key,
      label: normalizeQualityLabel(configuredName || resolutionName || key, key, resolution, bitRate),
      sort,
      urls,
    });
  }

  qualities.sort((left, right) => {
    const rank = right.sort - left.sort;
    return rank !== 0 ? rank : left.id.localeCompare(right.id);
  });

  // Legacy and modern keys can expose the same actual stream; show it once.
  const seenStreams = new Set<string>();
  return qualities.filter((quality) => {
    const fingerprint = [...quality.urls].sort().join('\u0000');
    if (seenStreams.has(fingerprint)) return false;
    seenStreams.add(fingerprint);
    return true;
  });
}

/* ------------------------------- room resolution ------------------------------ */

interface DouyinEnvelope {
  status_code?: number;
  data?: Record<string, unknown>;
}

/** Internal resolution: room metadata plus the stream_url envelope. */
interface DouyinResolution {
  info: LiveRoomInfo;
  streamUrl: unknown;
}

function roomStatusLive(room: Record<string, unknown>): boolean {
  return Number(room['status'] ?? 0) === 2;
}

function buildResolution(
  webRid: string,
  room: Record<string, unknown>,
  owner: Record<string, unknown> | null,
  fallbackNick: string,
): DouyinResolution {
  const live = roomStatusLive(room);
  const ownerNick = owner ? readText(owner['nickname']) : '';
  const avatarSource = owner ?? {};
  const firstUrl = (value: unknown): string => (Array.isArray(value) ? readText(value[0]) : '');
  const avatarList = asStringMap(avatarSource['avatar_thumb'])?.['url_list'];
  const coverList = asStringMap(room['cover'])?.['url_list'];
  const totalViewers = live ? douyinTotalViewers(room) : '';
  const onlineViewers = live ? douyinOnlineViewers(room) : '';
  const liveStatus: LiveStatusValue = live ? 'live' : 'offline';
  return {
    info: {
      platform: 'douyin',
      roomId: webRid,
      title: readText(room['title']),
      nick: ownerNick || fallbackNick,
      avatar: firstUrl(avatarList),
      cover: live ? firstUrl(coverList) : '',
      watching: totalViewers || onlineViewers,
      link: `https://live.douyin.com/${webRid}`,
      status: live,
      liveStatus,
    },
    streamUrl: live ? (room['stream_url'] ?? {}) : {},
  };
}

/** Port of _getRoomDetailByWebRidApi (webcast/room/web/enter). */
async function resolveByWebRidApi(webRid: string): Promise<DouyinResolution> {
  const url = buildSignedUrl('https://live.douyin.com/webcast/room/web/enter/', {
    app_name: 'douyin_web',
    enter_from: 'web_live',
    live_id: '1',
    web_rid: webRid,
    is_need_double_stream: 'false',
  });
  const result = await getJson<DouyinEnvelope>(url, { headers: await apiHeaders() });
  // Aligned with Dart: no status_code gate here — read data.data[0] directly
  // and let a missing room fall to the HTML path (douyin returns non-zero
  // status codes together with usable payloads in some states).
  const data = asStringMap(result?.data);
  const rooms = Array.isArray(data?.['data']) ? (data['data'] as unknown[]) : [];
  const room = asStringMap(rooms[0]);
  const user = asStringMap(data?.['user']);
  if (!room) {
    // Ended broadcasts leave the enter API with an empty room list but the
    // anchor profile intact; report an offline room instead of an error.
    if (user) return offlineRoomFromUser(webRid, user);
    throw roomNotFound(`douyin room ${webRid} not found`);
  }
  const owner = asStringMap(room['owner']);
  const fallbackNick = readText(user?.['nickname']);
  return buildResolution(webRid, room, owner, fallbackNick);
}

/** Offline room built from the anchor profile (enter API with no live room). */
function offlineRoomFromUser(webRid: string, user: Record<string, unknown>): DouyinResolution {
  const avatar = asStringMap(user['avatar_thumb']);
  const avatarList = Array.isArray(avatar?.['url_list']) ? (avatar['url_list'] as unknown[]) : [];
  return {
    info: {
      platform: 'douyin',
      roomId: webRid,
      title: '',
      nick: readText(user['nickname']),
      avatar: readText(avatarList[0]),
      cover: '',
      watching: '',
      link: `https://live.douyin.com/${webRid}`,
      status: false,
      liveStatus: 'offline',
    },
    streamUrl: {},
  };
}

/** Port of _getWebCookie + _getRoomDataByHtml (HTML fallback). */
async function resolveByWebRidHtml(webRid: string): Promise<DouyinResolution> {
  const base = {
    referer: DOUYIN_REFERER,
    'user-agent': DOUYIN_API_USER_AGENT,
  };
  const setCookies = await headSetCookies(`https://live.douyin.com/${webRid}`, { headers: base }).catch((error) => {
    // douyin answers 404 for room URLs that are gone; that is ROOM_NOT_FOUND,
    // not an upstream failure.
    if (upstreamStatusOf(error) === 404) throw roomNotFound(`douyin room ${webRid} not found`);
    throw error;
  });
  const pairs: string[] = [];
  for (const value of setCookies) {
    const pair = (value.split(';')[0] ?? '').trim();
    if (pair.startsWith('ttwid=') || pair.startsWith('__ac_nonce=') || pair.startsWith('msToken=')) {
      pairs.push(pair);
    }
  }
  const cookie = pairs.join('; ');

  const html = await getText(`https://live.douyin.com/${webRid}`, {
    headers: cookie ? { ...base, cookie } : base,
  }).catch((error) => {
    if (upstreamStatusOf(error) === 404) throw roomNotFound(`douyin room ${webRid} not found`);
    throw error;
  });
  const match = html.match(/\{\\"state\\":\{\\"appStore[\s\S]*?\]\\n/);
  if (!match) throw roomNotFound(`douyin room ${webRid} not found (page state missing)`);
  const str = match[0].trim().replaceAll('\\"', '"').replaceAll('\\\\', '\\').replaceAll(']\\n', '');
  let state: Record<string, unknown>;
  try {
    const parsed = JSON.parse(str) as Record<string, unknown>;
    state = asStringMap(parsed['state']) ?? {};
  } catch {
    throw upstreamError('douyin page state payload is malformed');
  }

  const roomStore = asStringMap(state['roomStore']) ?? {};
  const roomInfo = asStringMap(roomStore['roomInfo']) ?? {};
  const room = asStringMap(roomInfo['room']);
  if (!room) throw roomNotFound(`douyin room ${webRid} not found`);
  const owner = asStringMap(room['owner']);
  const anchor = asStringMap(roomInfo['anchor']);
  const fallbackNick = readText(anchor?.['nickname']);
  return buildResolution(webRid, room, owner, fallbackNick);
}

/** Port of getRoomDetailByWebRid: API first, HTML fallback second. */
async function resolveByWebRid(webRid: string): Promise<DouyinResolution> {
  try {
    return await resolveByWebRidApi(webRid);
  } catch {
    // API can reject anonymous sessions; fall through to the page-derived state.
    return resolveByWebRidHtml(webRid);
  }
}

/** Port of getRoomDetailByRoomId (webcast/room/reflow/info for long ids). */
async function resolveByRoomId(roomId: string): Promise<DouyinResolution> {
  const result = await getJson<DouyinEnvelope>('https://webcast.amemv.com/webcast/room/reflow/info/', {
    params: {
      type_id: '0',
      live_id: '1',
      room_id: roomId,
      sec_user_id: '',
      version_code: '99.99.99',
      app_id: AID,
    },
    headers: await apiHeaders(),
  });
  const data = asStringMap(result?.data);
  const room = asStringMap(data?.['room']);
  if (!room) throw roomNotFound(`douyin room ${roomId} not found`);
  const owner = asStringMap(room['owner']) ?? {};
  const webRid = readText(owner['web_rid']);

  // A 19-digit id is one-off per broadcast; when that session already ended
  // (status 4), re-resolve through the anchor's current webRid.
  if (Number(room['status'] ?? 0) === 4 && webRid) {
    return resolveByWebRid(webRid);
  }
  return buildResolution(webRid || roomId, room, owner, '');
}

/* --------------------------------- play URLs ---------------------------------- */

function protocolFromUrl(url: string): StreamProtocol {
  const path = new URL(url).pathname.toLowerCase();
  if (path.endsWith('.flv')) return 'flv';
  if (path.endsWith('.m3u8')) return 'hls';
  if (path.endsWith('.mp4')) return 'mp4';
  return 'unknown';
}

function computeExpireAt(urls: string[]): string {
  try {
    const first = urls[0];
    if (!first) throw new Error('no url');
    const query = new URL(first).searchParams;
    const expire = Number(query.get('expire') ?? query.get('expires') ?? 0);
    if (Number.isFinite(expire) && expire > Date.now() / 1000) {
      return new Date(expire * 1000).toISOString();
    }
  } catch {
    // fall through to the default window
  }
  return new Date(Date.now() + 30 * 60 * 1000).toISOString();
}

/* ---------------------------------- backend ----------------------------------- */

export class DouyinBackend implements ResolverBackend {
  readonly id = 'douyin';
  readonly name = 'Douyin';
  readonly capabilities = ['resolve', 'play-urls', 'qualities'] as const;

  /** Mirrors DouyinSite.getRoomDetail: id length decides webRid vs numeric path. */
  async resolveRoom(roomId: string): Promise<LiveRoomInfo> {
    if (roomId.length <= 16) return (await resolveByWebRid(roomId)).info;
    return (await resolveByRoomId(roomId)).info;
  }

  async getQualities(roomId: string): Promise<QualityInfo[]> {
    const resolution = roomId.length <= 16 ? await resolveByWebRid(roomId) : await resolveByRoomId(roomId);
    if (!resolution.info.status) return [];
    return parseStreamQualities(resolution.streamUrl).map((quality) => ({
      selectionId: quality.id,
      label: quality.label,
    }));
  }

  async getPlayUrls(roomId: string, quality?: string): Promise<PlayUrlsResult> {
    const resolution = roomId.length <= 16 ? await resolveByWebRid(roomId) : await resolveByRoomId(roomId);
    if (!resolution.info.status) {
      throw roomClosed(`douyin room ${roomId} is not live`);
    }

    const qualities = parseStreamQualities(resolution.streamUrl);
    if (qualities.length === 0) throw upstreamError('douyin returned no playable stream qualities');

    let chosen: DouyinQuality;
    if (quality === undefined || quality === '') {
      chosen = qualities[0] as DouyinQuality;
    } else {
      const normalized = quality.toLowerCase();
      const match =
        qualities.find((entry) => entry.id === normalized) ??
        qualities.find((entry) => entry.label === quality);
      if (!match) {
        throw badRequest(
          `unknown quality "${quality}"; available: ${qualities.map((entry) => entry.label).join(', ')}`,
        );
      }
      chosen = match;
    }

    return {
      platform: this.id,
      roomId,
      quality: chosen.label,
      protocol: protocolFromUrl(chosen.urls[0] as string),
      urls: chosen.urls,
      headers: playbackHeaders(roomId, await getCookie()),
      expireAt: computeExpireAt(chosen.urls),
      sourceQueryPolicies: {},
    };
  }

  cdnHostSuffixes(): readonly string[] {
    return [
      'douyincdn.com',
      'douyin.com',
      'amemv.com',
      'bytecdn.cn',
      'zjcdn.com',
      'bytedance.net',
      'bytedance.com',
      'douyinstatic.com',
      'douyinpic.com',
      'ibytedtos.com',
      'douyinus.net',
      'snssdk.com',
      'toutiaocdn.com',
    ];
  }
}
