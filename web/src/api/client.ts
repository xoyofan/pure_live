import {
  ApiError,
  type ApiErrorCode,
  type Health,
  type PlayUrls,
  type PlayUrlsRequest,
  type Platform,
  type Quality,
  type ResolveRequest,
  type Room,
} from './types';

/** Same-origin base path; in dev the Vite proxy forwards /api -> 127.0.0.1:8787. */
export const API_BASE = '/api/v1';

/** Headers the browser cannot set on fetch/media requests -> must use /proxy. */
const RESTRICTED_HEADER_KEYS = ['user-agent', 'origin', 'referer', 'cookie'] as const;

function toApiError(code: unknown, message: unknown, httpStatus: number): ApiError {
  const knownCodes: ApiErrorCode[] = [
    'BAD_REQUEST',
    'UNAUTHORIZED',
    'PLATFORM_UNSUPPORTED',
    'ROOM_NOT_FOUND',
    'ROOM_CLOSED',
    'UPSTREAM_ERROR',
    'UPSTREAM_TIMEOUT',
    'INTERNAL',
  ];
  const validCode =
    typeof code === 'string' && (knownCodes as string[]).includes(code)
      ? (code as ApiErrorCode)
      : 'UNKNOWN';
  return new ApiError(
    validCode,
    typeof message === 'string' && message.length > 0 ? message : `请求失败 (HTTP ${httpStatus})`,
    httpStatus,
  );
}

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  let resp: Response;
  try {
    resp = await fetch(`${API_BASE}${path}`, {
      headers: { Accept: 'application/json', ...(init?.headers ?? {}) },
      ...init,
    });
  } catch {
    // fetch() rejects on network failure / DNS / refused connection.
    throw new ApiError('NETWORK', '无法连接解析服务,请确认解析服务已启动');
  }

  let body: unknown = null;
  const text = await resp.text();
  if (text.length > 0) {
    try {
      body = JSON.parse(text);
    } catch {
      if (resp.ok) throw new ApiError('PARSE', '服务端返回了无法解析的响应', resp.status);
    }
  }

  if (!resp.ok) {
    const errBody = (body as { error?: { code?: unknown; message?: unknown } } | null)?.error;
    if (errBody === undefined || errBody === null || typeof errBody !== 'object') {
      // No contract error shape: the failure came from transport itself
      // (server down -> dev proxy 500/504, gateway, etc.).
      throw new ApiError('NETWORK', '无法连接解析服务,请确认解析服务已启动', resp.status);
    }
    throw toApiError(errBody.code, errBody.message, resp.status);
  }

  return body as T;
}

// ---------------------------------------------------------------------------
// Endpoint wrappers (contract section 4, M1)
// ---------------------------------------------------------------------------

/** GET /health */
export function getHealth(): Promise<Health> {
  return request<Health>('/health');
}

/** GET /platforms */
export function getPlatforms(): Promise<{ platforms: Platform[] }> {
  return request<{ platforms: Platform[] }>('/platforms');
}

/** POST /rooms/{platform}/resolve */
export function resolveRoom(platform: string, roomId: string): Promise<{ room: Room }> {
  return request<{ room: Room }>(`/rooms/${encodeURIComponent(platform)}/resolve`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ roomId } satisfies ResolveRequest),
  });
}

/** GET /rooms/{platform}/qualities?roomId= */
export function getQualities(platform: string, roomId: string): Promise<{ qualities: Quality[] }> {
  const query = new URLSearchParams({ roomId });
  return request<{ qualities: Quality[] }>(
    `/rooms/${encodeURIComponent(platform)}/qualities?${query.toString()}`,
  );
}

/** POST /rooms/{platform}/play-urls */
export function getPlayUrls(
  platform: string,
  req: PlayUrlsRequest,
): Promise<PlayUrls> {
  return request<PlayUrls>(`/rooms/${encodeURIComponent(platform)}/play-urls`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(req),
  });
}

// ---------------------------------------------------------------------------
// Playback proxy (contract 4.7)
// ---------------------------------------------------------------------------

/** True if any of user-agent/origin/referer/cookie is non-empty. */
export function needsProxy(headers: Record<string, string> | null | undefined): boolean {
  if (!headers) return false;
  return RESTRICTED_HEADER_KEYS.some((key) => (headers[key] ?? '').trim().length > 0);
}

function base64url(input: string): string {
  const bytes = new TextEncoder().encode(input);
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/**
 * GET /api/v1/proxy?u=<encodeURIComponent(url)>&h=<base64url(JSON headers)>
 * The server attaches the headers in `h` while pulling from the upstream CDN.
 */
export function buildProxyUrl(url: string, headers: Record<string, string>): string {
  const filtered: Record<string, string> = {};
  for (const [key, value] of Object.entries(headers)) {
    if (typeof value === 'string' && value.length > 0) filtered[key] = value;
  }
  const query = new URLSearchParams({
    u: url,
    h: base64url(JSON.stringify(filtered)),
  });
  return `${API_BASE}/proxy?${query.toString()}`;
}

/**
 * Resolve the URL a media element should load: through /proxy when the
 * upstream requires browser-restricted headers, otherwise direct.
 */
export function toPlaybackUrl(play: {
  urls: string[];
  headers: Record<string, string>;
}): string | null {
  const url = play.urls[0];
  if (!url) return null;
  return needsProxy(play.headers) ? buildProxyUrl(url, play.headers) : url;
}
