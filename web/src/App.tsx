import { useCallback, useEffect, useState } from 'react';
import HomePage from './pages/HomePage';
import RoomPage from './pages/RoomPage';

type Route = { page: 'home' } | { page: 'room'; platform: string; roomId: string };

/**
 * Derive the route from the URL. Supported deep-link forms:
 *   /{platform}/{roomId}        (path style, canonical)
 *   /?platform=...&roomId=...   (legacy query style, still honored)
 */
function routeFromLocation(): Route {
  const segments = window.location.pathname.split('/').filter(Boolean);
  if (segments.length === 2) {
    return { page: 'room', platform: decodeURIComponent(segments[0]), roomId: decodeURIComponent(segments[1]) };
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
  const nextUrl = route.page === 'room' ? `/${encodeURIComponent(route.platform)}/${encodeURIComponent(route.roomId)}` : '/';
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
