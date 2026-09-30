/**
 * Category tag colors — port of zishu_flutter CategoryStyle.opaqueFor:
 * hash the display name to a base hue, mix 18% toward #141414 for the chip
 * background, and pick dark/light text by luminance.
 */

const FALLBACK_HUES = [
  0x4c8bf5, 0x35a06c, 0xc4763b, 0x8a63d2, 0xd4568c, 0x3f9ea8, 0xb3a23b, 0x5d78d6,
];

const NAME_RULES: Array<[RegExp, number]> = [
  [/英雄联盟|LOL/i, 0x3572b0],
  [/王者|荣耀/, 0x2f9e5f],
  [/和平|吃鸡|pubg/i, 0x4a90d9],
  [/CS|csgo/i, 0xd98a2b],
  [/DOTA/i, 0xb04a2f],
  [/无畏|valorant/i, 0xd45454],
  [/原神|星铁|miHoYo/i, 0x5a63d8],
  [/户外/, 0x3f9e6e],
  [/体育|赛事/, 0x3b8f4a],
  [/美食/, 0xd97a2b],
  [/唱|星秀|颜值/, 0xd4568c],
  [/二次元|动漫/, 0x8a63d2],
  [/聊天|电台/, 0x4c8bf5],
];

function hash32(text: string): number {
  let hash = 0;
  for (let i = 0; i < text.length; i++) {
    hash = (hash * 31 + text.charCodeAt(i)) | 0;
  }
  return Math.abs(hash);
}

function normalize(text: string): string {
  return text.trim().toLowerCase().replace(/\s+/g, '').replace(/：/g, ':');
}

function mixHex(a: number, b: number, t: number): number {
  const ar = (a >> 16) & 0xff;
  const ag = (a >> 8) & 0xff;
  const ab = a & 0xff;
  const br = (b >> 16) & 0xff;
  const bg = (b >> 8) & 0xff;
  const bb = b & 0xff;
  const r = Math.round(ar * (1 - t) + br * t);
  const g = Math.round(ag * (1 - t) + bg * t);
  const bl = Math.round(ab * (1 - t) + bb * t);
  return (r << 16) | (g << 8) | bl;
}

function luminance(hex: number): number {
  const r = (hex >> 16) & 0xff;
  const g = (hex >> 8) & 0xff;
  const b = hex & 0xff;
  return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
}

export interface CategoryStyle {
  background: string;
  foreground: string;
}

const cache = new Map<string, CategoryStyle>();

/** Chip background/foreground for a category display name ('' -> neutral). */
export function categoryStyle(name: string): CategoryStyle | null {
  const key = normalize(name);
  if (!key) return null;
  const cached = cache.get(key);
  if (cached) return cached;

  let base: number | null = null;
  for (const [pattern, color] of NAME_RULES) {
    if (pattern.test(name)) {
      base = color;
      break;
    }
  }
  base ??= FALLBACK_HUES[hash32(key) % FALLBACK_HUES.length];

  const bgSolid = mixHex(base, 0x141414, 0.18);
  const style: CategoryStyle = {
    background: `#${bgSolid.toString(16).padStart(6, '0')}`,
    foreground: luminance(bgSolid) > 0.62 ? '#1a1400' : '#f5f5f5',
  };
  cache.set(key, style);
  return style;
}
