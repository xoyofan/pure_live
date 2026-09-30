import { useEffect, useState } from 'react';
import { getCategories } from '../api/client';
import { isApiError } from '../api/types';
import type { AreaItem, Category } from '../api/types';
import { categoryStyle } from '../lib/categoryColor';

interface Props {
  platform: string;
  onOpenCategory: (platform: string, area: { areaId: string; areaType?: string; typeName?: string; areaName?: string }) => void;
}

/**
 * Category index (zishu CategoryIndexView shape): tiles of every directory
 * leaf — cover image when the platform supplies one, hashed-color name tile
 * otherwise.
 */
export default function CategoryIndexPage({ platform, onOpenCategory }: Props) {
  const [categories, setCategories] = useState<Category[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let disposed = false;
    setCategories([]);
    setError(null);
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
  }, [platform]);

  const leaves: AreaItem[] = [];
  for (const category of categories) {
    for (const child of category.children) {
      if (child.areaId) leaves.push(child);
    }
  }

  return (
    <div className="discover">
      <h2 className="category-index-title">全部分类</h2>
      {error && <p className="banner banner-error">{error}</p>}
      {!error && leaves.length === 0 && <p className="banner">分类加载中…</p>}
      <div className="category-tiles">
        {leaves.map((area) => {
          const style = categoryStyle(area.areaName || area.typeName || '');
          return (
            <button
              key={area.areaId}
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
          );
        })}
      </div>
    </div>
  );
}
