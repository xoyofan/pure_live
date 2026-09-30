/**
 * Danmaku WS smoke test: connects to the local streaming server, prints the
 * first frames received within the time window, then exits.
 * Usage: node scripts/danmaku-smoke.mjs [roomId] [seconds]
 */
import WebSocket from 'ws';

const roomId = process.argv[2] ?? '6';
const windowSec = Number(process.argv[3] ?? 20);
const windowMs = windowSec * 1000;
const url = `ws://127.0.0.1:8787/api/v1/danmaku/stream?platform=bilibili&roomId=${roomId}`;

console.log(`[smoke] connecting to ${url}`);
const ws = new WebSocket(url);

let frameCount = 0;
const start = Date.now();

ws.on('open', () => {
  console.log('[smoke] client connected');
  const pingTimer = setInterval(() => {
    if (ws.readyState === ws.OPEN) ws.send(JSON.stringify({ type: 'ping' }));
  }, 10_000);
  ws.on('close', () => clearInterval(pingTimer));
});

ws.on('message', (data) => {
  let frame;
  try {
    frame = JSON.parse(String(data));
  } catch {
    console.log('[smoke] non-JSON frame:', String(data).slice(0, 80));
    return;
  }
  frameCount++;
  if (frame.type === 'chat') {
    console.log(`[frame] chat user=${frame.userName} uid=${frame.userId} text=${frame.text.slice(0, 40)}`);
  } else if (frame.type === 'online') {
    console.log(`[frame] online kind=${frame.kind} value=${frame.value}`);
  } else if (frame.type === 'status') {
    console.log(`[frame] status state=${frame.state}${frame.message ? ` msg=${frame.message}` : ''}`);
  } else if (frame.type === 'pong') {
    console.log('[frame] pong');
  } else {
    console.log(`[frame] ${frame.type}:`, JSON.stringify(frame).slice(0, 140));
  }
});

ws.on('error', (err) => console.log('[smoke] error:', err.message));
ws.on('close', (code, reason) => console.log(`[smoke] closed code=${code} reason=${reason}`));

setTimeout(() => {
  console.log(`[smoke] done: ${frameCount} frames in ${Math.round((Date.now() - start) / 1000)}s`);
  ws.close();
  setTimeout(() => process.exit(0), 300);
}, windowMs);
