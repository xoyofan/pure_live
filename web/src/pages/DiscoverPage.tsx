import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { getCategories, getCategoryRooms, getRecommendRooms, searchRooms } from '../api/client';
import { isApiError } from '../api/types';
import type { AreaItem, Category, RoomListItem } from '../api/types';
import RoomCard from '../components/RoomCard';

export interface CategorySelection {
  areaId: string;
  areaType?: string;
  typeName?: string;
  areaName?: string;
}

interface Props {
  platform: string;
  platformName: string;
  /** Route-driven mode: keyword -> search, areaId -> category, else recommend. */
  keyword: string | null;
  area: CategorySelection | null;
  onEnterRoom: (platform: string, roomId: string) => void;
  onSelectCategory: (platform: string, area: CategorySelection | null) => void;
  onSearch: (platform: string, keyword: string) => void;
}

type Feed =
  | { kind: 'loading' }
  | { kind: 'error'; message: string }
  | { kind: 'ok'; rooms: RoomListItem[]; page: number; hasMore: boolean };

const PAGE_SIZE = 30;

function describeError(err: unknown, fallback: string): string {
  if (isApiError(err)) {
    switch (err.code) {
      case 'NETWORK':
        return '无法连接解析服务,请确认解析服务已启动';
      case 'PLATFORM_UNSUPPORTED':
        return '该平台暂未接入发现流';
      case 'UPSTREAM_ERROR':
      case 'UPSTREAM_TIMEOUT':
        return '上游平台响应异常,请稍后重试';
      default:
        return err.message || fallback;
    }
  }
  return fallback;
}

function dedupeRooms(rooms: RoomListItem[]): RoomListItem[] {
  const seen = new Set<string>();
  const out: RoomListItem[] = [];
  for (const room of rooms) {
    const key = `${room.platform}:${room.roomId}`;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(room);
  }
  return out;
}

/**
 * Platform home (api.md 4.6): recommend feed by default, category rooms via
 * the chip row, keyword search from the nav box. Infinite-scrolls while the
 * server reports hasMore.
 */
export default function DiscoverPage({
  platform,
  platformName,
  keyword,
  area,
  onEnterRoom,
  onSelectCategory,
  onSearch,
}: Props) {
  const [feed, setFeed] = useState<Feed>({ kind: 'loading' });
  const [categories, setCategories] = useState<Category[]>([]);
  const loadSeqRef = useRef(0);
  const loadingRef = useRef(false);
  const sentinelRef = useRef<HTMLDivElement | null>(null);

  const mode: 'search' | 'category' | 'recommend' = keyword !== null ? 'search' : area !== null ? 'category' : 'recommend';

  // Categories power the chip row (category mode + discovery entry points).
  useEffect(() => {
    let disposed = false;
    setCategories([]);
    getCategories(platform)
      .then((res) => {
        if (!disposed) setCategories(res.categories ?? []);
      })
      .catch(() => {
        // Chip row is optional decoration; category mode still works via URL.
      });
    return () => {
      disposed = true;
    };
  }, [platform]);

  // Reset the feed whenever the (platform, mode, key) triple changes.
  useEffect(() => {
    const seq = ++loadSeqRef.current;
    loadingRef.current = true;
    setFeed({ kind: 'loading' });

    const fetchPage = keyword !== null
      ? () => searchRooms(platform, keyword, 1, PAGE_SIZE)
      : area !== null
        ? () => getCategoryRooms(platform, area, 1, PAGE_SIZE)
        : () => getRecommendRooms(platform, 1, PAGE_SIZE);

    fetchPage()
      .then((res) => {
        if (seq !== loadSeqRef.current) return;
        setFeed({ kind: 'ok', rooms: dedupeRooms(res.rooms ?? []), page: res.page, hasMore: res.hasMore });
      })
      .catch((err: unknown) => {
        if (seq !== loadSeqRef.current) return;
        setFeed({ kind: 'error', message: describeError(err, '列表获取失败') });
      })
      .finally(() => {
        if (seq === loadSeqRef.current) loadingRef.current = false;
      });
  }, [platform, keyword, area?.areaId, area?.areaType]);

  const loadMore = useCallback(() => {
    if (loadingRef.current) return;
    if (feed.kind !== 'ok' || !feed.hasMore) return;
    loadingRef.current = true;
    const seq = loadSeqRef.current;
    const nextPage = feed.page + 1;

    const fetchPage = keyword !== null
      ? () => searchRooms(platform, keyword, nextPage, PAGE_SIZE)
      : area !== null
        ? () => getCategoryRooms(platform, area, nextPage, PAGE_SIZE)
        : () => getRecommendRooms(platform, nextPage, PAGE_SIZE);

    fetchPage()
      .then((res) => {
        if (seq !== loadSeqRef.current) return;
        setFeed((prev) =>
          prev.kind === 'ok'
            ? {
                kind: 'ok',
                rooms: dedupeRooms([...prev.rooms, ...(res.rooms ?? [])]),
                page: res.page,
                hasMore: res.hasMore,
              }
            : prev,
        );
      })
      .catch(() => {
        // Keep the already-loaded rooms; the sentinel retry re-triggers.
      })
      .finally(() => {
        loadingRef.current = false;
      });
  }, [feed, platform, keyword, area]);

  // Infinite scroll: load the next page when the sentinel gets close.
  useEffect(() => {
    const node = sentinelRef.current;
    if (!node || feed.kind !== 'ok' || !feed.hasMore) return;
    const observer = new IntersectionObserver(
      (entries) => {
        if (entries.some((entry) => entry.isIntersecting)) loadMore();
      },
      { rootMargin: '600px 0px' },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, [feed, loadMore]);

  // Flatten the category tree into selectable chips (children preferred).
  const chips = useMemo(() => {
    const out: AreaItem[] = [];
    for (const category of categories) {
      for (const child of category.children) {
        if (child.areaId) out.push(child);
      }
    }
    return out;
  }, [categories]);

  const selectedAreaId = area?.areaId ?? null;

  return (
    <div className="discover">
      <div className="discover-toolbar">
        <div className="category-chips">
          <button
            type="button"
            className={`chip${mode === 'recommend' ? ' active' : ''}`}
            onClick={() => onSelectCategory(platform, null)}
          >
            推荐
          </button>
          {chips.map((chip) => (
            <button
              key={chip.areaId}
              type="button"
              className={`chip${selectedAreaId === chip.areaId ? ' active' : ''}`}
              onClick={() =>
                onSelectCategory(platform, {
                  areaId: chip.areaId ?? '',
                  areaType: chip.areaType ?? undefined,
                  typeName: chip.typeName ?? undefined,
                  areaName: chip.areaName ?? undefined,
                })
              }
            >
              {chip.areaName || chip.typeName || chip.areaId}
            </button>
          ))}
        </div>
      </div>

      {mode === 'search' && keyword !== null && (
        <p className="discover-heading">
          “{keyword}” 的搜索结果
          <button type="button" className="btn-small" onClick={() => onSearch(platform, '')}>
            取消
          </button>
        </p>
      )}
      {mode === 'category' && area !== null && (
        <p className="discover-heading">{area.typeName || area.areaName || area.areaId} · 分类房间</p>
      )}

      {feed.kind === 'loading' && (
        <div className="cards-grid">
          {Array.from({ length: 12 }, (_, i) => (
            <div key={i} className="room-card skeleton">
              <div className="room-card-cover" />
              <div className="room-card-body">
                <div className="skeleton-line" />
                <div className="skeleton-line short" />
              </div>
            </div>
          ))}
        </div>
      )}

      {feed.kind === 'error' && (
        <div className="room-state">
          <p className="banner banner-error">{feed.message}</p>
        </div>
      )}

      {feed.kind === 'ok' && feed.rooms.length === 0 && (
        <p className="banner">{mode === 'search' ? '没有匹配的直播间' : '暂时没有开播中的房间'}</p>
      )}

      {feed.kind === 'ok' && feed.rooms.length > 0 && (
        <>
          <div className="cards-grid">
            {feed.rooms.map((room) => (
              <RoomCard key={`${room.platform}:${room.roomId}`} room={room} platformName={platformName} onOpen={onEnterRoom} />
            ))}
          </div>
          <div ref={sentinelRef} className="feed-sentinel">
            {feed.hasMore ? (
              <span className="feed-hint">加载中…</span>
            ) : (
              <span className="feed-hint">没有更多了</span>
            )}
          </div>
        </>
      )}
    </div>
  );
}
