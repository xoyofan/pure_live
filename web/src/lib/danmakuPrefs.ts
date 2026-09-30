/**
 * Danmaku display preferences (font size / opacity / speed / display area /
 * stroke), persisted in localStorage. Defaults mirror the fixed behaviour
 * before the settings panel existed: scale 1, full opacity, 9s crossing time,
 * full-screen area, outlined text.
 */

export interface DanmakuPrefs {
  /** Multiplier on the 20px base danmaku font size (0.7 ~ 1.5). */
  fontSizeScale: number;
  /** Overall overlay opacity (0.2 ~ 1). */
  opacity: number;
  /** Seconds for a message to cross the canvas (5 ~ 15; smaller = faster). */
  durationSec: number;
  /** Fraction of the canvas height used by danmaku tracks (0.25 / 0.5 / 0.75 / 1). */
  areaRatio: number;
  /** Dark text outline on/off (false = plain colored text). */
  stroke: boolean;
}

const KEY = 'purelive.danmakuPrefs.v1';

/** Slider bounds + defaults, shared by the settings panel and the loader. */
export const DANMAKU_PREFS_LIMITS = {
  fontSizeScale: { min: 0.7, max: 1.5, step: 0.05, default: 1 },
  opacity: { min: 0.2, max: 1, step: 0.05, default: 1 },
  durationSec: { min: 5, max: 15, step: 1, default: 9 },
  areaRatio: { min: 0.25, max: 1, step: 0.25, default: 1 },
} as const;

/** The four display-area levels offered by the settings panel. */
export const DANMAKU_AREA_OPTIONS = [0.25, 0.5, 0.75, 1] as const;

const DEFAULTS: DanmakuPrefs = {
  fontSizeScale: DANMAKU_PREFS_LIMITS.fontSizeScale.default,
  opacity: DANMAKU_PREFS_LIMITS.opacity.default,
  durationSec: DANMAKU_PREFS_LIMITS.durationSec.default,
  areaRatio: DANMAKU_PREFS_LIMITS.areaRatio.default,
  stroke: true,
};

function clampPref(value: unknown, key: keyof typeof DANMAKU_PREFS_LIMITS): number {
  const limits = DANMAKU_PREFS_LIMITS[key];
  const n = typeof value === 'number' ? value : Number(value);
  if (!Number.isFinite(n)) return limits.default;
  // Clamp into range, then snap to the slider step so a hand-edited
  // localStorage value cannot leave the slider thumb between steps.
  const clamped = Math.min(limits.max, Math.max(limits.min, n));
  if (limits.step <= 0) return clamped;
  const snapped = limits.min + Math.round((clamped - limits.min) / limits.step) * limits.step;
  return Math.min(limits.max, Math.max(limits.min, snapped));
}

export function loadDanmakuPrefs(): DanmakuPrefs {
  try {
    const raw = localStorage.getItem(KEY);
    if (!raw) return { ...DEFAULTS };
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== 'object') return { ...DEFAULTS };
    const data = parsed as Record<string, unknown>;
    return {
      fontSizeScale: clampPref(data.fontSizeScale, 'fontSizeScale'),
      opacity: clampPref(data.opacity, 'opacity'),
      durationSec: clampPref(data.durationSec, 'durationSec'),
      areaRatio: clampPref(data.areaRatio, 'areaRatio'),
      stroke: typeof data.stroke === 'boolean' ? data.stroke : DEFAULTS.stroke,
    };
  } catch {
    return { ...DEFAULTS };
  }
}

export function saveDanmakuPrefs(prefs: DanmakuPrefs): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(prefs));
  } catch {
    // storage unavailable (private mode) — prefs stay session-local
  }
}

/**
 * App-level default danmaku switch (top-bar settings dialog in App.tsx),
 * persisted separately from the display prefs: true = rooms open with
 * danmaku shown (RoomPage seeds its per-session mute state from it).
 */
const DANMAKU_DEFAULT_KEY = 'purelive.danmakuDefault.v1';

export function loadDanmakuDefault(): boolean {
  try {
    return localStorage.getItem(DANMAKU_DEFAULT_KEY) !== 'off';
  } catch {
    return true;
  }
}

export function saveDanmakuDefault(on: boolean): void {
  try {
    localStorage.setItem(DANMAKU_DEFAULT_KEY, on ? 'on' : 'off');
  } catch {
    // storage unavailable (private mode) — default stays session-local
  }
}
