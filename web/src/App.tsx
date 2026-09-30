import { useCallback, useEffect, useState } from 'react';
import DiscoverPage, { type CategorySelection } from './pages/DiscoverPage';
import RoomPage from './pages/RoomPage';
import { getCategories, getPlatforms } from './api/client';
import type { AreaItem, Platform } from './api/types';

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
 *
 * Shell layout follows zishu_flutter: a left rail (brand / nav / platform
 * tiles / hot categories) around the browse pages; the play page goes
 * full-bleed without the rail.
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
  const [hotAreas, setHotAreas] = useState<AreaItem[]>([]);

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

  // Sidebar hot-category list: leaves of the platform directory (top 12).
  useEffect(() => {
    if (route.page !== 'discover') return;
    let disposed = false;
    setHotAreas([]);
    getCategories(route.platform)
      .then((res) => {
        if (disposed) return;
        const leaves: AreaItem[] = [];
        for (const category of res.categories ?? []) {
          for (const child of category.children) {
            if (child.areaId) leaves.push(child);
          }
        }
        setHotAreas(leaves.slice(0, 12));
      })
      .catch(() => {
        // Sidebar list is decoration; category chips still work.
      });
    return () => {
      disposed = true;
    };
  }, [route.page, route.platform]);

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

  const submitTopForm = (raw: string) => {
    const value = raw.trim();
    if (!value) return;
    if (/^\d{3,}$/.test(value)) enterRoom(route.platform, value);
    else showDiscover(route.platform, value, null);
  };

  const sidebar = route.page === 'discover' && (
    <aside className="sidebar">
      <div className="side-brand">Pure Live</div>
      <nav className="side-nav">
        <button
          type="button"
          className={`side-link${route.page === 'discover' && route.area === null && route.keyword === null ? ' active' : ''}`}
          onClick={() => showDiscover(route.platform, null, null)}
        >
          首页
        </button>
      </nav>
      <div className="side-section-label">平台</div>
      <div className="side-platforms">
        {tabs.map((p) => (
          <button
            key={p.id}
            type="button"
            data-platform={p.id}
            className={`side-platform${route.platform === p.id ? ' active' : ''}`}
            onClick={() => showDiscover(p.id, null, null)}
          >
            {p.name ?? p.id}
          </button>
        ))}
      </div>
      {hotAreas.length > 0 && (
        <>
          <div className="side-section-label">热门分类</div>
          <div className="side-hot">
            {hotAreas.map((area) => (
              <button
                key={area.areaId}
                type="button"
                className={`side-link small${route.area?.areaId === area.areaId ? ' active' : ''}`}
                onClick={() =>
                  showDiscover(route.platform, null, {
                    areaId: area.areaId ?? '',
                    areaType: area.areaType ?? undefined,
                    typeName: area.typeName ?? undefined,
                    areaName: area.areaName ?? undefined,
                  })
                }
              >
                {area.areaName || area.typeName || area.areaId}
              </button>
            ))}
          </div>
        </>
      )}
    </aside>
  );

  return (
    <div className={`app${route.page === 'room' ? ' app-play' : ''}`}>
      {sidebar}
      <div className="app-body">
        <header className="app-header">
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
            className="top-search"
            onSubmit={(e) => {
              e.preventDefault();
              submitTopForm((e.currentTarget.elements.namedItem('q') as HTMLInputElement | null)?.value ?? '');
            }}
          >
            <input name="q" placeholder="搜索直播间 / 房间号直达" />
            <button type="submit" className="btn-small">
              搜索
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
              platformName={platformName(route.platform)}
              roomId={route.roomId}
              onLeave={() => showDiscover(route.platform, null, null)}
              onOpenRoom={enterRoom}
            />
          )}
        </main>
      </div>
    </div>
  );
}
