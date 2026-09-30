/**
 * Douyin ResolverBackend — port of lib/core/site/douyin/douyin_site.dart,
 * lib/core/utils/douyin/douyin_utils.dart (a_bogus-signed request URLs) and
 * the douyin branch of lib/core/common/playback_header_resolver.dart.
 */
import { getJson, getText, getTextWithCookies, headSetCookies, upstreamStatusOf } from '../http.js';
import { badRequest, roomClosed, roomNotFound, upstreamError } from '../errors.js';

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

export async function getCookie(): Promise<string> {
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
export function playbackHeaders(roomId: string, cookie: string): Record<string, string> {
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
/** CDN host suffixes accepted by /proxy for douyin streams. */
export function douyinCdnHostSuffixes(): readonly string[] {
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