import type { RoomListItem } from '../api/types';
import { categoryStyle } from '../lib/categoryColor';

interface Props {
  room: RoomListItem;
  platformName: string;
  onOpen: (platform: string, roomId: string) => void;
}

/**
 * Flat live-room card in the zishu_flutter style: 16:9 cover with corner
 * overlays — top-left category tag (hashed color), top-right viewers,
 * bottom-left platform chip — and title + anchor name below on the card body.
 */
/** Feed-level tags some platforms stamp on every room — not real categories. */
const GENERIC_AREAS = new Set(['热门推荐', '推荐', '直播']);

export default function RoomCard({ room, platformName, onOpen }: Props) {
  const isLive = room.liveStatus === 'live' || room.status;
  const area = (room.area ?? '').trim();
  const areaStyle = GENERIC_AREAS.has(area) ? null : categoryStyle(area);

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
        {room.watching ? <span className="tag-viewers">{room.watching}</span> : null}
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
