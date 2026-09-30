/**
 * Local "my categories" store — zishu keeps category favorites client-side
 * too (no account backend). Entries persist in localStorage; deduped by
 * platform + areaId, capped at 50.
 */

export interface MyCategoryEntry {
  areaId: string;
  areaType?: string;
  typeName?: string;
  areaName?: string;
  platform: string;
  savedAt: number;
}

const KEY = 'purelive.myCategories.v1';
const CAP = 50;

const keyOf = (platform: string, areaId: string) => `${platform}:${areaId}`;

function read(): MyCategoryEntry[] {
  try {
    const raw = localStorage.getItem(KEY);
    const list: unknown = raw ? JSON.parse(raw) : [];
    if (!Array.isArray(list)) return [];
    // Guard against stale/dirty storage: keep only well-formed entries,
    // deduped by platform + areaId, capped at CAP.
    const seen = new Set<string>();
    const clean: MyCategoryEntry[] = [];
    for (const item of list) {
      if (clean.length >= CAP) break;
      if (typeof item !== 'object' || item === null) continue;
      const { areaId, platform } = item as MyCategoryEntry;
      if (typeof areaId !== 'string' || typeof platform !== 'string') continue;
      const k = keyOf(platform, areaId);
      if (seen.has(k)) continue;
      seen.add(k);
      clean.push(item as MyCategoryEntry);
    }
    return clean;
  } catch {
    return [];
  }
}

const listeners = new Set<() => void>();

function write(list: MyCategoryEntry[]): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(list.slice(0, CAP)));
  } catch {
    // storage unavailable (private mode) — favorites stay session-local
  }
  listeners.forEach((listener) => listener());
}

/** Subscribe to save/remove so the rail ★ and tile highlights stay in sync. */
export function subscribeMyCategories(listener: () => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

export function listMyCategories(): MyCategoryEntry[] {
  return read();
}

export function isMyCategory(platform: string, areaId: string): boolean {
  return read().some((e) => e.platform === platform && e.areaId === areaId);
}

export function addMyCategory(entry: Omit<MyCategoryEntry, 'savedAt'>): MyCategoryEntry[] {
  const next: MyCategoryEntry = { ...entry, savedAt: Date.now() };
  const filtered = read().filter((e) => keyOf(e.platform, e.areaId) !== keyOf(next.platform, next.areaId));
  const updated = [next, ...filtered].slice(0, CAP);
  write(updated);
  return updated;
}

export function removeMyCategory(platform: string, areaId: string): MyCategoryEntry[] {
  const updated = read().filter((e) => keyOf(e.platform, e.areaId) !== keyOf(platform, areaId));
  write(updated);
  return updated;
}
