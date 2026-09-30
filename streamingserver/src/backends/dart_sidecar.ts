/**
 * DartSidecarBackend — resolution executed by the SAME lib/core Dart sources
 * the Flutter app uses, compiled to a standalone exe (`tool/sidecar/runner`),
 * talking line-JSON over stdio. This replaces the TS re-implementations for
 * the platforms it covers; playback headers stay in TS until the header
 * resolver moves through the sidecar too.
 */
import { spawn, type ChildProcess } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { ApiError, roomClosed, upstreamError } from '../errors.js';
import type {
  CategoryInfo,
  LiveRoomInfo,
  ListQuery,
  PlayUrlsResult,
  QualityInfo,
  ResolverBackend,
  RoomListResult,
} from './types.js';
import { bilibiliCdnHostSuffixes, playbackHeaders as bilibiliPlaybackHeaders } from './bilibili.js';
import { douyinCdnHostSuffixes, getCookie, playbackHeaders as douyinPlaybackHeaders } from './douyin.js';

interface SidecarCall {
  resolve: (value: unknown) => void;
  reject: (error: Error) => void;
  timer: NodeJS.Timeout;
}

export class SidecarProcess {
  private proc: ChildProcess | null = null;
  private nextId = 1;
  private readonly pending = new Map<number, SidecarCall>();
  private buffer = '';
  private starting: Promise<void> | null = null;

  /** Receives {"push":"danmaku"} stdout envelopes (see danmaku/douyin.ts). */
  onDanmakuPush: ((roomId: string, frame: Record<string, unknown>) => void) | null = null;
  /** Fires when the sidecar process dies (sessions must surface an error). */
  onExit: (() => void) | null = null;

  constructor(private readonly exePath: string) {}

  private async ensureStarted(): Promise<void> {
    if (this.proc && this.proc.exitCode === null) return;
    if (this.starting) return this.starting;
    this.starting = this.spawn();
    return this.starting;
  }

  private async spawn(): Promise<void> {
    const proc = spawn(this.exePath, [], { stdio: ['pipe', 'pipe', 'inherit'] });
    this.proc = proc;
    this.buffer = '';
    let started = false;

    const startup = new Promise<void>((resolveStartup, rejectStartup) => {
      const fail = (reason: string) => {
        if (!started) rejectStartup(new Error(reason));
      };
      proc.on('error', (error) => fail(`sidecar spawn failed: ${error.message}`));
      proc.on('exit', (code) => {
        this.proc = null;
        this.onExit?.();
        for (const call of this.pending.values()) {
          call.reject(upstreamError(`sidecar exited (code ${code})`));
          clearTimeout(call.timer);
        }
        this.pending.clear();
        fail(`sidecar exited during startup (code ${code})`);
      });
      proc.stdout.setEncoding('utf8');
      proc.stdout.on('data', (chunk: string) => {
        this.buffer += chunk;
        let newline: number;
        while ((newline = this.buffer.indexOf('\n')) !== -1) {
          const line = this.buffer.slice(0, newline).trim();
          this.buffer = this.buffer.slice(newline + 1);
          if (!line) continue;
          if (!started) {
            // First line is the ready banner.
            try {
              const banner = JSON.parse(line) as { started?: boolean };
              if (banner.started) {
                started = true;
                resolveStartup();
                continue;
              }
            } catch {
              /* fall through to normal handling */
            }
          }
          this.handleLine(line);
        }
      });
    });

    await startup;
    this.starting = null;
  }

  private handleLine(line: string): void {
    let message: {
      id?: number;
      ok?: boolean;
      result?: unknown;
      error?: { code?: string; message?: string };
      push?: string;
      roomId?: string;
      frame?: Record<string, unknown>;
    };
    try {
      message = JSON.parse(line);
    } catch {
      return; // Non-JSON stdout noise is ignored.
    }
    // Unsolicited push envelope from the sidecar (e.g. danmaku frames).
    if (message.push === 'danmaku' && typeof message.roomId === 'string') {
      this.onDanmakuPush?.(message.roomId, message.frame ?? {});
      return;
    }
    if (typeof message.id !== 'number') return;
    const call = this.pending.get(message.id);
    if (!call) return;
    this.pending.delete(message.id);
    clearTimeout(call.timer);
    if (message.ok) {
      call.resolve(message.result);
    } else {
      const code = message.error?.code ?? 'UPSTREAM_ERROR';
      call.reject(new ApiError(code === 'ROOM_CLOSED' ? 410 : code === 'PLATFORM_UNSUPPORTED' ? 404 : 502, code as never, message.error?.message ?? 'sidecar error'));
    }
  }

  // Transport budget only — the sidecar runs Flutter's exact parsing stack
  // (lib/core HttpClient: 20s connect/receive/send per upstream request).
  // A resolution chains at most three upstream requests, so the worst-case
  // Flutter-original budget is 3 x 20s; no parsing parameter is altered here.
  call<T>(method: string, params: Record<string, unknown>, timeoutMs = 60_000): Promise<T> {
    return this.ensureStarted().then(
      () =>
        new Promise<T>((resolvePromise, rejectPromise) => {
          const id = this.nextId++;
          const timer = setTimeout(() => {
            this.pending.delete(id);
            rejectPromise(upstreamError(`sidecar call ${method} timed out`));
          }, timeoutMs);
          this.pending.set(id, {
            resolve: resolvePromise as (value: unknown) => void,
            reject: rejectPromise,
            timer,
          });
          this.proc?.stdin?.write(`${JSON.stringify({ id, method, params })}\n`);
        }),
    );
  }

  dispose(): void {
    this.proc?.kill();
    this.proc = null;
  }
}

interface SidecarRoom {
  platform: string;
  roomId: string;
  title: string;
  nick: string;
  avatar: string;
  cover: string;
  watching: string;
  link: string;
  status: boolean;
  liveStatus: 'live' | 'offline' | 'replay' | 'banned' | 'unknown';
}

interface SidecarPlayUrls {
  quality: string;
  qualityId: string;
  urls: string[];
}

const protocolFromUrl = (url: string): 'flv' | 'hls' | 'mp4' | 'unknown' => {
  const clean = (url.split('?')[0] ?? url).toLowerCase();
  if (clean.endsWith('.flv')) return 'flv';
  if (clean.endsWith('.m3u8')) return 'hls';
  if (clean.endsWith('.mp4')) return 'mp4';
  return 'unknown';
};

const computeExpireAt = (urls: string[]): string => {
  const now = Date.now();
  for (const url of urls) {
    const match = url.match(/(?:expire|expires|wsTime)=(\d{10})/);
    if (match) return new Date(Number(match[1]) * 1000).toISOString();
  }
  return new Date(now + 10 * 60 * 1000).toISOString();
};

const CDN_SUFFIXES: Record<string, readonly string[]> = {
  douyin: douyinCdnHostSuffixes(),
  bilibili: bilibiliCdnHostSuffixes(),
  // huya signed URLs 302 onto third-party edges (ByteDance CDN observed in
  // practice); keep the known families on the /proxy allowlist.
  huya: ['huya.com', 'bytefcdnrd.com', 'huyacdn.com', 'hifihuya.com', 'msstatic.com'],
  douyu: ['douyucdn.cn', 'douyucdn2.cn', 'douyu.com'],
};

const PLATFORM_NAMES: Record<string, string> = {
  douyin: 'Douyin',
  bilibili: 'BiliBili',
  huya: 'Huya',
  douyu: 'Douyu',
};

// huya: the app falls back to the bundled hysdk UA when the refreshed signer
// UA is unavailable (lib/core/site/huya/huya_request_params.dart:18).
const HUYA_DEFAULT_UA =
  'HYSDK(Windows,30000002)_APP(pc_exe&7090000&official)_SDK(trans&2.35.0.5996)';

// douyu: mirrors DouyuUtils.userAgent + cookieHeader() with the deterministic
// defaultDeviceId (the app uses a random per-session did when none is stored).
const DOUYU_UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36';
const DOUYU_DEFAULT_DID = '10000000000000000000000000001501';

const HEADER_POLICY: Record<string, (roomId: string) => Promise<Record<string, string>>> = {
  douyin: async (roomId) => douyinPlaybackHeaders(roomId, await getCookie().catch(() => '')),
  bilibili: async () => bilibiliPlaybackHeaders(''),
  huya: async (roomId) => ({
    'user-agent': process.env.PARSER_HUYA_UA ?? HUYA_DEFAULT_UA,
    origin: 'https://www.huya.com',
    referer: roomId ? `https://www.huya.com/${roomId}` : 'https://www.huya.com/',
    ...(process.env.PARSER_HUYA_COOKIE ? { cookie: process.env.PARSER_HUYA_COOKIE } : {}),
  }),
  douyu: async (roomId) => {
    const cookie = (process.env.PARSER_DOUYU_COOKIE ?? '').trim();
    return {
      origin: 'https://www.douyu.com',
      referer: roomId ? `https://www.douyu.com/${roomId}` : 'https://www.douyu.com/',
      'user-agent': DOUYU_UA,
      cookie: `dy_did=${DOUYU_DEFAULT_DID}; acf_did=${DOUYU_DEFAULT_DID}${cookie ? `; ${cookie}` : ''}`,
    };
  },
};

/** Builds sidecar-backed implementations for the given platforms. */
export function createDartSidecarBackends(platforms: readonly string[]): SidecarRegistration | null {
  const exePath = process.env.PARSER_SIDECAR_PATH ?? DEFAULT_SIDECAR_PATH;
  if (!existsSync(exePath)) return null;

  const sidecar = new SidecarProcess(exePath);
  // Warm the process (spawn + banner) so the first real request pays only
  // its own upstream cost.
  void sidecar.call('health', {}).catch(() => {});

  const backends = platforms
    .filter((platform) => PLATFORM_NAMES[platform])
    .map(
      (platform) =>
        new DartSidecarPlatformBackend(
          platform,
          PLATFORM_NAMES[platform] ?? platform,
          sidecar,
          HEADER_POLICY[platform] ?? (async () => ({})),
        ),
    );
  if (backends.length === 0) return null;
  return { process: sidecar, backends };
}

/** Wraps one sidecar platform; playback headers stay a host-side policy. */
class DartSidecarPlatformBackend implements ResolverBackend {
  constructor(
    readonly id: string,
    readonly name: string,
    private readonly sidecar: SidecarProcess,
    private readonly headersFor: (roomId: string) => Promise<Record<string, string>>,
    readonly capabilities: readonly import('./types.js').PlatformCapability[] = [
      'resolve',
      'play-urls',
      'qualities',
      'search',
      'directory',
    ],
  ) {}

  async resolveRoom(roomId: string): Promise<LiveRoomInfo> {
    const result = await this.sidecar.call<{ room: SidecarRoom }>('resolve', { platform: this.id, roomId });
    return result.room;
  }

  async getQualities(roomId: string): Promise<QualityInfo[]> {
    const result = await this.sidecar.call<{ qualities: QualityInfo[] }>('qualities', { platform: this.id, roomId });
    return result.qualities ?? [];
  }

  async getPlayUrls(roomId: string, quality?: string): Promise<PlayUrlsResult> {
    const result = await this.sidecar.call<SidecarPlayUrls>('playUrls', {
      platform: this.id,
      roomId,
      ...(quality !== undefined && quality !== '' ? { quality } : {}),
    });
    if (!result.urls?.length) {
      throw roomClosed(`${this.id} room ${roomId} has no playable urls`);
    }
    return {
      platform: this.id,
      roomId,
      quality: result.quality,
      protocol: protocolFromUrl(result.urls[0] ?? ''),
      urls: result.urls,
      headers: await this.headersFor(roomId),
      expireAt: computeExpireAt(result.urls),
      sourceQueryPolicies: {},
    };
  }

  async getCategories(query: ListQuery): Promise<CategoryInfo[]> {
    const result = await this.sidecar.call<{ categories: CategoryInfo[] }>('categories', {
      platform: this.id,
      ...query,
    });
    return result.categories ?? [];
  }

  async getRecommendRooms(query: ListQuery): Promise<RoomListResult> {
    const result = await this.sidecar.call<RoomListResult>('recommendRooms', { platform: this.id, ...query });
    return { page: result.page, hasMore: result.hasMore, rooms: result.rooms ?? [] };
  }

  async getCategoryRooms(
    area: { areaId: string; areaType?: string; typeName?: string; areaName?: string },
    query: ListQuery,
  ): Promise<RoomListResult> {
    const result = await this.sidecar.call<RoomListResult>('categoryRooms', {
      platform: this.id,
      ...area,
      ...query,
    });
    return { page: result.page, hasMore: result.hasMore, rooms: result.rooms ?? [] };
  }

  async searchRooms(keyword: string, query: ListQuery): Promise<RoomListResult> {
    const result = await this.sidecar.call<RoomListResult>('searchRooms', {
      platform: this.id,
      keyword,
      ...query,
    });
    return { page: result.page, hasMore: result.hasMore, rooms: result.rooms ?? [] };
  }

  cdnHostSuffixes(): readonly string[] {
    return CDN_SUFFIXES[this.id] ?? [];
  }
}

export interface SidecarRegistration {
  process: SidecarProcess;
  backends: DartSidecarPlatformBackend[];
}

const DEFAULT_SIDECAR_PATH = fileURLToPath(new URL('../../../build/sidecar/pure-live-sidecar.exe', import.meta.url));

/**
 * Builds sidecar-backed implementations for the given platforms when the exe
 * exists (build via tool/sidecar). Returns null when missing, leaving the
 * registry without resolution for those platforms.
 */
