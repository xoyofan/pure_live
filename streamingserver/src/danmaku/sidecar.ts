/**
 * Danmaku served by the Dart sidecar (douyin/huya/douyu): the SAME lib/core
 * implementations the Flutter app uses (handshakes, signatures and protobuf
 * decoding stay single-source). The sidecar pushes
 * {"push":"danmaku","roomId","frame"} envelopes on stdout; this source fans
 * them out to every WS client attached to that room and refcounts sessions.
 */
import type { SidecarProcess } from '../backends/dart_sidecar.js';
import type {
  DanmakuConnectOptions,
  DanmakuFrame,
  DanmakuSession,
  DanmakuSource,
} from './types.js';

interface SidecarChatFrame {
  type: 'chat';
  userName?: string;
  userId?: string;
  text?: string;
  ts?: string;
}

interface SidecarOnlineFrame {
  type: 'online';
  kind?: string;
  value?: number;
  ts?: string;
}

interface SidecarStatusFrame {
  type: 'status';
  state?: string;
  message?: string;
}

type SidecarFrame = SidecarChatFrame | SidecarOnlineFrame | SidecarStatusFrame | Record<string, unknown>;

const STATUSES = new Set(['connecting', 'connected', 'reconnecting', 'closed', 'error']);

export class SidecarPushDanmakuSource implements DanmakuSource {
  private readonly listeners = new Map<string, Set<DanmakuConnectOptions['onFrame']>>();

  constructor(
    private readonly sidecar: SidecarProcess,
    private readonly platforms: readonly string[],
  ) {
    sidecar.onDanmakuPush = (platform, roomId, frame) => this.dispatch(platform, roomId, frame);
    sidecar.onExit = () => {
      for (const [key, frames] of this.listeners) {
        for (const onFrame of frames) {
          onFrame({ type: 'status', state: 'error', message: 'sidecar process exited' });
        }
        this.listeners.delete(key);
      }
    };
  }

  connect(options: DanmakuConnectOptions): DanmakuSession {
    const platform = options.platform ?? this.platforms[0];
    const key = `${platform}:${options.roomId}`;
    let listeners = this.listeners.get(key);
    const first = listeners === undefined || listeners.size === 0;
    listeners ??= new Set();
    listeners.add(options.onFrame);
    this.listeners.set(key, listeners);

    if (first) {
      this.sidecar
        .call('danmakuStart', { platform, roomId: options.roomId })
        .catch((error: unknown) => {
          // Only report when nobody re-attached in the meantime.
          if (this.listeners.get(key)?.has(options.onFrame)) {
            options.onFrame({
              type: 'status',
              state: 'error',
              message: error instanceof Error ? error.message : 'danmaku start failed',
            });
          }
        });
    } else {
      // Late joiner: tell the client the shared upstream is already live.
      options.onFrame({ type: 'status', state: 'connecting' });
    }

    return {
      close: () => {
        const set = this.listeners.get(key);
        if (!set) return;
        set.delete(options.onFrame);
        if (set.size === 0) {
          this.listeners.delete(key);
          void this.sidecar
            .call('danmakuStop', { platform, roomId: options.roomId })
            .catch(() => {});
        }
      },
    };
  }

  private dispatch(platform: string, roomId: string, raw: SidecarFrame): void {
    const set = this.listeners.get(`${platform}:${roomId}`);
    if (!set || set.size === 0) return;
    const frame = this.normalize(raw);
    if (frame === null) return;
    for (const onFrame of set) onFrame(frame);
  }

  private normalize(raw: SidecarFrame): DanmakuFrame | null {
    if (typeof raw !== 'object' || raw === null) return null;
    const type = (raw as { type?: unknown }).type;
    if (type === 'chat') {
      const frame = raw as SidecarChatFrame;
      const text = typeof frame.text === 'string' ? frame.text : '';
      if (text.length === 0) return null;
      return {
        type: 'chat',
        userName: typeof frame.userName === 'string' && frame.userName ? frame.userName : '用户',
        userId: typeof frame.userId === 'string' ? frame.userId : '',
        text,
        avatar: '',
        ts: typeof frame.ts === 'string' ? frame.ts : new Date().toISOString(),
      };
    }
    if (type === 'online') {
      const frame = raw as SidecarOnlineFrame;
      const value = typeof frame.value === 'number' && Number.isFinite(frame.value) ? frame.value : null;
      if (value === null) return null;
      const kind = frame.kind === 'totalViewers' ? 'totalViewers' : frame.kind === 'popularity' ? 'popularity' : 'onlineViewers';
      return {
        type: 'online',
        kind,
        value,
        ts: typeof frame.ts === 'string' ? frame.ts : new Date().toISOString(),
      };
    }
    if (type === 'status') {
      const frame = raw as SidecarStatusFrame;
      const state = typeof frame.state === 'string' && STATUSES.has(frame.state)
        ? (frame.state as 'connecting' | 'connected' | 'reconnecting' | 'closed' | 'error')
        : 'reconnecting';
      return {
        type: 'status',
        state,
        ...(typeof frame.message === 'string' && frame.message ? { message: frame.message } : {}),
      };
    }
    return null;
  }
}
