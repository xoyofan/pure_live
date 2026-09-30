import { useEffect, useState } from 'react';
import { getCategories } from '../api/client';
import { isApiError } from '../api/types';
import type { AreaItem, Category } from '../api/types';
import StateBanner from '../components/StateBanner';
import { categoryStyle } from '../lib/categoryColor';
import { addMyCategory, listMyCategories, removeMyCategory, subscribeMyCategories } from '../lib/myCategories';

interface Props {
  platform: string;
  onOpenCategory: (platform: string, area: { areaId: string; areaType?: string; typeName?: string; areaName?: string }) => void;
}

/** Tiles per screen;「加载更多」appends this many (huya alone has ~400 leaves). */
const PAGE_SIZE = 60;

/**
 * Category index (zishu CategoryIndexView shape): tiles of every directory
 * leaf — cover image when the platform supplies one, hashed-color name tile
 * otherwise.
 */
export default function CategoryIndexPage({ platform, onOpenCategory }: Props) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [error, setError] = useState<string | null>(null);
  // 错误 banner 的「重试」:自增后触发分类重新请求。
  const [reloadSeq, setReloadSeq] = useState(0);
  const [myCats, setMyCats] = useState(listMyCategories);
  const [query, setQuery] = useState('');
  const [visibleCount, setVisibleCount] = useState(PAGE_SIZE);

  // Save/remove happens here; the subscription keeps the ★ state current.
  useEffect(() => subscribeMyCategories(() => setMyCats(listMyCategories())), []);

  useEffect(() => {
    let disposed = false;
    setCategories([]);
    setError(null);
    setVisibleCount(PAGE_SIZE);
    getCategories(platform)
      .then((res) => {
        if (!disposed) setCategories(res.categories ?? []);
      })
      .catch((err: unknown) => {
        if (disposed) return;
        setError(isApiError(err) && err.code === 'NETWORK' ? '无法连接解析服务' : '分类获取失败,请稍后重试');
      });
    return () => {
      disposed = true;
    };
  }, [platform, reloadSeq]);

  const leaves: AreaItem[] = [];
  for (const category of categories) {
    for (const child of category.children) {
      if (child.areaId) leaves.push(child);
    }
  }

  const savedKeys = new Set(myCats.filter((e) => e.platform === platform).map((e) => e.areaId));

  // Client-side filter over areaName/typeName — no extra requests.
  const keyword = query.trim().toLowerCase();
  const filtered = keyword
    ? leaves.filter((area) =>
        [area.areaName ?? '', area.typeName ?? ''].some((name) => name.toLowerCase().includes(keyword)),
      )
    : leaves;
  const shown = filtered.slice(0, visibleCount);

  const toggleSave = (area: AreaItem) => {
    const areaId = area.areaId ?? '';
    if (savedKeys.has(areaId)) removeMyCategory(platform, areaId);
    else
      addMyCategory({
        platform,
        areaId,
        areaType: area.areaType ?? undefined,
        typeName: area.typeName ?? undefined,
        areaName: area.areaName ?? undefined,
      });
  };

  return (
    <div className="discover">
      <h2 className="category-index-title">全部分类</h2>
      <div className="discover-search">
        <input
          type="search"
          value={query}
          placeholder="搜索分类名称"
          onChange={(e) => {
            setQuery(e.target.value);
            setVisibleCount(PAGE_SIZE);
          }}
        />
      </div>
      {error && <StateBanner kind="error" text={error} onRetry={() => setReloadSeq((n) => n + 1)} />}
      {!error && leaves.length === 0 && <StateBanner kind="loading" text="分类加载中…" />}
      {!error && leaves.length > 0 && filtered.length === 0 && (
        <StateBanner kind="empty" text="没有匹配的分类,换个关键词试试" />
      )}
      <div className="category-tiles">
        {shown.map((area) => {
          const style = categoryStyle(area.areaName || area.typeName || '');
          const saved = savedKeys.has(area.areaId ?? '');
          return (
            <div key={area.areaId} className="category-tile-cell">
              <button
                type="button"
                className="category-tile"
                onClick={() =>
                  onOpenCategory(platform, {
                    areaId: area.areaId ?? '',
                    areaType: area.areaType ?? undefined,
                    typeName: area.typeName ?? undefined,
                    areaName: area.areaName ?? undefined,
                  })
                }
              >
                {area.areaPic ? (
                  <img src={area.areaPic} alt="" loading="lazy" referrerPolicy="no-referrer" />
                ) : null}
                <span
                  className="category-tile-name"
                  style={style ? { background: style.background, color: style.foreground } : undefined}
                >
                  {area.areaName || area.typeName || area.areaId}
                </span>
              </button>
              <button
                type="button"
                className={`category-fav-btn${saved ? ' saved' : ''}`}
                title={saved ? '取消收藏' : '收藏分类'}
                onClick={() => toggleSave(area)}
              >
                ★
              </button>
            </div>
          );
        })}
      </div>
      {filtered.length > shown.length && (
        <div className="category-load-more">
          <button type="button" className="btn-small" onClick={() => setVisibleCount((n) => n + PAGE_SIZE)}>
            加载更多
          </button>
        </div>
      )}
    </div>
  );
}
