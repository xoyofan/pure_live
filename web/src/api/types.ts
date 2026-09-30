// Types mirroring D:\pure_live\contracts\api.md (契约 v1) exactly.
// REST base: /api/v1 ; all roomId/userId are strings.

/** Platform id string, e.g. "bilibili" | "douyin" (M1); more in M2. */
export type PlatformId = string;

export type LiveStatus = 'live' | 'offline' | 'replay' | 'banned' | 'unknown';

export type Capability =
  | 'resolve'
  | 'play-urls'
  | 'qualities'
  | 'danmaku'
  | 'search'
  | 'directory';

/** GET /platforms */
export interface Platform {
  id: PlatformId;
  name: string;
  capabilities: Capability[];
}

/** GET /health */
export interface Health {
  ok: boolean;
  version: string;
  platforms: string[];
  uptimeSec: number;
}

/** POST /rooms/{platform}/resolve -> { room } */
export interface Room {
  platform: PlatformId;
  roomId: string;
  title: string;
  nick: string;
  avatar: string;
  cover: string;
  watching: string;
  link: string;
  status: boolean;
  liveStatus: LiveStatus;
}

/** GET /rooms/{platform}/qualities?roomId= */
export interface Quality {
  selectionId: string;
  label: string;
}

/** protocol of the resolved playback stream */
export type Protocol = 'flv' | 'hls' | 'mp4' | 'unknown';

/**
 * POST /rooms/{platform}/play-urls
 * headers: request headers the upstream CDN requires; the browser cannot set
 * user-agent/origin/referer/cookie, so constrained streams must go through
 * GET /proxy (see client.buildProxyUrl).
 */
export interface PlayUrls {
  platform: PlatformId;
  roomId: string;
  quality: string;
  protocol: Protocol;
  urls: string[];
  headers: Record<string, string>;
  /** ISO-8601 UTC */
  expireAt: string;
  sourceQueryPolicies: Record<string, unknown>;
}

/** POST /rooms/{platform}/resolve request body */
export interface ResolveRequest {
  roomId: string;
}

/** Category leaf (api.md 4.6.1), mirroring Flutter LiveArea. */
export interface AreaItem {
  platform: string | null;
  areaType: string | null;
  typeName: string | null;
  areaId: string | null;
  areaName: string | null;
  areaPic: string | null;
  shortName: string | null;
}

/** GET /directory/{platform}/categories */
export interface Category {
  id: string;
  name: string;
  children: AreaItem[];
}

/** Slim room entry of every 4.6 list (subset of Room). */
export type RoomListItem = Room;

/** Paged list shared by recommend / category rooms / search (api.md 4.6). */
export interface RoomListResult {
  page: number;
  hasMore: boolean;
  rooms: RoomListItem[];
}

/** POST /rooms/{platform}/play-urls request body */
export interface PlayUrlsRequest {
  roomId: string;
  /** omit for platform default quality */
  quality?: string;
  withHeaders: boolean;
}

// ---------------------------------------------------------------------------
// Danmaku WebSocket frames (text, one JSON object per frame)
// ---------------------------------------------------------------------------

export type DanmakuOnlineKind = 'popularity' | 'onlineViewers' | 'totalViewers';

export type DanmakuConnectionState =
  | 'connecting'
  | 'connected'
  | 'reconnecting'
  | 'closed'
  | 'error';

export type DanmakuFrame =
  | {
      type: 'chat';
      userName: string;
      userId: string;
      text: string;
      avatar?: string;
      /** ISO-8601 UTC */
      ts: string;
    }
  | {
      type: 'online';
      kind: DanmakuOnlineKind;
      value: number;
      ts: string;
    }
  | {
      type: 'superChat';
      userName: string;
      userId: string;
      text: string;
      price: number;
      ts: string;
    }
  | {
      type: 'gift';
      userName: string;
      userId: string;
      giftName: string;
      count: number;
      ts: string;
    }
  | {
      type: 'status';
      state: DanmakuConnectionState;
      message?: string;
    }
  | {
      type: 'pong';
    };

/** Client -> server keepalive frame (every 30s). */
export interface DanmakuPingFrame {
  type: 'ping';
}

// ---------------------------------------------------------------------------
// Errors: non-2xx is always {"error": {"code": "...", "message": "..."}}
// ---------------------------------------------------------------------------

/** Error codes from the contract, plus client-side codes for transport failures. */
export type ApiErrorCode =
  | 'BAD_REQUEST'
  | 'UNAUTHORIZED'
  | 'PLATFORM_UNSUPPORTED'
  | 'ROOM_NOT_FOUND'
  | 'ROOM_CLOSED'
  | 'UPSTREAM_ERROR'
  | 'UPSTREAM_TIMEOUT'
  | 'INTERNAL'
  // client-side (not from the contract; transport/parse failures)
  | 'NETWORK'
  | 'PARSE'
  | 'UNKNOWN';

export class ApiError extends Error {
  readonly code: ApiErrorCode;
  /** HTTP status; null for transport-level failures (NETWORK). */
  readonly httpStatus: number | null;

  constructor(code: ApiErrorCode, message: string, httpStatus: number | null = null) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.httpStatus = httpStatus;
  }
}

export function isApiError(value: unknown): value is ApiError {
  return value instanceof ApiError;
}
