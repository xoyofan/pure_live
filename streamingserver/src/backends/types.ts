/**
 * ResolverBackend contract (contracts/api.md section 1): the server talks to
 * platforms only through this interface, so an M3 C++ addon backend can replace
 * the TS implementations without touching routes.
 */
import type { DanmakuSource } from '../danmaku/types.js';

export type LiveStatusValue = 'live' | 'offline' | 'replay' | 'banned' | 'unknown';

export type PlatformCapability = 'resolve' | 'play-urls' | 'qualities' | 'danmaku' | 'search' | 'directory';

/** Room metadata aligned with Flutter LiveRoom semantics (api.md 4.3). */
export interface LiveRoomInfo {
  platform: string;
  roomId: string;
  title: string;
  nick: string;
  avatar: string;
  cover: string;
  watching: string;
  link: string;
  status: boolean;
  liveStatus: LiveStatusValue;
}

export interface QualityInfo {
  /** Opaque id echoed back in POST /rooms/{platform}/play-urls "quality". */
  selectionId: string;
  /** Human-facing label. */
  label: string;
}

export type StreamProtocol = 'flv' | 'hls' | 'mp4' | 'unknown';

export interface PlayUrlsResult {
  platform: string;
  roomId: string;
  quality: string;
  protocol: StreamProtocol;
  urls: string[];
  headers: Record<string, string>;
  /** ISO-8601 UTC; when the resolved URLs stop being usable. */
  expireAt: string;
  sourceQueryPolicies: Record<string, unknown>;
}

/** Category tree node (api.md 4.6.1), mirroring Flutter LiveArea. */
export interface AreaInfo {
  platform: string | null;
  areaType: string | null;
  typeName: string | null;
  areaId: string | null;
  areaName: string | null;
  areaPic: string | null;
  shortName: string | null;
}

export interface CategoryInfo {
  id: string;
  name: string;
  children: AreaInfo[];
}

/** Paged room list shared by 4.6.2-4.6.4. */
export interface RoomListResult {
  page: number;
  hasMore: boolean;
  rooms: LiveRoomInfo[];
}

/** List query shared by the directory/search endpoints (page is 1-based). */
export interface ListQuery {
  page: number;
  pageSize: number;
}

export interface ResolverBackend {
  readonly id: string;
  readonly name: string;
  readonly capabilities: readonly PlatformCapability[];
  /** Real room metadata; offline rooms resolve with 200 + liveStatus "offline". */
  resolveRoom(roomId: string): Promise<LiveRoomInfo>;
  getQualities(roomId: string): Promise<QualityInfo[]>;
  getPlayUrls(roomId: string, quality?: string): Promise<PlayUrlsResult>;
  /** Static CDN host suffixes accepted by /proxy for this platform. */
  cdnHostSuffixes(): readonly string[];
  /** Directory/search capabilities (api.md 4.6); absent when unsupported. */
  getCategories?(query: ListQuery): Promise<CategoryInfo[]>;
  getRecommendRooms?(query: ListQuery): Promise<RoomListResult>;
  getCategoryRooms?(
    area: { areaId: string; areaType?: string; typeName?: string; areaName?: string },
    query: ListQuery,
  ): Promise<RoomListResult>;
  searchRooms?(keyword: string, query: ListQuery): Promise<RoomListResult>;
}

export interface RegisteredPlatform {
  id: string;
  name: string;
  capabilities: PlatformCapability[];
}

const RUNTIME_HOST_LIMIT = 512;

/**
 * Platform registry: maps platform id -> backend / danmaku source, and keeps a
 * bounded runtime cache of CDN hosts seen in real play-urls responses so the
 * /proxy allowlist is "derived from what the backends actually return".
 */
class Registry {
  private readonly backends = new Map<string, ResolverBackend>();
  private readonly danmakuSources = new Map<string, DanmakuSource>();
  private readonly runtimeHosts = new Set<string>();

  registerBackend(backend: ResolverBackend): void {
    this.backends.set(backend.id, backend);
  }

  registerDanmakuSource(platformId: string, source: DanmakuSource): void {
    this.danmakuSources.set(platformId, source);
  }

  getBackend(platformId: string): ResolverBackend | undefined {
    return this.backends.get(platformId);
  }

  getDanmakuSource(platformId: string): DanmakuSource | undefined {
    return this.danmakuSources.get(platformId);
  }

  hasDanmaku(platformId: string): boolean {
    return this.danmakuSources.has(platformId);
  }

  listPlatforms(): RegisteredPlatform[] {
    return [...this.backends.values()].map((backend) => ({
      id: backend.id,
      name: backend.name,
      capabilities: [...backend.capabilities],
    }));
  }

  /** Records hosts returned by a backend so /proxy can accept them. */
  notePlayUrlHosts(urls: readonly string[]): void {
    for (const url of urls) {
      try {
        const host = new URL(url).host;
        if (host) {
          if (this.runtimeHosts.size >= RUNTIME_HOST_LIMIT) return;
          this.runtimeHosts.add(host);
        }
      } catch {
        // not a parseable URL; ignore
      }
    }
  }

  /** True when hostname[:port] was returned by a backend or matches a static CDN suffix. */
  isAllowedProxyHost(hostWithPort: string): boolean {
    const normalized = hostWithPort.toLowerCase();
    if (this.runtimeHosts.has(normalized)) return true;
    const hostname = normalized.replace(/:\d+$/, '');
    if (this.runtimeHosts.has(hostname)) return true;
    for (const backend of this.backends.values()) {
      for (const suffix of backend.cdnHostSuffixes()) {
        if (hostname === suffix || hostname.endsWith(`.${suffix}`)) return true;
      }
    }
    return false;
  }
}

export const registry = new Registry();
