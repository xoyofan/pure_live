/**
 * Danmaku source contract: the server proxies and normalizes platform chat
 * streams; upstream reconnection with backoff is owned by the source.
 * Frames match contracts/api.md section 5 (text frames, one JSON per frame).
 */

export type DanmakuFrame =
  | {
      type: 'chat';
      userName: string;
      userId: string;
      text: string;
      avatar: string;
      ts: string;
    }
  | {
      type: 'online';
      kind: 'popularity' | 'onlineViewers' | 'totalViewers';
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
      state: 'connecting' | 'connected' | 'reconnecting' | 'closed' | 'error';
      message?: string;
    }
  | { type: 'pong' };

export type DanmakuStatusState = Extract<DanmakuFrame, { type: 'status' }>['state'];

export interface DanmakuConnectOptions {
  roomId: string;
  /** Platform id; sources serving several platforms route on it. */
  platform?: string;
  onFrame(frame: DanmakuFrame): void;
}

export interface DanmakuSession {
  /** Stops the upstream connection and emits a final "closed" status. */
  close(): void;
}

export interface DanmakuSource {
  /**
   * Starts the upstream session immediately; early frames may arrive before
   * connect() returns. Never throws synchronously — upstream failures are
   * reported via "error"/"reconnecting" status frames and retried.
   */
  connect(options: DanmakuConnectOptions): DanmakuSession;
}

export function nowIso(): string {
  return new Date().toISOString();
}
