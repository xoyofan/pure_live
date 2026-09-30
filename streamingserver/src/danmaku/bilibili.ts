/**
 * BiliBili danmaku source — port of lib/core/danmaku/bilibili_danmaku.dart.
 *
 * Pipeline: getDanmuInfo (WBI-signed) -> wss connect -> auth packet (protover 3)
 * -> 16-byte packet stream -> brotli/zlib decompress -> JSON commands ->
 * normalized DanmakuFrames. Platform heartbeat every 30s; upstream reconnects
 * with exponential backoff and credential refresh, reported via status frames.
 */
import { createHash } from 'node:crypto';
import { inflateSync } from 'node:zlib';
import WebSocket from 'ws';
import { brotliDecompress } from '../brotli.js';
import { getJson } from '../http.js';
import { BILIBILI_USER_AGENT } from '../backends/bilibili.js';
import type { DanmakuConnectOptions, DanmakuFrame, DanmakuSession, DanmakuSource } from './types.js';
import { nowIso } from './types.js';

const PACKET_HEADER_LENGTH = 16;
const MAX_TRANSPORT_MESSAGE_BYTES = 8 * 1024 * 1024;
const MAX_DECOMPRESSED_MESSAGE_BYTES = 16 * 1024 * 1024;
const MAX_PACKETS_PER_MESSAGE = 4096;
const MAX_COMPRESSED_NESTING_DEPTH = 2;
const HEARTBEAT_INTERVAL_MS = 30_000;
const AUTH_TIMEOUT_MS = 8_000;
const MAX_BACKOFF_MS = 30_000;

/* ------------------------- shared credential discovery ------------------------- */

export interface DanmakuCredentials {
  realRoomId: number;
  token: string;
  serverUrls: string[];
  buvid: string;
  cookie: string;
  headers: Record<string, string>;
}

interface BuvidProvider {
  (): Promise<{ buvid3: string; buvid4: string; cookie: string }>;
}

let wbiSigner:
  | ((params: Record<string, string | number>, forceRefresh?: boolean) => Promise<Record<string, string>>)
  | null = null;
let buvidProvider: BuvidProvider | null = null;

/**
 * The danmaku module reuses the bilibili backend's WBI signer and buvid
 * cookies without importing a backend instance (avoids a cycle).
 */
export function bindBilibiliHelpers(
  signer: (params: Record<string, string | number>, forceRefresh?: boolean) => Promise<Record<string, string>>,
  provider: BuvidProvider,
): void {
  wbiSigner = signer;
  buvidProvider = provider;
}

interface DanmuInfoResponse {
  code?: number;
  message?: string;
  data?: { token?: string; host_list?: Array<{ host?: string; wss_port?: number | string }> };
}

/** Resolves real room id + chat token + server list (port of _discoverDanmaku). */
export async function discoverDanmakuCredentials(roomId: string, maxAttempts = 4): Promise<DanmakuCredentials> {
  if (!wbiSigner || !buvidProvider) throw new Error('bilibili danmaku helpers are not bound');

  const { buvid3, cookie } = await buvidProvider();
  console.error(new Date().toISOString().slice(11,19), '[danmaku-debug] buvid ready, buvid3 len', buvid3.length);
  const roomSigned = await wbiSigner({ room_id: roomId });
  console.error(new Date().toISOString().slice(11,19), '[danmaku-debug] room wbi signed');
  const roomResp = await getJson<{ code?: number; data?: { room_info?: { room_id?: number | string } } }>(
    'https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom',
    {
      params: roomSigned,
      headers: {
        'user-agent': BILIBILI_USER_AGENT,
        referer: 'https://live.bilibili.com/',
        ...(cookie ? { cookie } : {}),
      },
    },
  );
  const realRoomId = Number(roomResp?.data?.room_info?.room_id ?? 0);
  console.error(new Date().toISOString().slice(11,19), '[danmaku-debug] room info resolved, realRoomId', realRoomId);
  if (!Number.isFinite(realRoomId) || realRoomId <= 0) {
    throw new Error(`bilibili room ${roomId} does not exist`);
  }

  const headers = {
    'user-agent': BILIBILI_USER_AGENT,
    origin: 'https://live.bilibili.com',
    referer: `https://live.bilibili.com/${realRoomId}`,
    ...(cookie ? { cookie } : {}),
  };

  let lastError: unknown = null;
  for (let attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      const signed = await wbiSigner({ id: String(realRoomId), type: 0 }, attempt === 1 || attempt === 3);
      console.error(`[danmaku-debug] getDanmuInfo attempt ${attempt} request...`);
      const resp = await getJson<DanmuInfoResponse>(
        'https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo',
        { params: signed, headers },
      );
      console.error(`[danmaku-debug] getDanmuInfo attempt ${attempt} code=${resp?.code}`);
      const token = resp?.data?.token ?? '';
      console.error(
        `[danmaku-debug] token len=${token.length} dataType=${typeof resp?.data} hosts=${resp?.data?.host_list?.length ?? 'n/a'}`,
      );
      if (resp?.code === 0 && token) {
        // The generic gateway resolves reliably; keep regional nodes as failovers.
        const serverUrls = ['wss://broadcastlv.chat.bilibili.com/sub'];
        for (const item of resp.data?.host_list ?? []) {
          const host = (item?.host ?? '').trim();
          if (!host) continue;
          const port = Number(item?.wss_port ?? 443) || 443;
          const endpoint = `wss://${host}${port === 443 ? '' : `:${port}`}/sub`;
          if (!serverUrls.includes(endpoint)) serverUrls.push(endpoint);
        }
        return { realRoomId, token, serverUrls, buvid: buvid3, cookie, headers };
      }
      lastError = new Error(`getDanmuInfo code=${resp?.code}`);
    } catch (error) {
      lastError = error;
    }
    if (attempt + 1 < maxAttempts) {
      await new Promise((resolve) => setTimeout(resolve, 180 * (attempt + 1)));
    }
  }
  throw lastError instanceof Error ? lastError : new Error('bilibili danmaku discovery failed');
}

/* ------------------------------ packet encode/decode --------------------------- */

function encodePacket(payload: string, operation: number): Buffer {
  const data = Buffer.from(payload, 'utf8');
  const packet = Buffer.alloc(data.length + PACKET_HEADER_LENGTH);
  packet.writeUInt32BE(packet.length, 0);
  packet.writeUInt16BE(PACKET_HEADER_LENGTH, 4);
  packet.writeUInt16BE(0, 6); // protocol version 0 = JSON body
  packet.writeUInt32BE(operation, 8);
  packet.writeUInt32BE(1, 12);
  data.copy(packet, PACKET_HEADER_LENGTH);
  return packet;
}

type PacketHandler = (protocolVersion: number, operation: number, body: Buffer) => void;

function readPacketStream(data: Buffer, depth: number, onPacket: PacketHandler): void {
  if (depth > MAX_COMPRESSED_NESTING_DEPTH) throw new Error('packet nesting too deep');
  let offset = 0;
  let count = 0;
  while (offset + PACKET_HEADER_LENGTH <= data.length) {
    count++;
    if (count > MAX_PACKETS_PER_MESSAGE) throw new Error('too many packets in message');
    const packetLength = data.readUInt32BE(offset);
    const headerLength = data.readUInt16BE(offset + 4);
    const protocolVersion = data.readUInt16BE(offset + 6);
    const operation = data.readUInt32BE(offset + 8);
    if (
      headerLength < PACKET_HEADER_LENGTH ||
      packetLength < headerLength ||
      packetLength > MAX_TRANSPORT_MESSAGE_BYTES ||
      offset + packetLength > data.length
    ) {
      throw new Error(
        `invalid frame: offset=${offset}, packet=${packetLength}, header=${headerLength}, total=${data.length}`,
      );
    }
    const body = data.subarray(offset + headerLength, offset + packetLength);
    onPacket(protocolVersion, operation, body);
    offset += packetLength;
  }
  if (offset !== data.length) throw new Error(`incomplete frame: parsed=${offset}, total=${data.length}`);
}

function decompressBody(body: Buffer, protocolVersion: number): Buffer {
  if (protocolVersion === 2) {
    return inflateSync(body, { maxOutputLength: MAX_DECOMPRESSED_MESSAGE_BYTES });
  }
  const out = brotliDecompress(new Uint8Array(body));
  if (out.byteLength > MAX_DECOMPRESSED_MESSAGE_BYTES) {
    throw new Error(`decompressed message exceeds ${MAX_DECOMPRESSED_MESSAGE_BYTES} bytes`);
  }
  return Buffer.from(out.buffer, out.byteOffset, out.byteLength);
}

/* ------------------------------ message normalization -------------------------- */

function parseRichInfo(raw: unknown): Record<string, unknown> | null {
  if (typeof raw === 'string' && raw.trimStart().startsWith('{')) {
    try {
      return JSON.parse(raw) as Record<string, unknown>;
    } catch {
      return null;
    }
  }
  return raw && typeof raw === 'object' ? (raw as Record<string, unknown>) : null;
}

function readRichField(rich: Record<string, unknown> | null, field: string): string {
  if (!rich) return '';
  const user = (rich['user'] && typeof rich['user'] === 'object' ? rich['user'] : rich) as Record<string, unknown>;
  const base = user && typeof user['base'] === 'object' ? (user['base'] as Record<string, unknown>) : null;
  if (!base) return '';
  const direct = String(base[field] ?? '').trim();
  if (direct) return direct;
  const origin = base['origin_info'];
  return origin && typeof origin === 'object' ? String((origin as Record<string, unknown>)[field] ?? '').trim() : '';
}

function preferredUserName(packet: Record<string, unknown>, metadata: unknown[], legacyName: string): string {
  const richInfo = parseRichInfo(metadata.length > 15 ? metadata[15] : undefined);
  const packetUserInfo = parseRichInfo(packet['uinfo']);
  const packetDataUserInfo = parseRichInfo(
    packet['data'] && typeof packet['data'] === 'object'
      ? (packet['data'] as Record<string, unknown>)['uinfo']
      : undefined,
  );

  const candidates = [
    readRichField(richInfo, 'name'),
    readRichField(packetUserInfo, 'name'),
    readRichField(packetDataUserInfo, 'name'),
  ];
  const masked = /\*{2,}|＊{2,}/;
  for (const candidate of [...candidates, legacyName]) {
    if (candidate && !masked.test(candidate)) return candidate;
  }
  return candidates[0] || legacyName;
}

function preferredUserAvatar(metadata: unknown[], packet: Record<string, unknown>): string {
  const richInfo = parseRichInfo(metadata.length > 15 ? metadata[15] : undefined);
  const packetUserInfo = parseRichInfo(packet['uinfo']);
  return readRichField(richInfo, 'face') || readRichField(packetUserInfo, 'face');
}

type AckSender = (packet: Buffer) => void;

function commandToFrames(command: Record<string, unknown>, sendAck: AckSender): DanmakuFrame[] {
  const cmd = String(command['cmd'] ?? '');
  const frames: DanmakuFrame[] = [];

  if (cmd.includes('DANMU_MSG')) {
    const info = Array.isArray(command['info']) ? (command['info'] as unknown[]) : [];
    if (info.length > 0) {
      const text = String(info[1] ?? '');
      const user = Array.isArray(info[2]) ? (info[2] as unknown[]) : [];
      if (user.length > 0 && text) {
        const metadata = Array.isArray(info[0]) ? (info[0] as unknown[]) : [];
        const userName = preferredUserName(command, metadata, String(user[1] ?? ''));
        const avatar = preferredUserAvatar(metadata, command);
        const rawTimestamp = Number(metadata.length > 4 ? metadata[4] : NaN);
        const ts =
          Number.isFinite(rawTimestamp) && rawTimestamp > 0
            ? new Date(rawTimestamp > 100000000000 ? rawTimestamp : rawTimestamp * 1000).toISOString()
            : nowIso();
        frames.push({ type: 'chat', userName, userId: String(user[0] ?? ''), text, avatar, ts });
      }
    }
  } else if (cmd === 'WATCHED_CHANGE') {
    const data = command['data'];
    const value = Number(data && typeof data === 'object' ? (data as Record<string, unknown>)['num'] : NaN);
    if (Number.isFinite(value) && value >= 0) {
      frames.push({ type: 'online', kind: 'totalViewers', value, ts: nowIso() });
    }
  } else if (cmd === 'SUPER_CHAT_MESSAGE') {
    const data = command['data'];
    if (data && typeof data === 'object') {
      const d = data as Record<string, unknown>;
      const userInfo = (d['user_info'] ?? {}) as Record<string, unknown>;
      frames.push({
        type: 'superChat',
        userName: String(userInfo['uname'] ?? ''),
        userId: String(userInfo['uid'] ?? d['uid'] ?? ''),
        text: String(d['message'] ?? ''),
        price: Number(d['price'] ?? 0),
        ts: nowIso(),
      });
    }
  } else if (cmd === 'SEND_GIFT') {
    const data = command['data'];
    if (data && typeof data === 'object') {
      const d = data as Record<string, unknown>;
      frames.push({
        type: 'gift',
        userName: String(d['uname'] ?? ''),
        userId: String(d['uid'] ?? ''),
        giftName: String(d['giftName'] ?? ''),
        count: Number(d['num'] ?? 1),
        ts: nowIso(),
      });
    }
  }

  // Bounded acknowledgement for packets that require it (op 24).
  if (
    command['p_is_ack'] === true &&
    typeof command['p_msg_type'] !== 'undefined' &&
    String(command['msg_id'] ?? '').trim()
  ) {
    const msgId = String(command['msg_id']).trim();
    const msgType = Number(command['p_msg_type']);
    if (Number.isFinite(msgType)) {
      sendAck(encodePacket(JSON.stringify({ msg_id: msgId, cmd, p_msg_type: msgType }), 24));
    }
  }
  return frames;
}

/* --------------------------------- the source ---------------------------------- */

const encodeHeartbeat = (): Buffer => encodePacket('', 2);

function buildAuthPacket(creds: DanmakuCredentials): Buffer {
  const payload = {
    uid: 0,
    roomid: creds.realRoomId,
    protover: 3,
    buvid: creds.buvid,
    support_ack: true,
    queue_uuid: createHash('md5')
      .update(`${Date.now()}-${Math.random()}`)
      .digest('hex')
      .slice(0, 8),
    scene: 'room',
    platform: 'web',
    type: 2,
    key: creds.token,
  };
  return encodePacket(JSON.stringify(payload), 7);
}

export class BilibiliDanmakuSource implements DanmakuSource {
  connect(options: DanmakuConnectOptions): DanmakuSession {
    let closed = false;
    let ws: WebSocket | null = null;
    let heartbeatTimer: NodeJS.Timeout | null = null;
    let authTimer: NodeJS.Timeout | null = null;
    let reconnectTimer: NodeJS.Timeout | null = null;
    let attempts = 0;

    const emit = options.onFrame;
    const sendStatus = (state: 'connecting' | 'connected' | 'reconnecting' | 'closed' | 'error', message?: string) => {
      if (closed && state !== 'closed') return;
      emit(message === undefined ? { type: 'status', state } : { type: 'status', state, message });
    };

    const clearTimers = () => {
      if (heartbeatTimer) clearInterval(heartbeatTimer);
      if (authTimer) clearTimeout(authTimer);
      if (reconnectTimer) clearTimeout(reconnectTimer);
      heartbeatTimer = null;
      authTimer = null;
      reconnectTimer = null;
    };

    const teardownSocket = () => {
      if (ws) {
        try {
          ws.removeAllListeners();
          ws.terminate();
        } catch {
          // already closed
        }
        ws = null;
      }
      clearTimers();
    };

    const scheduleReconnect = () => {
      if (closed) return;
      const delay = Math.min(1000 * 2 ** attempts, MAX_BACKOFF_MS) + Math.floor(Math.random() * 250);
      attempts++;
      sendStatus('reconnecting', `upstream lost; retrying in ~${Math.round(delay / 1000)}s`);
      reconnectTimer = setTimeout(() => {
        reconnectTimer = null;
        void connectUpstream();
      }, delay);
    };

    const sendPacket = (packet: Buffer) => {
      try {
        ws?.send(packet);
      } catch {
        // socket died; the close handler schedules a reconnect
      }
    };

    const handleCommandText = (text: string, sendAck: AckSender) => {
      const trimmed = text.trim();
      if (!trimmed) return;
      let command: Record<string, unknown>;
      try {
        command = JSON.parse(trimmed) as Record<string, unknown>;
      } catch {
        return;
      }
      for (const frame of commandToFrames(command, sendAck)) emit(frame);
    };

    const handleMessage = (data: Buffer) => {
      try {
        if (data.length > MAX_TRANSPORT_MESSAGE_BYTES) {
          throw new Error(`message too large: ${data.length} bytes`);
        }
        readPacketStream(data, 0, (protocolVersion, operation, body) => {
          if (operation === 3) {
            if (body.length >= 4) {
              emit({ type: 'online', kind: 'popularity', value: body.readUInt32BE(0), ts: nowIso() });
            }
            return;
          }
          if (operation === 5) {
            const sendAck: AckSender = (packet) => sendPacket(packet);
            if (protocolVersion === 2 || protocolVersion === 3) {
              const decoded = decompressBody(body, protocolVersion);
              readPacketStream(decoded, 1, (_version, innerOp, innerBody) => {
                if (innerOp === 3) {
                  if (innerBody.length >= 4) {
                    emit({ type: 'online', kind: 'popularity', value: innerBody.readUInt32BE(0), ts: nowIso() });
                  }
                  return;
                }
                if (innerOp !== 5) return;
                handleCommandText(innerBody.toString('utf8'), sendAck);
              });
            } else {
              handleCommandText(body.toString('utf8'), sendAck);
            }
            return;
          }
          if (operation === 8) {
            let code = -1;
            const text = body.toString('utf8').trim();
            try {
              const parsed = text ? (JSON.parse(text) as Record<string, unknown>) : { code: 0 };
              code = Number(parsed['code'] ?? -1);
            } catch {
              code = -1;
            }
            if (code === 0) {
              if (authTimer) clearTimeout(authTimer);
              authTimer = null;
              attempts = 0;
              sendStatus('connected');
              heartbeatTimer = setInterval(() => sendPacket(encodeHeartbeat()), HEARTBEAT_INTERVAL_MS);
              sendPacket(encodeHeartbeat());
            } else {
              // Auth rejected: credentials are stale; refresh and reconnect.
              teardownSocket();
              scheduleReconnect();
            }
          }
        });
      } catch {
        // Malformed frame: drop it, keep the session alive.
      }
    };

    const connectUpstream = async () => {
      if (closed) return;
      console.error(new Date().toISOString().slice(11,19), '[danmaku-debug] connectUpstream start');
      sendStatus(attempts === 0 ? 'connecting' : 'reconnecting');
      let creds: DanmakuCredentials;
      try {
        creds = await discoverDanmakuCredentials(options.roomId);
      } catch (error) {
        console.error(new Date().toISOString().slice(11,19), '[danmaku-debug] discovery failed:', error instanceof Error ? error.message : error);
        const message = error instanceof Error ? error.message : String(error);
        if (message.includes('does not exist')) {
          closed = true;
          sendStatus('error', message);
          sendStatus('closed', 'room not found');
          return;
        }
        scheduleReconnect();
        return;
      }
      if (closed) return;
      console.error(new Date().toISOString().slice(11,19), '[danmaku-debug] discovery returned closed=', closed);
      const endpoints = creds.serverUrls;
      const endpoint = endpoints[attempts % endpoints.length] as string;

      ws = new WebSocket(endpoint, {
        headers: creds.headers,
        handshakeTimeout: 12_000,
        maxPayload: MAX_TRANSPORT_MESSAGE_BYTES,
      });
      console.error(new Date().toISOString().slice(11,19), '[danmaku-debug] ws created:', endpoint);

      ws.on('open', () => {
        console.error(new Date().toISOString().slice(11,19), '[danmaku-debug] ws open, auth sent');
        sendPacket(buildAuthPacket(creds));
        authTimer = setTimeout(() => {
          // No auth acknowledgement within 8s: drop and retry.
          teardownSocket();
          scheduleReconnect();
        }, AUTH_TIMEOUT_MS);
      });
      ws.on('message', (data: WebSocket.RawData) => {
        handleMessage(Buffer.isBuffer(data) ? data : Buffer.from(data as ArrayBuffer));
      });
      ws.on('error', () => {
        // The close handler drives reconnection.
      });
      ws.on('close', () => {
        if (closed) return;
        teardownSocket();
        if (closed) return;
        scheduleReconnect();
      });
    };

    void connectUpstream();

    return {
      close() {
        if (closed) return;
        closed = true;
        teardownSocket();
        sendStatus('closed');
      },
    };
  }
}
