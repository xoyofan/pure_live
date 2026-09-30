import { useCallback, useEffect, useRef, useState } from 'react';
import DiscoverPage, { type CategorySelection } from './pages/DiscoverPage';
import CategoryIndexPage from './pages/CategoryIndexPage';
import FollowPage from './pages/FollowPage';
import MyCategoriesPage from './pages/MyCategoriesPage';
import { applyTheme, readTheme, toggleTheme, type ThemeMode } from './lib/theme';
import { loadDanmakuDefault, saveDanmakuDefault } from './lib/danmakuPrefs';
import { listMyCategories, subscribeMyCategories, type MyCategoryEntry } from './lib/myCategories';
import RoomPage from './pages/RoomPage';
import { getCategories, getPlatforms } from './api/client';
import type { AreaItem, Platform } from './api/types';

type Route =
  | { page: 'discover'; platform: string; keyword: string | null; area: CategorySelection | null }
  | { page: 'categoryIndex'; platform: string }
  | { page: 'myCategories'; platform: string }
  | { page: 'follow'; platform: string }
  | { page: 'room'; platform: string; roomId: string };

/** Fallback platform names when /platforms has not loaded yet. */
const FALLBACK_NAMES: Record<string, string> = { bilibili: 'BiliBili', douyin: 'Douyin' };

/** Short tile marks (zishu shows colorful app icons; we use brand-color text marks). */
const TILE_MARKS: Record<string, string> = { bilibili: 'B站', douyin: '抖音', huya: '虎牙', douyu: '斗鱼' };

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
 *   /{platform}/category                 -> category index tiles
 *   /{platform}/category/{areaId}?...    -> category rooms
 *   /{platform}/room/{roomId}            -> playback room
 * The bare "/" shows the douyin home (the M1 discovery platform).
 *
 * Shell layout follows zishu_flutter: a left rail (brand / nav row / platform
 * tiles / hot categories) around the browse pages; the play page goes
 * full-bleed without the rail. The home grid has no chips row — categories
 * live in the rail and the index page, like zishu.
 */
function routeFromLocation(): Route {
  const segments = window.location.pathname.split('/').filter(Boolean).map(decodeURIComponent);
  const query = new URLSearchParams(window.location.search);
  const keyword = query.get('keyword');

  if (segments.length === 3 && segments[1] === 'room' && segments[2]) {
    return { page: 'room', platform: segments[0], roomId: segments[2] };
  }
  if (segments.length === 1 && segments[0] === 'follow') {
    return { page: 'follow', platform: 'douyin' };
  }
  if (segments.length === 1 && segments[0] === 'my-categories') {
    return { page: 'myCategories', platform: 'douyin' };
  }
  if (segments.length >= 2 && segments[1] === 'category') {
    if (segments[2]) {
      const { areaType, typeName, areaName } = queryAreaOf(window.location.search);
      return {
        page: 'discover',
        platform: segments[0] || 'douyin',
        keyword: null,
        area: { areaId: segments[2], areaType, typeName, areaName },
      };
    }
    return { page: 'categoryIndex', platform: segments[0] || 'douyin' };
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
  const [hotCollapsed, setHotCollapsed] = useState(false);
  const [myCategories, setMyCategories] = useState<MyCategoryEntry[]>(listMyCategories);
  const [theme, setTheme] = useState<ThemeMode>(readTheme);
  const [settingsOpen, setSettingsOpen] = useState(false);
  const dialogRef = useRef<HTMLDivElement | null>(null);
  const [danmakuDefault, setDanmakuDefault] = useState<boolean>(loadDanmakuDefault);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
  }, [theme]);

  // Top-bar settings dialog behaviour while open: initial focus, ESC to
  // close, and a Tab loop so keyboard focus cannot reach the background
  // through the modal mask (aria-modal).
  useEffect(() => {
    if (!settingsOpen) return;
    dialogRef.current?.focus();
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setSettingsOpen(false);
        return;
      }
      if (e.key !== 'Tab' || !dialogRef.current) return;
      const focusables = dialogRef.current.querySelectorAll<HTMLElement>(
        'button, input, [tabindex]:not([tabindex="-1"])',
      );
      if (focusables.length === 0) return;
      const first = focusables[0];
      const last = focusables[focusables.length - 1];
      const active = document.activeElement;
      if (e.shiftKey && (active === first || !dialogRef.current.contains(active))) {
        e.preventDefault();
        last.focus();
      } else if (!e.shiftKey && active === last) {
        e.preventDefault();
        first.focus();
      }
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [settingsOpen]);

  // Modal mask locks background scrolling; restored on close/unmount.
  useEffect(() => {
    if (!settingsOpen) return;
    const prevOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    return () => {
      document.body.style.overflow = prevOverflow;
    };
  }, [settingsOpen]);

  // Segmented dark/light pick in the dialog — writes the picked mode straight
  // through applyTheme (same store the top-bar toggle uses) instead of
  // relying on toggleTheme's two-value inversion.
  const pickTheme = (mode: ThemeMode) => {
    if (mode === theme) return;
    applyTheme(mode);
    setTheme(mode);
  };

  const toggleDanmakuDefault = () => {
    const next = !danmakuDefault;
    setDanmakuDefault(next);
    saveDanmakuDefault(next);
  };

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

  // My-categories entries change on the category index page; refresh the
  // rail ★ markers through the store subscription.
  useEffect(() => subscribeMyCategories(() => setMyCategories(listMyCategories())), []);

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

  // Rail hot-category list: leaves of the platform directory (top 12).
  useEffect(() => {
    const platform = route.page === 'room' || route.page === 'follow' ? 'douyin' : route.platform;
    if (route.page === 'room') return;
    let disposed = false;
    setHotAreas([]);
    getCategories(platform)
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
        // Rail list is decoration; the index page still works.
      });
    return () => {
      disposed = true;
    };
  }, [route.page, route.platform, route.page === 'follow']);

  const platformName = useCallback(
    (id: string) => platforms.find((p) => p.id === id)?.name ?? FALLBACK_NAMES[id] ?? id,
    [platforms],
  );

  const navigate = useCallback((next: Route) => {
    setRoute(next);
    const url =
      next.page === 'room'
        ? `/${encodeURIComponent(next.platform)}/room/${encodeURIComponent(next.roomId)}`
        : next.page === 'categoryIndex'
          ? `/${encodeURIComponent(next.platform)}/category`
          : next.page === 'follow'
            ? '/follow'
            : next.page === 'myCategories'
              ? '/my-categories'
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

  const sidebar = route.page !== 'room' && (
    <aside className="sidebar">
      <div className="side-brand">Pure Live</div>
      <nav className="side-nav-row">
        <button
          type="button"
          className={`side-nav-item${route.page === 'discover' && route.area === null && route.keyword === null ? ' active' : ''}`}
          onClick={() => showDiscover(route.platform, null, null)}
        >
          <span className="side-nav-icon">⌂</span>
          <span className="side-nav-label">首页</span>
        </button>
        <button
          type="button"
          className={`side-nav-item${route.page === 'categoryIndex' ? ' active' : ''}`}
          onClick={() => navigate({ page: 'categoryIndex', platform: route.platform })}
        >
          <span className="side-nav-icon">▦</span>
          <span className="side-nav-label">分类</span>
        </button>
        <button
          type="button"
          className={`side-nav-item${route.page === 'myCategories' ? ' active' : ''}`}
          onClick={() => navigate({ page: 'myCategories', platform: route.platform })}
        >
          <span className="side-nav-icon">♥</span>
          <span className="side-nav-label">我的分类</span>
        </button>
        <button
          type="button"
          className={`side-nav-item${route.page === 'follow' ? ' active' : ''}`}
          onClick={() => navigate({ page: 'follow', platform: route.platform })}
        >
          <span className="side-nav-icon">★</span>
          <span className="side-nav-label">关注</span>
        </button>
      </nav>
      <div className="side-section-label">平台</div>
      <div className="side-platforms">
        {tabs.map((p) => {
          const activePlatform = route.page === 'follow' || route.page === 'myCategories' ? '' : route.platform;
          return (
            <button
              key={p.id}
              type="button"
              data-platform={p.id}
              className={`side-platform${activePlatform === p.id ? ' active' : ''}`}
              onClick={() => showDiscover(p.id, null, null)}
            >
              {TILE_MARKS[p.id] ?? (p.name ?? p.id).slice(0, 2)}
            </button>
          );
        })}
      </div>
      {hotAreas.length > 0 && (
        <>
          <button
            type="button"
            className="side-section-label side-collapse"
            onClick={() => setHotCollapsed((c) => !c)}
          >
            <span className="hot-dot">●</span> 热门分类
            <span className="collapse-arrow">{hotCollapsed ? '›' : '‹'}</span>
          </button>
          {!hotCollapsed && (
            <div className="side-hot">
              {hotAreas.map((area) => {
                const active = route.page === 'discover' && route.area?.areaId === area.areaId;
                const saved = myCategories.some(
                  (e) => e.platform === route.platform && e.areaId === (area.areaId ?? ''),
                );
                return (
                  <button
                    key={area.areaId}
                    type="button"
                    className={`side-hot-item${active ? ' active' : ''}`}
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
                    {saved && <span className="hot-star">★</span>}
                  </button>
                );
              })}
              <button
                type="button"
                className="side-hot-item side-hot-more"
                onClick={() => navigate({ page: 'categoryIndex', platform: route.platform })}
              >
                全部分类
              </button>
            </div>
          )}
        </>
      )}
    </aside>
  );

  // Mobile-only bottom navigation (zishu bottom_nav): mirrors the rail nav row
  // for <768px where the sidebar is hidden; the play page stays full-bleed.
  const bottomNav = route.page !== 'room' && (
    <nav className="bottom-nav">
      <button
        type="button"
        className={`bottom-nav-item${route.page === 'discover' && route.area === null && route.keyword === null ? ' active' : ''}`}
        onClick={() => showDiscover(route.platform, null, null)}
      >
        <span className="bottom-nav-icon">⌂</span>
        <span className="bottom-nav-label">首页</span>
      </button>
      <button
        type="button"
        className={`bottom-nav-item${route.page === 'categoryIndex' ? ' active' : ''}`}
        onClick={() => navigate({ page: 'categoryIndex', platform: route.platform })}
      >
        <span className="bottom-nav-icon">▦</span>
        <span className="bottom-nav-label">分类</span>
      </button>
      <button
        type="button"
        className={`bottom-nav-item${route.page === 'follow' ? ' active' : ''}`}
        onClick={() => navigate({ page: 'follow', platform: route.platform })}
      >
        <span className="bottom-nav-icon">★</span>
        <span className="bottom-nav-label">关注</span>
      </button>
      <button
        type="button"
        className={`bottom-nav-item${route.page === 'myCategories' ? ' active' : ''}`}
        onClick={() => navigate({ page: 'myCategories', platform: route.platform })}
      >
        <span className="bottom-nav-icon">▤</span>
        <span className="bottom-nav-label">我的分类</span>
      </button>
    </nav>
  );

  return (
    <div className={`app${route.page === 'room' ? ' app-play' : ''}`}>
      {sidebar}
      {bottomNav}
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
          <button
            type="button"
            className="theme-toggle"
            title={theme === 'dark' ? '切换浅色' : '切换深色'}
            onClick={() => setTheme((m) => toggleTheme(m))}
          >
            {theme === 'dark' ? '🌙' : '☀️'}
          </button>
          <button
            type="button"
            className="settings-toggle"
            title="设置"
            aria-haspopup="dialog"
            onClick={() => setSettingsOpen(true)}
          >
            ⚙
          </button>
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
              onSearch={(platform, keyword) => showDiscover(platform, keyword.trim() === '' ? null : keyword, null)}
            />
          ) : route.page === 'categoryIndex' ? (
            <CategoryIndexPage
              key={`categoryIndex:${route.platform}`}
              platform={route.platform}
              onOpenCategory={(platform, area) => showDiscover(platform, null, area)}
            />
          ) : route.page === 'myCategories' ? (
            <MyCategoriesPage
              key="myCategories"
              platformName={platformName}
              onOpenCategory={(platform, area) => showDiscover(platform, null, area)}
              onOpenCategoryIndex={() => navigate({ page: 'categoryIndex', platform: route.platform })}
            />
          ) : route.page === 'follow' ? (
            <FollowPage key="follow" onEnterRoom={enterRoom} platformName={platformName} />
          ) : (
            <RoomPage
              key={`room:${route.platform}:${route.roomId}`}
              platform={route.platform}
              roomId={route.roomId}
              onLeave={() => showDiscover(route.platform, null, null)}
              onOpenRoom={enterRoom}
            />
          )}
        </main>
      </div>
      {settingsOpen && (
        <div className="settings-dialog-mask" onClick={() => setSettingsOpen(false)}>
          <div
            ref={dialogRef}
            className="settings-dialog"
            role="dialog"
            aria-modal="true"
            aria-label="设置"
            tabIndex={-1}
            onClick={(e) => e.stopPropagation()}
          >
            <div className="settings-dialog-head">
              <span>设置</span>
              <button
                type="button"
                className="settings-dialog-close"
                aria-label="关闭"
                onClick={() => setSettingsOpen(false)}
              >
                ×
              </button>
            </div>
            <div className="settings-dialog-body">
              <section className="settings-dialog-section">
                <h3 className="settings-dialog-label">外观</h3>
                <div className="settings-row">
                  <span>主题</span>
                  <div className="settings-segments" role="group" aria-label="主题模式">
                    <button
                      type="button"
                      className={theme === 'dark' ? 'active' : ''}
                      aria-pressed={theme === 'dark'}
                      onClick={() => pickTheme('dark')}
                    >
                      深色
                    </button>
                    <button
                      type="button"
                      className={theme === 'light' ? 'active' : ''}
                      aria-pressed={theme === 'light'}
                      onClick={() => pickTheme('light')}
                    >
                      浅色
                    </button>
                  </div>
                </div>
              </section>
              <section className="settings-dialog-section">
                <h3 className="settings-dialog-label">弹幕</h3>
                <label className="settings-row">
                  <span>默认弹幕</span>
                  <button
                    type="button"
                    className={`switch${danmakuDefault ? '' : ' off'}`}
                    onClick={toggleDanmakuDefault}
                  >
                    {danmakuDefault ? '开启' : '关闭'}
                  </button>
                </label>
                <p className="settings-hint">
                  打开播放页设置:进入直播间后,在右侧栏「设置」标签中可调弹幕字号 / 不透明度 /
                  速度 / 显示区域 / 描边,以及当次播放的弹幕显隐。
                </p>
              </section>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
