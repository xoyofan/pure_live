/**
 * WS /api/v1/danmaku/stream?platform=bilibili&roomId=... (contracts/api.md 5).
 * The server proxies the platform chat source and pushes normalized JSON text
 * frames. Client pings keep the session alive; 60s without a ping closes it.
 * Upstream reconnection is owned by the DanmakuSource and surfaced via
 * status frames.
 */
import type { Server as HttpServer, IncomingMessage } from 'node:http';
import type { Duplex } from 'node:stream';
import { WebSocketServer, type WebSocket } from 'ws';
import { registry } from '../backends/types.js';

const PING_TIMEOUT_MS = 60_000;
const PING_CHECK_INTERVAL_MS = 15_000;

function rejectHandshake(socket: Duplex, status: number, code: string, message: string): void {
  const body = JSON.stringify({ error: { code, message } });
  socket.write(
    `HTTP/1.1 ${status} ${status === 401 ? 'Unauthorized' : status === 400 ? 'Bad Request' : 'Not Found'}\r\n` +
      'Connection: close\r\n' +
      'Content-Type: application/json\r\n' +
      `Content-Length: ${Buffer.byteLength(body)}\r\n` +
      '\r\n' +
      body,
  );
  socket.destroy();
}

function parseRequest(url: URL, request: IncomingMessage): { platform: string; roomId: string } {
  const platform = (url.searchParams.get('platform') ?? '').trim();
  const roomId = (url.searchParams.get('roomId') ?? '').trim();
  void request;
  return { platform, roomId };
}

export function attachDanmakuWs(server: HttpServer, token: string): void {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (request, socket, head) => {
    let url: URL;
    try {
      url = new URL(request.url ?? '/', 'http://127.0.0.1');
    } catch {
      rejectHandshake(socket, 400, 'BAD_REQUEST', 'malformed upgrade URL');
      return;
    }
    if (url.pathname !== '/api/v1/danmaku/stream') {
      rejectHandshake(socket, 404, 'BAD_REQUEST', `unknown WS path ${url.pathname}`);
      return;
    }
    if (token) {
      const provided = url.searchParams.get('token') ?? request.headers['x-server-token'] ?? '';
      if (provided !== token) {
        rejectHandshake(socket, 401, 'UNAUTHORIZED', 'token mismatch');
        return;
      }
    }

    const { platform, roomId } = parseRequest(url, request);
    if (!roomId) {
      rejectHandshake(socket, 400, 'BAD_REQUEST', 'roomId query parameter is required');
      return;
    }
    const source = registry.getDanmakuSource(platform);
    if (!source) {
      rejectHandshake(socket, 404, 'PLATFORM_UNSUPPORTED', `platform "${platform}" has no danmaku source`);
      return;
    }

    wss.handleUpgrade(request, socket, head, (client) => {
      let lastPingAt = Date.now();
      const send = (frame: unknown) => {
        if (client.readyState === client.OPEN) {
          client.send(JSON.stringify(frame));
        }
      };

      send({ type: 'status', state: 'connecting' });
      const session = source.connect({
        roomId,
        onFrame: (frame) => send(frame),
      });

      client.on('message', (data) => {
        lastPingAt = Date.now();
        try {
          const parsed = JSON.parse(String(data)) as { type?: unknown };
          if (parsed?.type === 'ping') {
            send({ type: 'pong' });
          }
        } catch {
          // Non-JSON client frames are ignored.
        }
      });
      client.on('close', () => session.close());
      client.on('error', () => session.close());

      const checker = setInterval(() => {
        if (Date.now() - lastPingAt > PING_TIMEOUT_MS) {
          clearInterval(checker);
          session.close();
          client.close(1000, 'ping timeout');
        }
        if (client.readyState === client.CLOSED) clearInterval(checker);
      }, PING_CHECK_INTERVAL_MS);
      client.on('close', () => clearInterval(checker));
    });
  });
}
