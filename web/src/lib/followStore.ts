import type { RoomListItem } from '../api/types';

/**
 * Local follow store — zishu keeps follows client-side too (no account
 * backend). Entries persist in localStorage; super follow is a flag.
 */

export interface FollowEntry {
  platform: string;
  roomId: string;
  title: string;
  nick: string;
  avatar: string;
  cover: string;
  isSpecial: boolean;
  savedAt: number;
}

const KEY = 'purelive.follow.v1';
const CAP = 200;

function read(): FollowEntry[] {
  try {
    const raw = localStorage.getItem(KEY);
    const list = raw ? (JSON.parse(raw) as FollowEntry[]) : [];
    return Array.isArray(list) ? list : [];
  } catch {
    return [];
  }
}

function write(list: FollowEntry[]): void {
  try {
    localStorage.setItem(KEY, JSON.stringify(list.slice(0, CAP)));
  } catch {
    // storage unavailable (private mode) — follows stay session-local
  }
}

const keyOf = (platform: string, roomId: string) => `${platform}:${roomId}`;

export function listFollows(): FollowEntry[] {
  return read();
}

export function isFollowed(platform: string, roomId: string): boolean {
  return read().some((e) => keyOf(e.platform, e.roomId) === keyOf(platform, roomId));
}

export function getFollow(platform: string, roomId: string): FollowEntry | undefined {
  return read().find((e) => keyOf(e.platform, e.roomId) === keyOf(platform, roomId));
}

export function addFollow(room: RoomListItem): FollowEntry[] {
  const list = read().filter((e) => !e.isSpecial || keyOf(e.platform, e.roomId) !== keyOf(room.platform, room.roomId));
  const next: FollowEntry = {
    platform: room.platform,
    roomId: room.roomId,
    title: room.title ?? '',
    nick: room.nick ?? '',
    avatar: room.avatar ?? '',
    cover: room.cover ?? '',
    isSpecial: false,
    savedAt: Date.now(),
  };
  const filtered = list.filter((e) => keyOf(e.platform, e.roomId) !== keyOf(next.platform, next.roomId));
  const updated = [next, ...filtered].slice(0, CAP);
  write(updated);
  return updated;
}

export function removeFollow(platform: string, roomId: string): FollowEntry[] {
  const updated = read().filter((e) => keyOf(e.platform, e.roomId) !== keyOf(platform, roomId));
  write(updated);
  return updated;
}

export function toggleSpecial(platform: string, roomId: string): FollowEntry[] {
  const list = read();
  const updated = list.map((e) =>
    keyOf(e.platform, e.roomId) === keyOf(platform, roomId) ? { ...e, isSpecial: !e.isSpecial } : e,
  );
  write(updated);
  return updated;
}
