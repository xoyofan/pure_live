import { useCallback, useEffect, useState } from 'react';
import HomePage from './pages/HomePage';
import RoomPage from './pages/RoomPage';

type Route = { page: 'home' } | { page: 'room'; platform: string; roomId: string };

/** Page kinds that live under a platform prefix (/{platform}/{kind}/...). */
const PAGE_KINDS = ['room'] as const;

/**
 * Derive the route from the URL. Supported forms (canonical first):
 *   /{platform}/room/{roomId}   e.g. /douyin/room/435911602058
 *   /{platform}/{roomId}        shorthand without the page kind
 *   /?platform=...&roomId=...   legacy query form
 */
function routeFromLocation(): Route {
  const segments = window.location.pathname.split('/').filter(Boolean).map(decodeURIComponent);
  if (segments.length >= 2) {
    const [platform, kind, ...rest] = segments;
    if ((PAGE_KINDS as readonly string[]).includes(kind)) {
      if (kind === 'room' && rest[0]) {
        return { page: 'room', platform, roomId: rest[0] };
      }
      // Known kind with a missing id (e.g. /douyin/room) — home for now.
      return { page: 'home' };
    }
    if (segments.length === 2 && rest.length === 0) {
      return { page: 'room', platform, roomId: kind };
    }
  }
  const params = new URLSearchParams(window.location.search);
  const platform = params.get('platform');
  const roomId = params.get('roomId');
  if (platform && roomId) {
    return { page: 'room', platform, roomId };
  }
  return { page: 'home' };
}

function syncUrl(route: Route) {
  const nextUrl =
    route.page === 'room'
      ? `/${encodeURIComponent(route.platform)}/room/${encodeURIComponent(route.roomId)}`
      : '/';
  window.history.pushState(null, '', nextUrl);
}

export default function App() {
  const [route, setRoute] = useState<Route>(routeFromLocation);
  // Remember the last manual entry so "返回" keeps the form filled.
  const [lastPlatform, setLastPlatform] = useState('bilibili');
  const [lastRoomId, setLastRoomId] = useState('');

  // Browser back/forward re-derives the route from the URL.
  useEffect(() => {
    const onPopState = () => setRoute(routeFromLocation());
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  const enterRoom = useCallback((platform: string, roomId: string) => {
    setLastPlatform(platform);
    setLastRoomId(roomId);
    setRoute({ page: 'room', platform, roomId });
    syncUrl({ page: 'room', platform, roomId });
  }, []);

  const leaveRoom = useCallback(() => {
    setRoute({ page: 'home' });
    syncUrl({ page: 'home' });
  }, []);

  return (
    <div className="app">
      <header className="app-header">
        <button type="button" className="app-logo" onClick={leaveRoom}>
          Pure Live
        </button>
        <span className="app-sub">网页直播播放间</span>
      </header>
      <main className="app-main">
        {route.page === 'home' ? (
          <HomePage
            initialPlatform={lastPlatform}
            initialRoomId={lastRoomId}
            onEnterRoom={enterRoom}
          />
        ) : (
          <RoomPage
            key={`room:${route.platform}:${route.roomId}`}
            platform={route.platform}
            roomId={route.roomId}
            onLeave={leaveRoom}
          />
        )}
      </main>
    </div>
  );
}
