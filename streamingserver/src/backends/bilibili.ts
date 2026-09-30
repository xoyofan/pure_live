/**
 * BiliBili ResolverBackend — port of lib/core/site/bilibili/bilibili_site.dart
 * (room detail, WBI signing, buvid cookies, qualities, play URLs) and the
 * bilibili branch of lib/core/common/playback_header_resolver.dart.
 */
import { createHash } from 'node:crypto';
import { getJson } from '../http.js';
import { badRequest, roomClosed, roomNotFound, upstreamError } from '../errors.js';

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
export function playbackHeaders(roomId: string): Record<string, string> {
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

/** CDN host suffixes accepted by /proxy for bilibili streams. */
export function bilibiliCdnHostSuffixes(): readonly string[] {
  // smtcdns.net is Tencent HTTPDNS CNAME that bilivideo hosts resolve to.
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