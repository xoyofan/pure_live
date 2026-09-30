import { useEffect, useRef, useState } from 'react';
import type { MutableRefObject } from 'react';
import type { DanmakuConnectionState } from '../api/types';

/** A chat message ready for the canvas overlay to render. */
export interface DanmakuChatItem {
  userName: string;
  text: string;
}

/**
 * Undrained chat backlog cap: if the canvas consumes slower than messages
 * arrive (e.g. hidden tab), drop the oldest and keep the newest so memory
 * and the render burst stay bounded.
 */
const BACKLOG_CAP = 200;

const PING_INTERVAL_MS = 30_000;
const BACKOFF_BASE_MS = 1_000;
const BACKOFF_MAX_MS = 30_000;
/** A socket that stayed open this long counts as healthy -> reset backoff. */
const STABLE_OPEN_MS = 5_000;

export interface DanmakuHandle {
  /** Connection status; server `status` frames take precedence over local state. */
  status: DanmakuConnectionState | 'idle';
  statusMessage: string | null;
  /** Latest online/popularity value from `online` frames, if any. */
  onlineValue: number | null;
  /** Queue the canvas drains; capped at BACKLOG_CAP (oldest dropped). */
  chatQueueRef: MutableRefObject<DanmakuChatItem[]>;
  /** Bounded recent-chat mirror for side-panel list rendering. */
  chatList: DanmakuChatItem[];
}

/** Side-panel list cap; older entries drop off the head. */
const CHAT_LIST_CAP = 60;

/**
 * Consume the danmaku WebSocket
 *   ws(s)://<same host>/api/v1/danmaku/stream?platform=...&roomId=...
 * with client-side exponential backoff reconnect (1s -> max 30s) and a 30s
 * ping keepalive, per contract section 5.
 */
export function useDanmaku(
  platform: string | null,
  roomId: string | null,
): DanmakuHandle {
  const [status, setStatus] = useState<DanmakuConnectionState | 'idle'>('idle');
  const [statusMessage, setStatusMessage] = useState<string | null>(null);
  const [onlineValue, setOnlineValue] = useState<number | null>(null);
  const [chatList, setChatList] = useState<DanmakuChatItem[]>([]);
  const chatQueueRef = useRef<DanmakuChatItem[]>([]);

  useEffect(() => {
    if (!platform || !roomId) {
      setStatus('idle');
      setStatusMessage(null);
      setOnlineValue(null);
      setChatList([]);
      chatQueueRef.current = [];
      return;
    }

    let disposed = false;
    let socket: WebSocket | null = null;
    let reconnectTimer: number | null = null;
    let pingTimer: number | null = null;
    let stableTimer: number | null = null;
    let attempt = 0;

    const proto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const url = `${proto}//${window.location.host}/api/v1/danmaku/stream?platform=${encodeURIComponent(platform)}&roomId=${encodeURIComponent(roomId)}`;

    const stopTimers = () => {
      if (pingTimer !== null) {
        window.clearInterval(pingTimer);
        pingTimer = null;
      }
      if (stableTimer !== null) {
        window.clearTimeout(stableTimer);
        stableTimer = null;
      }
    };

    const clearReconnectTimer = () => {
      if (reconnectTimer !== null) {
        window.clearTimeout(reconnectTimer);
        reconnectTimer = null;
      }
    };

    const scheduleReconnect = () => {
      if (disposed) return;
      const delay = Math.min(BACKOFF_BASE_MS * 2 ** attempt, BACKOFF_MAX_MS);
      attempt += 1;
      setStatus('reconnecting');
      clearReconnectTimer();
      reconnectTimer = window.setTimeout(connect, delay);
    };

    const connect = () => {
      if (disposed) return;
      setStatus((prev) => (prev === 'reconnecting' ? 'reconnecting' : 'connecting'));
      try {
        socket = new WebSocket(url);
      } catch {
        scheduleReconnect();
        return;
      }

      socket.onopen = () => {
        if (disposed) {
          socket?.close();
          return;
        }
        // Keepalive ping every 30s; the server drops idle clients after 60s.
        stopTimers();
        pingTimer = window.setInterval(() => {
          if (socket && socket.readyState === WebSocket.OPEN) {
            socket.send(JSON.stringify({ type: 'ping' }));
          }
        }, PING_INTERVAL_MS);
        // Reset the backoff once the connection proved stable.
        stableTimer = window.setTimeout(() => {
          attempt = 0;
        }, STABLE_OPEN_MS);
      };

      socket.onmessage = (event) => {
        if (disposed || typeof event.data !== 'string') return;
        let frame: unknown;
        try {
          frame = JSON.parse(event.data);
        } catch {
          return;
        }
        if (typeof frame !== 'object' || frame === null) return;
        const msg = frame as Record<string, unknown>;
        switch (msg.type) {
          case 'chat': {
            const userName = typeof msg.userName === 'string' ? msg.userName : '用户';
            const text = typeof msg.text === 'string' ? msg.text : '';
            if (text.length === 0) return;
            const item = { userName, text };
            const queue = chatQueueRef.current;
            queue.push(item);
            if (queue.length > BACKLOG_CAP) {
              queue.splice(0, queue.length - BACKLOG_CAP);
            }
            setChatList((prev) => {
              const next = [...prev, item];
              return next.length > CHAT_LIST_CAP ? next.slice(next.length - CHAT_LIST_CAP) : next;
            });
            break;
          }
          case 'online': {
            const value = typeof msg.value === 'number' && Number.isFinite(msg.value) ? msg.value : null;
            if (value !== null) setOnlineValue(value);
            break;
          }
          case 'status': {
            const state = msg.state;
            if (
              state === 'connecting' ||
              state === 'connected' ||
              state === 'reconnecting' ||
              state === 'closed' ||
              state === 'error'
            ) {
              setStatus(state);
              setStatusMessage(typeof msg.message === 'string' ? msg.message : null);
            }
            break;
          }
          case 'superChat':
          case 'gift':
          case 'pong':
          default:
            // M1 renders chat only; gift/superChat frames are accepted and ignored.
            break;
        }
      };

      socket.onclose = () => {
        stopTimers();
        socket = null;
        if (!disposed) scheduleReconnect();
      };

      socket.onerror = () => {
        // onclose always follows onerror; reconnection is handled there.
      };
    };

    connect();

    return () => {
      disposed = true;
      clearReconnectTimer();
      stopTimers();
      if (socket) {
        socket.onopen = null;
        socket.onmessage = null;
        socket.onclose = null;
        socket.onerror = null;
        if (
          socket.readyState === WebSocket.OPEN ||
          socket.readyState === WebSocket.CONNECTING
        ) {
          socket.close();
        }
        socket = null;
      }
      chatQueueRef.current = [];
      setChatList([]);
    };
  }, [platform, roomId]);

  return { status, statusMessage, onlineValue, chatQueueRef, chatList };
}
