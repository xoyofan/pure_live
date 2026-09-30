import type { RoomListItem } from '../api/types';

interface Props {
  room: RoomListItem;
  platformName: string;
  onOpen: (platform: string, roomId: string) => void;
}

/**
 * Live room card (SFVideoLive RoomCard pattern): 16:9 cover with corner
 * badges — top-left LIVE, top-right viewers — and a single-line title plus
 * anchor-name meta row below.
 */
export default function RoomCard({ room, platformName, onOpen }: Props) {
  const isLive = room.liveStatus === 'live' || room.status;

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
        {isLive && <span className="badge badge-live">LIVE</span>}
        <span className="badge badge-platform">{platformName}</span>
        {room.watching ? <span className="badge badge-viewers">{room.watching}</span> : null}
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
