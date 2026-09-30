/** Raw bilibili wss debug: auth packet in, print raw packets. */
import WebSocket from 'ws';

const enc = new TextEncoder();

function encodePacket(payload, operation) {
  const data = Buffer.from(payload, 'utf8');
  const packet = Buffer.alloc(data.length + 16);
  packet.writeUInt32BE(packet.length, 0);
  packet.writeUInt16BE(16, 4);
  packet.writeUInt16BE(0, 6);
  packet.writeUInt32BE(operation, 8);
  packet.writeUInt32BE(1, 12);
  data.copy(packet, 16);
  return packet;
}

const roomId = process.argv[2] ?? '6';

const m = await import('../dist/danmaku/bilibili.js');
const b = await import('../dist/backends/bilibili.js');
m.bindBilibiliHelpers(b.exportedWbiSign, b.buvidState);
const creds = await m.discoverDanmakuCredentials(roomId);
console.log('discovered room', creds.realRoomId, 'token len', creds.token.length);

const ws = new WebSocket(creds.serverUrls[0], { headers: creds.headers, handshakeTimeout: 12000 });
ws.on('open', () => {
  console.log('ws open, sending auth');
  const auth = {
    uid: 0,
    roomid: creds.realRoomId,
    protover: 3,
    buvid: creds.buvid,
    support_ack: true,
    queue_uuid: 'deadbeefdeadbeef'.slice(0, 8),
    scene: 'room',
    platform: 'web',
    type: 2,
    key: creds.token,
  };
  ws.send(encodePacket(JSON.stringify(auth), 7));
  setTimeout(() => ws.send(encodePacket('', 2)), 1000);
});
ws.on('message', (d) => {
  const data = Buffer.isBuffer(d) ? d : Buffer.from(d);
  if (data.length >= 16) {
    const pl = data.readUInt32BE(0);
    const pv = data.readUInt16BE(6);
    const op = data.readUInt32BE(8);
    const body = data.subarray(16, Math.min(pl, data.length));
    let preview = body.subarray(0, 60).toString('utf8');
    if (pv === 3 || pv === 2) preview = `<compressed ${body.length}B>`;
    console.log(`packet len=${pl} protover=${pv} op=${op} body=${preview.slice(0, 90)}`);
  } else {
    console.log('short frame', data.length);
  }
});
ws.on('error', (e) => console.log('ws error:', e.message));
ws.on('close', (c, r) => console.log('ws close', c, String(r).slice(0, 80)));
setTimeout(() => process.exit(0), 15000);
