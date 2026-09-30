import { useEffect, useState } from 'react';
import RoomCard from '../components/RoomCard';
import * as followStore from '../lib/followStore';
import type { FollowEntry } from '../lib/followStore';
import type { RoomListItem } from '../api/types';

interface Props {
  onEnterRoom: (platform: string, roomId: string) => void;
  platformName: (id: string) => string;
}

function toListItem(entry: FollowEntry): RoomListItem {
  return {
    platform: entry.platform,
    roomId: entry.roomId,
    title: entry.title,
    nick: entry.nick,
    avatar: entry.avatar,
    cover: entry.cover,
    watching: '',
    link: '',
    status: true,
    liveStatus: 'unknown',
    area: '',
  };
}

/**
 * 我的关注 (zishu /follow): grid of locally followed rooms across platforms.
 * Entries are managed from the play page's 关注/超关 buttons.
 */
export default function FollowPage({ onEnterRoom, platformName }: Props) {
  const [follows, setFollows] = useState<FollowEntry[]>(() => followStore.listFollows());

  // Refresh when returning to the page (entries change on the play page).
  useEffect(() => {
    setFollows(followStore.listFollows());
  }, []);

  return (
    <div className="discover">
      <h2 className="category-index-title">我的关注</h2>
      {follows.length === 0 && (
        <p className="banner">还没有关注的直播间——进入直播间后点右侧栏的「关注」即可收藏。</p>
      )}
      <div className="cards-grid">
        {follows.map((entry) => (
          <div key={`${entry.platform}:${entry.roomId}`} className="follow-cell">
            <RoomCard
              room={toListItem(entry)}
              platformName={platformName(entry.platform)}
              onOpen={onEnterRoom}
            />
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
        ))}
      </div>
    </div>
  );
}
