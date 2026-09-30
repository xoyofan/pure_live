/**
 * Minimal SM3 hash (GB/T 32905-2016) — the only crypto primitive the douyin
 * a_bogus signer needs. Verified against the standard test vector
 * SM3("abc") = 66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0
 * (see sm3SelfTest() at the bottom).
 */

const IV = [
  0x7380166f, 0x4914b2b9, 0x172442d7, 0xda8a0600, 0xa96f30bc, 0x163138aa, 0xe38dee4d, 0xb0fb0e4e,
];

const T0 = 0x79cc4519;
const T1 = 0x7a879d8a;

const rotl = (x: number, n: number): number => ((x << n) | (x >>> (32 - n))) >>> 0;

function ff(j: number, a: number, b: number, c: number): number {
  if (j < 16) return (a ^ b ^ c) >>> 0;
  return ((a & b) | (a & c) | (b & c)) >>> 0;
}

function gg(j: number, a: number, b: number, c: number): number {
  if (j < 16) return (a ^ b ^ c) >>> 0;
  return ((a & b) | (~a & c)) >>> 0;
}

/** P0/P1 message-expansion permutations. */
const p0 = (x: number): number => (x ^ rotl(x, 9) ^ rotl(x, 17)) >>> 0;
const p1 = (x: number): number => (x ^ rotl(x, 15) ^ rotl(x, 23)) >>> 0;

/** Computes SM3 over raw bytes, returning 32 digest bytes. */
export function sm3Bytes(data: Uint8Array): Uint8Array {
  // Padding: 0x80, zeros to 56 bytes mod 64, then 64-bit big-endian bit length.
  const bitLen = data.length * 8;
  const paddedLen = (((data.length + 8) >>> 6) + 1) << 6;
  const padded = new Uint8Array(paddedLen);
  padded.set(data);
  padded[data.length] = 0x80;
  const view = new DataView(padded.buffer);
  view.setUint32(paddedLen - 8, Math.floor(bitLen / 0x100000000));
  view.setUint32(paddedLen - 4, bitLen >>> 0);

  let v = Uint32Array.from(IV);

  const w = new Uint32Array(68);
  const wPrime = new Uint32Array(64);

  for (let block = 0; block < paddedLen; block += 64) {
    for (let i = 0; i < 16; i++) w[i] = view.getUint32(block + i * 4);
    for (let i = 16; i < 68; i++) {
      const a = w[i - 16] as number;
      const b = w[i - 9] as number;
      const c = rotl(w[i - 3] as number, 15);
      const d = rotl(w[i - 13] as number, 7);
      const e = w[i - 6] as number;
      w[i] = p1(a ^ b ^ c) ^ d ^ e;
    }
    for (let i = 0; i < 64; i++) wPrime[i] = (w[i] as number) ^ (w[i + 4] as number);

    let a = v[0] as number;
    let b = v[1] as number;
    let c = v[2] as number;
    let d = v[3] as number;
    let e = v[4] as number;
    let f = v[5] as number;
    let g = v[6] as number;
    let h = v[7] as number;
    for (let j = 0; j < 64; j++) {
      const t = j < 16 ? T0 : T1;
      const ss1 = rotl((rotl(a, 12) + e + rotl(t, j % 32)) >>> 0, 7);
      const ss2 = ss1 ^ rotl(a, 12);
      const tt1 = (ff(j, a, b, c) + d + ss2 + (wPrime[j] as number)) >>> 0;
      const tt2 = (gg(j, e, f, g) + h + ss1 + (w[j] as number)) >>> 0;
      d = c;
      c = rotl(b, 9);
      b = a;
      a = tt1;
      h = g;
      g = rotl(f, 19);
      f = e;
      e = p0(tt2);
    }
    const next = new Uint32Array(8);
    next[0] = ((v[0] as number) ^ a) >>> 0;
    next[1] = ((v[1] as number) ^ b) >>> 0;
    next[2] = ((v[2] as number) ^ c) >>> 0;
    next[3] = ((v[3] as number) ^ d) >>> 0;
    next[4] = ((v[4] as number) ^ e) >>> 0;
    next[5] = ((v[5] as number) ^ f) >>> 0;
    next[6] = ((v[6] as number) ^ g) >>> 0;
    next[7] = ((v[7] as number) ^ h) >>> 0;
    v = next;
  }

  const out = new Uint8Array(32);
  const outView = new DataView(out.buffer);
  for (let i = 0; i < 8; i++) outView.setUint32(i * 4, v[i] as number);
  return out;
}

export function sm3Hex(data: Uint8Array): string {
  return Buffer.from(sm3Bytes(data)).toString('hex');
}

export function sm3SelfTest(): boolean {
  const expected = '66c7f0f462eeedd9d1f2d46bdc10e4e24167c4875cf2f7a2297da02b8f4ba8e0';
  return sm3Hex(new TextEncoder().encode('abc')) === expected;
}
