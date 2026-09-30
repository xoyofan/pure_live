import type { RoomListItem } from '../api/types';
import { categoryStyle } from '../lib/categoryColor';
import { formatWatching } from '../lib/format';

interface Props {
  room: RoomListItem;
  platformName: string;
  onOpen: (platform: string, roomId: string) => void;
}

/** Feed-level tags some platforms stamp on every room — not real categories. */
const GENERIC_AREAS = new Set(['热门推荐', '推荐', '直播']);

/**
 * Flat live-room card in the zishu_flutter style. Four corners carry the
 * data overlays — top-left category tag (hashed color) + 直播 flag,
 * bottom-left platform chip, bottom-right compact viewers — with title and
 * anchor name on the body below.
 */
export default function RoomCard({ room, platformName, onOpen }: Props) {
  const isLive = room.liveStatus === 'live' || room.status;
  const area = (room.area ?? '').trim();
  const areaStyle = GENERIC_AREAS.has(area) ? null : categoryStyle(area);
  const viewers = formatWatching(room.watching ?? '');

  return (
    <button
      type="button"
      className="room-card"
      onClick={() => onOpen(room.platform || '', room.roomId)}
      title={room.title || room.nick}
    >
      <div className="room-card-cover">
        {room.cover ? (
          <img
            src={room.cover}
            alt=""
            loading="lazy"
            referrerPolicy="no-referrer"
            onError={(e) => {
              e.currentTarget.style.display = 'none';
            }}
          />
        ) : null}
        <div className="cover-tag-row">
          {areaStyle && area && (
            <span className="tag-area" style={{ background: areaStyle.background, color: areaStyle.foreground }}>
              {area}
            </span>
          )}
          {isLive && <span className="tag-live">直播</span>}
        </div>
        <span className={`tag-platform platform-${room.platform || ''}`}>{platformName}</span>
        {viewers ? <span className="tag-viewers">{viewers}</span> : null}
      </div>
      <div className="room-card-body">
        <p className="room-card-title">{room.title || `${platformName} ${room.roomId}`}</p>
        <p className="room-card-meta">
          <span className="room-card-nick">{room.nick || '未知主播'}</span>
          {!isLive && <span className="room-card-offline">未开播</span>}
        </p>
      </div>
    </button>
  );
}
