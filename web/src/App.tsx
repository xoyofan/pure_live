import { useCallback, useEffect, useState } from 'react';
import DiscoverPage, { type CategorySelection } from './pages/DiscoverPage';
import RoomPage from './pages/RoomPage';
import { getPlatforms } from './api/client';
import type { Platform } from './api/types';

type Route =
  | { page: 'discover'; platform: string; keyword: string | null; area: CategorySelection | null }
  | { page: 'room'; platform: string; roomId: string };

/** Fallback platform names when /platforms has not loaded yet. */
const FALLBACK_NAMES: Record<string, string> = { bilibili: 'BiliBili', douyin: 'Douyin' };

interface QueryArea {
  areaType?: string;
  typeName?: string;
  areaName?: string;
}

function queryAreaOf(search: string): QueryArea {
  const query = new URLSearchParams(search);
  return {
    areaType: query.get('areaType') ?? undefined,
    typeName: query.get('typeName') ?? undefined,
    areaName: query.get('areaName') ?? undefined,
  };
}

/**
 * URL is the source of truth:
 *   /{platform}                          -> platform discover home (recommend)
 *   /{platform}?keyword=x                -> search results
 *   /{platform}/category/{areaId}?...    -> category rooms
 *   /{platform}/room/{roomId}            -> playback room
 * The bare "/" shows the douyin home (the M1 discovery platform).
 */
function routeFromLocation(): Route {
  const segments = window.location.pathname.split('/').filter(Boolean).map(decodeURIComponent);
  const query = new URLSearchParams(window.location.search);
  const keyword = query.get('keyword');

  if (segments.length === 3 && segments[1] === 'room' && segments[2]) {
    return { page: 'room', platform: segments[0], roomId: segments[2] };
  }
  if (segments.length === 3 && segments[1] === 'category' && segments[2]) {
    const { areaType, typeName, areaName } = queryAreaOf(window.location.search);
    return {
      page: 'discover',
      platform: segments[0] || 'douyin',
      keyword: null,
      area: { areaId: segments[2], areaType, typeName, areaName },
    };
  }
  return {
    page: 'discover',
    platform: segments[0] || 'douyin',
    keyword: keyword !== null && keyword.trim() !== '' ? keyword : null,
    area: null,
  };
}

function discoverUrl(platform: string, keyword: string | null, area: CategorySelection | null): string {
  const base = `/${encodeURIComponent(platform)}`;
  if (area !== null) {
    const query = new URLSearchParams();
    if (area.areaType) query.set('areaType', area.areaType);
    if (area.typeName) query.set('typeName', area.typeName);
    if (area.areaName) query.set('areaName', area.areaName);
    const suffix = query.toString();
    return `${base}/category/${encodeURIComponent(area.areaId)}${suffix ? `?${suffix}` : ''}`;
  }
  if (keyword !== null && keyword.trim() !== '') return `${base}?keyword=${encodeURIComponent(keyword)}`;
  return base;
}

export default function App() {
  const [route, setRoute] = useState<Route>(routeFromLocation);
  const [platforms, setPlatforms] = useState<Platform[]>([]);

  // Canonical home URL for the bare "/" root.
  useEffect(() => {
    if (window.location.pathname === '/') {
      window.history.replaceState(null, '', discoverUrl('douyin', null, null));
    }
  }, []);

  useEffect(() => {
    const onPopState = () => setRoute(routeFromLocation());
    window.addEventListener('popstate', onPopState);
    return () => window.removeEventListener('popstate', onPopState);
  }, []);

  useEffect(() => {
    let disposed = false;
    getPlatforms()
      .then((res) => {
        if (!disposed) setPlatforms(res.platforms ?? []);
      })
      .catch(() => {
        // Header tabs fall back to the M1 platform set.
      });
    return () => {
      disposed = true;
    };
  }, []);

  const platformName = useCallback(
    (id: string) => platforms.find((p) => p.id === id)?.name ?? FALLBACK_NAMES[id] ?? id,
    [platforms],
  );

  const navigate = useCallback((next: Route) => {
    setRoute(next);
    const url =
      next.page === 'room'
        ? `/${encodeURIComponent(next.platform)}/room/${encodeURIComponent(next.roomId)}`
        : discoverUrl(next.platform, next.keyword, next.area);
    window.history.pushState(null, '', url);
  }, []);

  const showDiscover = useCallback(
    (platform: string, keyword: string | null, area: CategorySelection | null) =>
      navigate({ page: 'discover', platform, keyword, area }),
    [navigate],
  );

  const enterRoom = useCallback(
    (platform: string, roomId: string) => navigate({ page: 'room', platform, roomId }),
    [navigate],
  );

  const tabs = platforms.length > 0 ? platforms : Object.entries(FALLBACK_NAMES).map(([id, name]) => ({ id, name }));

  return (
    <div className="app">
      <header className="app-header">
        <button
          type="button"
          className="app-logo"
          onClick={() => showDiscover(route.platform, null, null)}
        >
          Pure Live
        </button>
        <nav className="platform-tabs">
          {tabs.map((p) => (
            <button
              key={p.id}
              type="button"
              data-platform={p.id}
              className={`platform-tab${route.platform === p.id ? ' active' : ''}`}
              onClick={() => showDiscover(p.id, null, null)}
            >
              {p.name ?? p.id}
            </button>
          ))}
        </nav>
        <form
          className="direct-form"
          onSubmit={(e) => {
            e.preventDefault();
            const input = (e.currentTarget.elements.namedItem('roomId') as HTMLInputElement | null)?.value.trim();
            if (input) enterRoom(route.platform, input);
          }}
        >
          <input name="roomId" placeholder={`${platformName(route.platform)} 房间号`} inputMode="text" />
          <button type="submit" className="btn-small">
            直达
          </button>
        </form>
      </header>
      <main className="app-main">
        {route.page === 'discover' ? (
          <DiscoverPage
            key={`discover:${route.platform}:${route.keyword ?? ''}:${route.area?.areaId ?? ''}`}
            platform={route.platform}
            platformName={platformName(route.platform)}
            keyword={route.keyword}
            area={route.area}
            onEnterRoom={enterRoom}
            onSelectCategory={(platform, area) => showDiscover(platform, null, area)}
            onSearch={(platform, keyword) => showDiscover(platform, keyword.trim() === '' ? null : keyword, null)}
          />
        ) : (
          <RoomPage
            key={`room:${route.platform}:${route.roomId}`}
            platform={route.platform}
            roomId={route.roomId}
            onLeave={() => showDiscover(route.platform, null, null)}
          />
        )}
      </main>
    </div>
  );
}
