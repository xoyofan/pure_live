import { useEffect, useState } from 'react';
import RoomCard from '../components/RoomCard';
import StateBanner from '../components/StateBanner';
import { getLiveStatus } from '../api/client';
import * as followStore from '../lib/followStore';
import type { FollowEntry } from '../lib/followStore';
import type { RoomListItem } from '../api/types';

interface Props {
  onEnterRoom: (platform: string, roomId: string) => void;
  platformName: (id: string) => string;
}

/** 挂载时开播状态刷新的在请求数上限 (api.md 4.3.1)。 */
const LIVE_STATUS_CONCURRENCY = 3;

function toListItem(entry: FollowEntry, live: boolean | undefined): RoomListItem {
  return {
    platform: entry.platform,
    roomId: entry.roomId,
    title: entry.title,
    nick: entry.nick,
    avatar: entry.avatar,
    cover: entry.cover,
    watching: '',
    link: '',
    // 刷新完成前维持原状(按在播渲染),刷新后与探测结果保持一致。
    status: live ?? true,
    liveStatus: live === undefined ? 'unknown' : live ? 'live' : 'offline',
    area: '',
  };
}

/** 角标:直播中(绿)/ 未开播(灰)。 */
function liveBadge(live: boolean) {
  return {
    position: 'absolute',
    right: 8,
    bottom: 8,
    zIndex: 2,
    fontSize: 11,
    lineHeight: 1,
    padding: '4px 7px',
    borderRadius: 'var(--radius-sm)',
    fontWeight: 600,
    background: live ? 'var(--ok)' : 'var(--text-dim)',
    color: '#fff',
  } as const;
}

/**
 * 我的关注 (zishu /follow): grid of locally followed rooms across platforms.
 * Entries are managed from the play page's 关注/超关 buttons. On mount every
 * entry gets a live-status refresh (at most 3 requests in flight); the cell
 * badge settles to 直播中/未开播, and failed probes simply keep no badge.
 */
export default function FollowPage({ onEnterRoom, platformName }: Props) {
  const [follows, setFollows] = useState<FollowEntry[]>(() => followStore.listFollows());
  const [liveMap, setLiveMap] = useState<Record<string, boolean>>({});

  // Refresh when returning to the page (entries change on the play page),
  // then probe each followed room's live status with a small worker pool.
  useEffect(() => {
    const entries = followStore.listFollows();
    setFollows(entries);
    if (entries.length === 0) return;
    let cancelled = false;
    const queue = [...entries];
    const worker = async (): Promise<void> => {
      for (;;) {
        const entry = queue.shift();
        if (!entry || cancelled) return;
        try {
          const { live } = await getLiveStatus(entry.platform, entry.roomId);
          if (!cancelled) {
            setLiveMap((prev) => ({ ...prev, [`${entry.platform}:${entry.roomId}`]: live }));
          }
        } catch {
          // 刷新失败(服务不可达等):保留未知态,不显示角标。
        }
      }
    };
    void Promise.all(
      Array.from({ length: Math.min(LIVE_STATUS_CONCURRENCY, entries.length) }, () => worker()),
    );
    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <div className="discover">
      <h2 className="category-index-title">我的关注</h2>
      {follows.length === 0 && (
        <StateBanner kind="empty" text="还没有关注的直播间——进入直播间后点右侧栏的「关注」即可收藏。" />
      )}
      <div className="cards-grid">
        {follows.map((entry) => {
          const live = liveMap[`${entry.platform}:${entry.roomId}`];
          return (
            <div key={`${entry.platform}:${entry.roomId}`} className="follow-cell">
              <RoomCard
                room={toListItem(entry, live)}
                platformName={platformName(entry.platform)}
                onOpen={onEnterRoom}
              />
              {live !== undefined && (
                <span className="follow-live-badge" style={liveBadge(live)}>
                  {live ? '直播中' : '未开播'}
                </span>
              )}
              {entry.isSpecial && <span className="follow-star">★ 超关</span>}
              <button
                type="button"
                className="follow-remove"
                title="取消关注"
                onClick={() => setFollows(followStore.removeFollow(entry.platform, entry.roomId))}
              >
                ✕
              </button>
            </div>
          );
        })}
      </div>
    </div>
  );
}
