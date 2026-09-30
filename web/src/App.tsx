import { useCallback, useEffect, useState } from 'react';
import HomePage from './pages/HomePage';
import RoomPage from './pages/RoomPage';

type Route = { page: 'home' } | { page: 'room'; platform: string; roomId: string };

/**
 * Derive the route from the URL. The canonical room form is
 * /{platform}/room/{roomId} — e.g. /douyin/room/435911602058.
 * Anything else is the home page.
 */
function routeFromLocation(): Route {
  const segments = window.location.pathname.split('/').filter(Boolean).map(decodeURIComponent);
  if (segments.length === 3) {
    const [platform, kind, id] = segments;
    if (kind === 'room' && platform && id) {
      return { page: 'room', platform, roomId: id };
    }
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
